import Foundation

/// Ground movement along the screen bottom.
public enum Walker {
    /// Moves `x` by `distance` in `direction` (+1 right, -1 left), stopping at the bound ahead.
    /// A figure outside the bounds walks back in freely; heading further out it stays put.
    public static func advance(x: Double, direction: Double, distance: Double, bounds: ClosedRange<Double>)
        -> (x: Double, bounced: Bool) {
        let moved = x + direction * distance
        if direction > 0, moved > bounds.upperBound { return (max(x, bounds.upperBound), true) }
        if direction < 0, moved < bounds.lowerBound { return (min(x, bounds.lowerBound), true) }
        return (moved, false)
    }
}
