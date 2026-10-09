import AppKit

/// `Cameo --render-dmg-background out.png <scale>` draws the installer window's background
/// (design: Cameo Installer canvas, "DMG 安装窗口"). Finder places the icons on top of it at
/// `appIcon` and `applicationsIcon`, so the art leaves those spots empty.
enum DMGBackground {
    static let size = CGSize(width: 720, height: 440)
    static let appIcon = CGPoint(x: 190, y: 200)
    static let applicationsIcon = CGPoint(x: 530, y: 200)

    private static let ink = NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)        // #1D1D1F
    private static let secondary = NSColor(srgbRed: 0.431, green: 0.431, blue: 0.451, alpha: 1)  // #6E6E73
    private static let amber = CGColor(srgbRed: 0.910, green: 0.604, blue: 0.118, alpha: 1)      // #E89A1E

    static func render(to url: URL, scale: Int) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        guard let cg = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { throw CocoaError(.fileWriteUnknown) }
        // The context already maps points to pixels (rep.size); flip to a y-down point space.
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        draw(cg)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }

    private static func draw(_ ctx: CGContext) {
        ctx.setFillColor(CGColor(srgbRed: 0.969, green: 0.961, blue: 0.945, alpha: 1))  // #F7F5F1
        ctx.fill(CGRect(origin: .zero, size: size))

        // Spotlight beam over the path from the app to the folder.
        ctx.saveGState()
        ctx.move(to: CGPoint(x: 336, y: -20))
        ctx.addLine(to: CGPoint(x: 384, y: -20))
        ctx.addLine(to: CGPoint(x: 460, y: 400))
        ctx.addLine(to: CGPoint(x: 260, y: 400))
        ctx.closePath()
        ctx.clip()
        let beam = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [CGColor(srgbRed: 1, green: 0.702, blue: 0.251, alpha: 0.22),
                                       CGColor(srgbRed: 1, green: 0.702, blue: 0.251, alpha: 0)] as CFArray,
                              locations: [0, 0.85])!
        ctx.drawLinearGradient(beam, start: CGPoint(x: 0, y: -20), end: CGPoint(x: 0, y: 400), options: [])
        ctx.restoreGState()

        text("把 Cameo 拖进「应用程序」", size: 22, weight: .semibold, color: ink, centerX: 360, top: 36)
        text("然后在「应用程序」或启动台里打开它", size: 13, weight: .regular, color: secondary, centerX: 360, top: 70)

        // Dotted arrow from the app to Applications.
        ctx.setStrokeColor(amber)
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.saveGState()
        ctx.setLineDash(phase: 0, lengths: [2, 9])
        ctx.move(to: CGPoint(x: 268, y: 202))
        ctx.addCurve(to: CGPoint(x: 444, y: 194), control1: CGPoint(x: 322, y: 154), control2: CGPoint(x: 398, y: 154))
        ctx.strokePath()
        ctx.restoreGState()
        ctx.move(to: CGPoint(x: 430, y: 194))
        ctx.addLine(to: CGPoint(x: 446, y: 196))
        ctx.addLine(to: CGPoint(x: 442, y: 180))
        ctx.strokePath()

        // Chaofei leads the way, standing on a faint floor line.
        let floorY: CGFloat = 351
        ctx.saveGState()
        let line = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.12), CGColor(gray: 0, alpha: 0)] as CFArray,
                              locations: [0, 0.5, 1])!
        ctx.clip(to: CGRect(x: 252, y: floorY, width: 216, height: 1))
        ctx.drawLinearGradient(line, start: CGPoint(x: 252, y: 0), end: CGPoint(x: 468, y: 0), options: [])
        ctx.restoreGState()
        let catSize = CGSize(width: 170, height: 146)
        ctx.saveGState()
        ctx.translateBy(x: 360 - catSize.width / 2, y: floorY - catSize.height * CatRig.ground / CatRig.canvas.height)
        let cat = CatRig.frame(pose: .stand, spin: 0, facingLeft: false, eyeOpenness: 1, viewSize: catSize)
        CatArt.draw(cat, in: ctx)
        ctx.restoreGState()

        // Footer: platform on the left, first-launch hint on the right.
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.08))
        ctx.fill(CGRect(x: 0, y: 394, width: size.width, height: 0.5))
        let monitor = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        if let monitor {
            let tinted = NSImage(size: monitor.size, flipped: false) { rect in
                monitor.draw(in: rect)
                secondary.set()
                rect.fill(using: .sourceIn)
                return true
            }
            tinted.draw(in: CGRect(x: 24, y: 417 - monitor.size.height / 2, width: monitor.size.width, height: monitor.size.height))
        }
        text("macOS 14 及以上 · Apple 芯片与 Intel 通用", size: 11.5, weight: .regular, color: secondary, left: 44, centerY: 417)
        text("首次打开：系统设置 › 隐私与安全性 › 仍要打开", size: 11.5, weight: .regular, color: secondary, right: 696, centerY: 417)
    }

    private static func attributed(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }

    private static func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerX: CGFloat, top: CGFloat) {
        let a = attributed(s, size: size, weight: weight, color: color)
        a.draw(at: CGPoint(x: centerX - a.size().width / 2, y: top))
    }

    private static func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, left: CGFloat? = nil, right: CGFloat? = nil, centerY: CGFloat) {
        let a = attributed(s, size: size, weight: weight, color: color)
        let x = left ?? ((right ?? 0) - a.size().width)
        a.draw(at: CGPoint(x: x, y: centerY - a.size().height / 2))
    }
}
