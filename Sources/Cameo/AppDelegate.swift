import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = AppModel()
    private let thumbnails = Thumbnails()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var characterWindow: CharacterWindowController!
    private var library: LibraryWindowController!
    private var updateBadge: AnyCancellable?
    private var dockIcon: AnyCancellable?
    /// An invisible point under the menu bar to show the popover from when the status item can't
    /// be relied on (it may be hidden behind the notch of a crowded menu bar).
    /// The view the popover is showing from.
    private weak var popoverAnchor: NSView?
    private var lastClose: Date?
    /// Closes the popover on a click in another app. `.transient` alone misses these when Cameo
    /// never became the active app (activation is only a request since macOS 14).
    private var outsideClicks: Any?
    private let screenAnchor = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                                       styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Glyph.template
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        let content = NSHostingController(rootView: PopoverView(
            model: model, thumbnails: thumbnails,
            onAdd: { [weak self] in self?.chooseVideos() },
            onOpenLibrary: { [weak self] in self?.openLibrary() }))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        popover.delegate = self

        characterWindow = CharacterWindowController(model: model)
        // Right-clicking the figure toggles the popover above it, clear of the pointer.
        characterWindow.onSecondaryClick = { [weak self] view in
            guard let self else { return }
            // A transient popover may already be closing from this very click.
            let justClosed = self.lastClose.map { Date().timeIntervalSince($0) < 0.4 } ?? false
            if self.popoverAnchor === view && (self.popover.isShown || justClosed) {
                self.popover.performClose(nil)
            } else {
                self.showPopover(relativeTo: view.bounds, of: view, edge: .maxY)
            }
        }
        screenAnchor.backgroundColor = .clear
        screenAnchor.ignoresMouseEvents = true
        screenAnchor.level = .statusBar
        screenAnchor.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        library = LibraryWindowController(model: model, thumbnails: thumbnails) { [weak self] window in
            self?.chooseVideos(in: window)
        }
        library.onClose = { [weak self] in self?.updateDockIcon() }
        // While the figure is hidden Cameo waits in the Dock: with its menu bar icon behind the
        // notch there would otherwise be nothing on screen to click.
        dockIcon = model.$visible.sink { [weak self] visible in self?.updateDockIcon(visible: visible) }
        NSApp.mainMenu = MainMenu.make()
        updateBadge = model.$update.combineLatest(model.$language).sink { [weak self] update, _ in
            self?.statusItem.button?.image = update == nil ? Glyph.template : Glyph.withBadge
            NSApp.mainMenu = MainMenu.make()
        }
        model.startUpdateChecks()
        let firstLaunch = !UserDefaults.standard.bool(forKey: "launched")
        UserDefaults.standard.set(true, forKey: "launched")
        if firstLaunch || ProcessInfo.processInfo.environment["CAMEO_OPEN_POPOVER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePopover() }
        }
        if ProcessInfo.processInfo.environment["CAMEO_OPEN_LIBRARY"] != nil { openLibrary() }
    }

    /// Opening a video with Cameo (Finder "Open With", or dropping it on the app icon) adds it,
    /// and so does a `cameo://add` link from the gallery.
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty { Task { await model.add(files) } }
        for link in urls.compactMap(GalleryLink.init) {
            Task {
                await model.add(link)
                showPopover()
            }
        }
    }

    /// Opening Cameo again while it runs (Spotlight, Launchpad, Finder) shows the popover below
    /// the menu bar, so it stays reachable when its icon is crowded out; an open library window
    /// is simply brought forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if library.isOpen { return true }
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        else { return false }
        let frame = screen.visibleFrame
        screenAnchor.setFrameOrigin(NSPoint(x: frame.midX, y: frame.maxY - 1))
        screenAnchor.orderFrontRegardless()
        if let view = screenAnchor.contentView {
            showPopover(relativeTo: view.bounds, of: view, edge: .minY)
        }
        return false
    }

    func popoverDidClose(_ notification: Notification) {
        lastClose = Date()
        // Moving the popover closes and reopens it; keep the monitor for the reopened one.
        guard !popover.isShown else { return }
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        screenAnchor.orderOut(nil)
    }

    private func showPopover() {
        guard statusItem != nil, !popover.isShown else { return }
        togglePopover()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button.bounds, of: button, edge: .minY)
        }
    }

    /// Shows the popover pointing at `rect` in `view`, moving it there if it is open elsewhere.
    private func showPopover(relativeTo rect: NSRect, of view: NSView, edge: NSRectEdge) {
        if popover.isShown { popover.close() }
        NSApp.activate()
        if let content = popover.contentViewController?.view { popover.contentSize = content.fittingSize }
        popover.show(relativeTo: rect, of: view, preferredEdge: edge)
        popoverAnchor = view
        if view.window !== screenAnchor { screenAnchor.orderOut(nil) }
        if outsideClicks == nil {
            outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.popover.performClose(nil) }
            }
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    /// A Dock icon (and the menus) while the library is open or the figure is hidden.
    private func updateDockIcon(visible: Bool? = nil) {
        let regular = library.isOpen || !(visible ?? model.visible)
        let policy: NSApplication.ActivationPolicy = regular ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    private func openLibrary() {
        popover.performClose(nil)
        library.show()
    }

    /// From the library: a sheet on its window, and the library shows the result.
    private func chooseVideos(in window: NSWindow) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.message = L("Choose videos with an alpha channel (HEVC with Alpha or ProRes 4444)")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self else { return }
            Task { await self.model.add(panel.urls) }
        }
    }

    private func chooseVideos() {
        popover.performClose(nil)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.message = L("Choose videos with an alpha channel (HEVC with Alpha or ProRes 4444)")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        Task {
            await model.add(panel.urls)
            togglePopover()
        }
    }
}
