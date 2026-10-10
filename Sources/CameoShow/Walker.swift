import Foundation

/// Ground movement along the screen bottom.
public enum Walker {
    /// Moves `x` by `distance` in `direction` (+1 right, -1 left), turning round at the bounds.
    public static func advance(x: Double, direction: Double, distance: Double, bounds: ClosedRange<Double>)
        -> (x: Double, direction: Double, bounced: Bool) {
        let moved = x + direction * distance
        if moved < bounds.lowerBound { return (bounds.lowerBound, 1, true) }
        if moved > bounds.upperBound { return (bounds.upperBound, -1, true) }
        return (moved, direction, false)
    }
}
