import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var characterWindow: CharacterWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Glyph.template
        characterWindow = CharacterWindowController(model: model)
    }

    /// Opening a video with Cameo (Finder "Open With", or dropping it on the app icon) adds it.
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { await model.add(urls) }
    }
}
