import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let thumbnails = Thumbnails()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var characterWindow: CharacterWindowController!
    private var library: LibraryWindowController!
    private var updateBadge: AnyCancellable?

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

        characterWindow = CharacterWindowController(model: model)
        library = LibraryWindowController(model: model, thumbnails: thumbnails) { [weak self] window in
            self?.chooseVideos(in: window)
        }
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

    private func showPopover() {
        guard statusItem != nil, !popover.isShown else { return }
        togglePopover()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate()
            if let view = popover.contentViewController?.view { popover.contentSize = view.fittingSize }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
