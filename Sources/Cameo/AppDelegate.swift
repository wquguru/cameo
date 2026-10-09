import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let thumbnails = Thumbnails()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var characterWindow: CharacterWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Glyph.template
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        let content = NSHostingController(rootView: PopoverView(model: model, thumbnails: thumbnails) { [weak self] in
            self?.chooseVideos()
        })
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)

        characterWindow = CharacterWindowController(model: model)
        let firstLaunch = !UserDefaults.standard.bool(forKey: "launched")
        UserDefaults.standard.set(true, forKey: "launched")
        if firstLaunch || ProcessInfo.processInfo.environment["CAMEO_OPEN_POPOVER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePopover() }
        }
    }

    /// Opening a video with Cameo (Finder "Open With", or dropping it on the app icon) adds it.
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { await model.add(urls) }
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

    private func chooseVideos() {
        popover.performClose(nil)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.message = "选择带透明通道的视频（HEVC with Alpha 或 ProRes 4444）"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        Task {
            await model.add(panel.urls)
            togglePopover()
        }
    }
}
