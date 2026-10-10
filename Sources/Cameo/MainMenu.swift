import AppKit

/// The menu bar menus Cameo shows while the library window makes it a regular app: enough for
/// About, Quit, editing a name (cut, copy, paste, undo), closing the window, and Help pointing at
/// the gallery's pages on making and submitting a character.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu("Cameo", [
            item(L("About Cameo"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item(L("Hide Cameo"), #selector(NSApplication.hide(_:)), "h"),
            .separator(),
            item(L("Quit Cameo"), #selector(NSApplication.terminate(_:)), "q"),
        ]))
        menu.addItem(submenu(L("Edit"), [
            item(L("Undo"), Selector(("undo:")), "z"),
            item(L("Redo"), Selector(("redo:")), "Z"),
            .separator(),
            item(L("Cut"), #selector(NSText.cut(_:)), "x"),
            item(L("Copy"), #selector(NSText.copy(_:)), "c"),
            item(L("Paste"), #selector(NSText.paste(_:)), "v"),
            item(L("Select All"), #selector(NSText.selectAll(_:)), "a"),
        ]))
        menu.addItem(submenu(L("Window"), [
            item(L("Close"), #selector(NSWindow.performClose(_:)), "w"),
            item(L("Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"),
        ]))
        let help = submenu(L("Help"), [
            LinkMenuItem(L("Make a Character"), GalleryLink.make),
            LinkMenuItem(L("Submit a Character"), GalleryLink.submit),
            .separator(),
            LinkMenuItem(L("Report an Issue"), AboutPanel.repository.appendingPathComponent("issues/new")),
        ])
        menu.addItem(help)
        NSApp.helpMenu = help.submenu
        return menu
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = NSMenu(title: title)
        items.forEach(item.submenu!.addItem)
        return item
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }
}
