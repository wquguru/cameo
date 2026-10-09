// Renders the Cameo app icon into an .iconset folder (see design/Icon.dc.html).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

/// The shared figure silhouette in its 100×204 design space.
func figurePath() -> CGPath {
    let p = CGMutablePath()
    p.addEllipse(in: CGRect(x: 33, y: 5, width: 34, height: 34))
    p.move(to: CGPoint(x: 50, y: 43))
    p.addCurve(to: CGPoint(x: 21, y: 70), control1: CGPoint(x: 33, y: 43), control2: CGPoint(x: 23, y: 53))
    for (x, y) in [(14, 128), (27, 128), (32, 200), (44, 200), (48, 140), (52, 140), (56, 200), (68, 200), (73, 128), (86, 128), (79, 70)] {
        p.addLine(to: CGPoint(x: x, y: y))
    }
    p.addCurve(to: CGPoint(x: 50, y: 43), control1: CGPoint(x: 77, y: 53), control2: CGPoint(x: 67, y: 43))
    p.closeSubpath()
    return p
}

/// Draws the icon in a 512×512, y-down design space. The body sits exactly on Apple's icon grid
/// (824 of 1024, centred) with nothing outside it and no baked-in shadow: macOS 26 puts icons
/// that stray from that shape into a grey frame.
func drawIcon(_ ctx: CGContext) {
    let square = CGRect(x: 50, y: 50, width: 412, height: 412)
    let squircle = CGPath(roundedRect: square, cornerWidth: 92, cornerHeight: 92, transform: nil)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    ctx.addPath(squircle)
    ctx.setFillColor(rgb(0x161618))
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    // Spotlight beam.
    ctx.saveGState()
    ctx.move(to: CGPoint(x: 206, y: 50))
    for (x, y) in [(306, 50), (420, 462), (92, 462)] { ctx.addLine(to: CGPoint(x: x, y: y)) }
    ctx.closePath()
    ctx.clip()
    let beam = CGGradient(colorsSpace: space, colors: [rgb(0xFFD27A, 0.55), rgb(0xFFB340, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(beam, start: CGPoint(x: 256, y: 50), end: CGPoint(x: 256, y: 462), options: [])
    ctx.restoreGState()
    // Floor glow.
    ctx.saveGState()
    ctx.translateBy(x: 256, y: 420)
    ctx.scaleBy(x: 1, y: 30.0 / 150.0)
    let floor = CGGradient(colorsSpace: space, colors: [rgb(0xFFC864, 0.75), rgb(0xFFC864, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(floor, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 150, options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    ctx.addPath(CGPath(roundedRect: square.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 91.5, cornerHeight: 91.5, transform: nil))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.08))
    ctx.setLineWidth(1)
    ctx.strokePath()

    // The figure, standing in the spotlight on the floor glow.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    ctx.translateBy(x: 182, y: 104)
    ctx.scaleBy(x: 1.48, y: 1.48)
    ctx.addPath(figurePath())
    ctx.setFillColor(rgb(0xF5F1EA))
    ctx.fillPath()
    ctx.restoreGState()
}

func writePNG(pixels: Int, to url: URL) throws {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(pixels) / 512
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: s, y: -s)
    drawIcon(ctx)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try writePNG(pixels: size, to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try writePNG(pixels: size * 2, to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
print("Wrote \(out.path)")
