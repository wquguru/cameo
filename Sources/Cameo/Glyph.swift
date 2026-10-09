import AppKit

/// The Cameo mark as a line glyph: a screen whose top edge a head pokes out of.
/// Drawn in a 16×16, y-down space (see design/Logo.dc.html).
enum Glyph {
    /// Monochrome template image for the menu bar.
    static var template: NSImage {
        let image = image(size: 16, color: .black)
        image.isTemplate = true
        image.accessibilityDescription = "Cameo"
        return image
    }

    static func image(size: CGFloat, color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let s = rect.width / 16
            let t = AffineTransform(scaleByX: s, byY: s)

            let screen = NSBezierPath()
            screen.move(to: NSPoint(x: 5.8, y: 4.5))
            screen.appendArc(from: NSPoint(x: 2.5, y: 4.5), to: NSPoint(x: 2.5, y: 14.5), radius: 2)
            screen.appendArc(from: NSPoint(x: 2.5, y: 14.5), to: NSPoint(x: 13.5, y: 14.5), radius: 2)
            screen.appendArc(from: NSPoint(x: 13.5, y: 14.5), to: NSPoint(x: 13.5, y: 4.5), radius: 2)
            screen.appendArc(from: NSPoint(x: 13.5, y: 4.5), to: NSPoint(x: 2.5, y: 4.5), radius: 2)
            screen.line(to: NSPoint(x: 10.2, y: 4.5))

            let shoulders = NSBezierPath()
            shoulders.move(to: NSPoint(x: 5.5, y: 14.5))
            shoulders.line(to: NSPoint(x: 5.5, y: 12.3))
            for i in 0...24 {
                let a = Double.pi + Double.pi * Double(i) / 24
                shoulders.line(to: NSPoint(x: 8 + 2.5 * cos(a), y: 12.3 + 2.5 * sin(a)))
            }
            shoulders.line(to: NSPoint(x: 10.5, y: 14.5))

            color.setStroke()
            for path in [screen, shoulders] {
                path.transform(using: t)
                path.lineWidth = 1.4 * s
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }

            let head = NSBezierPath(ovalIn: NSRect(x: 6.2, y: 1.6, width: 3.6, height: 3.6))
            head.transform(using: t)
            color.setFill()
            head.fill()
            return true
        }
    }
}
