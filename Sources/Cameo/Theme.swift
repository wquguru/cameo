import SwiftUI

/// The "stage spotlight" palette, used where the app shows the stage: the lit character card,
/// the update dot and the menu bar badge. Everything else uses system colours (see design/).
enum Theme {
    static let spotlight = Color(red: 1, green: 0.702, blue: 0.251)        // #FFB340
    static let stage = Color(red: 0.086, green: 0.086, blue: 0.094)        // #161618
    static let figure = Color(red: 0.961, green: 0.945, blue: 0.918)       // #F5F1EA
}

/// The shared figure silhouette, drawn from its 100×204 design space into any rect.
struct FigureShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: 33, y: 5, width: 34, height: 34))
        p.move(to: CGPoint(x: 50, y: 43))
        p.addCurve(to: CGPoint(x: 21, y: 70), control1: CGPoint(x: 33, y: 43), control2: CGPoint(x: 23, y: 53))
        for (x, y) in [(14, 128), (27, 128), (32, 200), (44, 200), (48, 140), (52, 140), (56, 200), (68, 200), (73, 128), (86, 128), (79, 70)] {
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addCurve(to: CGPoint(x: 50, y: 43), control1: CGPoint(x: 77, y: 53), control2: CGPoint(x: 67, y: 43))
        p.closeSubpath()
        let s = min(rect.width / 100, rect.height / 204)
        let dx = rect.midX - 50 * s, dy = rect.maxY - 204 * s
        return p.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: dx, ty: dy))
    }
}

/// The spotlight beam: a trapezoid widening towards the floor.
struct BeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.92, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
