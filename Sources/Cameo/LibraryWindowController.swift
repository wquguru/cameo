import AppKit
import SwiftUI

/// The character library: one window for when there are more characters than the popover shows.
/// While it is open Cameo is a regular app (Dock icon, menu bar menus); closing it returns Cameo
/// to the menu bar only.
@MainActor
final class LibraryWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let thumbnails: Thumbnails
    private let onAdd: (NSWindow) -> Void
    private var window: NSWindow?
    /// Called after the window closes, so the Dock icon can go if nothing else needs it.
    var onClose: (() -> Void)?

    init(model: AppModel, thumbnails: Thumbnails, onAdd: @escaping (NSWindow) -> Void) {
        self.model = model
        self.thumbnails = thumbnails
        self.onAdd = onAdd
    }

    /// On screen or in the Dock.
    var isOpen: Bool { window.map { $0.isVisible || $0.isMiniaturized } ?? false }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        let content = NSHostingController(rootView: LibraryView(model: model, thumbnails: thumbnails) { [weak self, weak window] in
            if let window { self?.onAdd(window) }
        })
        // The SwiftUI title, search field and toolbar items go into the window's own toolbar.
        content.sceneBridgingOptions = [.title, .toolbars]
        window.contentViewController = content
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 520, height: 400)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 960, height: 680))
        window.center()
        window.setFrameAutosaveName("Library")
        return window
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { self.onClose?() }
    }
}
