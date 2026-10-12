import Foundation

/// A window on screen, as a place to stand: its frame in screen points (y up), and its system
/// window number so it can be followed while it moves.
public struct Ledge: Equatable {
    public var id: Int
    public var minX: Double
    public var maxX: Double
    public var minY: Double
    public var maxY: Double

    public init(id: Int, minX: Double, maxX: Double, minY: Double, maxY: Double) {
        (self.id, self.minX, self.maxX, self.minY, self.maxY) = (id, minX, maxX, minY, maxY)
    }

    /// The top edge, where feet go.
    public var top: Double { maxY }
}

/// Window tops as ground: which one a figure lands on, and whether it can stay there.
/// Pure geometry; the app feeds it the on-screen windows, frontmost first.
public enum Ledges {
    /// The highest window top at or below `y` under feet at `x`, wide enough for a body reaching
    /// `halfWidth` either side, with room above it up to `ceiling` for a figure `height` tall, and
    /// not covered there by a window in front of it. Nil means the ground.
    public static func landing(x: Double, y: Double, halfWidth: Double, height: Double, ceiling: Double,
                               windows: [Ledge], tolerance: Double = 2) -> Ledge? {
        var best: Ledge?
        for (i, w) in windows.enumerated() {
            guard w.top <= y + tolerance, x >= w.minX, x <= w.maxX,
                  w.maxX - w.minX >= 2 * halfWidth, w.top + height <= ceiling,
                  !covered(at: x, top: w.top, by: windows[..<i]) else { continue }
            if best.map({ w.top > $0.top }) ?? true { best = w }
        }
        return best
    }

    /// Where feet let go at `y` come to stand: on the window top (`landing`) or the `bottom` up to
    /// `within` below them, else right there in the air (`floor`, the height to keep).
    public static func settle(y: Double, landing: Ledge?, bottom: Double, within: Double) -> (ledge: Ledge?, floor: Double?) {
        if let landing, y - landing.top <= within { return (landing, nil) }
        return (nil, y - bottom > within ? y : nil)
    }

    /// The window a figure standing on `ledge` is on now (it may have moved), and whether a window
    /// in front covers the spot where its feet would be. Nil when the window is gone (closed,
    /// minimised, on another Space) or too narrow. Callers let go only after a few misses in a
    /// row: while a window is dragged, the window list can briefly put another one in front.
    public static func track(_ ledge: Ledge, x: Double, halfWidth: Double, windows: [Ledge]) -> (window: Ledge, covered: Bool)? {
        guard let i = windows.firstIndex(where: { $0.id == ledge.id }) else { return nil }
        let w = windows[i]
        guard w.maxX - w.minX >= 2 * halfWidth else { return nil }
        let feet = min(max(x + (w.minX - ledge.minX), w.minX + halfWidth), w.maxX - halfWidth)
        return (w, covered(at: feet, top: w.top, by: windows[..<i]))
    }

    /// Whether a window in front hides the spot just above `top` at `x` (where feet would stand).
    static func covered(at x: Double, top: Double, by front: ArraySlice<Ledge>) -> Bool {
        front.contains { $0.minX <= x && x <= $0.maxX && $0.minY <= top + 4 && top + 4 <= $0.maxY }
    }
}
