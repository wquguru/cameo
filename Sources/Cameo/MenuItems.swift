import AppKit

/// A menu item that runs a closure, for menus built in code outside a responder chain.
class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() { handler() }
}

/// A menu item that opens a web page in the browser.
final class LinkMenuItem: ActionMenuItem {
    init(_ title: String, _ url: URL) {
        super.init(title) { NSWorkspace.shared.open(url) }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
