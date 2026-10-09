import AppKit

/// "关于 Cameo": the standard About panel (icon, name, version and copyright come from
/// Info.plist) with a line about the app and links to the project, gallery and issues.
@MainActor
enum AboutPanel {
    static let repository = URL(string: "https://github.com/wquguru/cameo")!

    static func show() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private static var credits: NSAttributedString {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.paragraphSpacing = 6
        let plain: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor, .paragraphStyle: centered,
        ]
        let text = NSMutableAttributedString(string: "让角色站在你的桌面上。\n", attributes: plain)
        let links = [("GitHub", repository), ("角色画廊", GalleryLink.gallery),
                     ("反馈问题", repository.appendingPathComponent("issues/new"))]
        for (i, (title, url)) in links.enumerated() {
            if i > 0 { text.append(NSAttributedString(string: "  ·  ", attributes: plain)) }
            var linked = plain
            linked[.link] = url
            text.append(NSAttributedString(string: title, attributes: linked))
        }
        var secondary = plain
        secondary[.foregroundColor] = NSColor.secondaryLabelColor
        text.append(NSAttributedString(string: "\n内置角色 Chaofei 以作者的猫为原型", attributes: secondary))
        return text
    }
}
