import Foundation
import Testing
@testable import CameoShow

private func win(_ id: Int, x: Double, y: Double, w: Double, h: Double) -> Ledge {
    Ledge(id: id, minX: x, maxX: x + w, minY: y, maxY: y + h)
}

/// A figure 300 tall reaching 60 either side, under a 1000-high visible area.
private func land(_ x: Double, _ y: Double, _ windows: [Ledge]) -> Ledge? {
    Ledges.landing(x: x, y: y, halfWidth: 60, height: 300, ceiling: 1000, windows: windows)
}

@Suite struct LedgesTests {
    @Test func landsOnTheWindowUnderTheFeet() {
        let w = win(1, x: 100, y: 200, w: 400, h: 300)  // top at 500
        #expect(land(300, 700, [w])?.id == 1)
        #expect(land(300, 500, [w])?.id == 1)            // already standing on it
    }

    @Test func groundWhenNothingIsUnderTheFeet() {
        let w = win(1, x: 100, y: 200, w: 400, h: 300)
        #expect(land(50, 700, [w]) == nil)               // beside it
        #expect(land(300, 400, [w]) == nil)              // dropped below its top
    }

    @Test func picksTheHighestTopBelowTheFeet() {
        let low = win(1, x: 0, y: 100, w: 600, h: 200)   // top 300
        let high = win(2, x: 0, y: 100, w: 600, h: 400)  // top 500, behind `low`
        #expect(land(300, 800, [low, high])?.id == 2)
        #expect(land(300, 450, [low, high])?.id == 1)    // below the high top: the lower one
    }

    @Test func skipsWindowsTooNarrowOrWithoutHeadroom() {
        #expect(land(150, 700, [win(1, x: 100, y: 200, w: 100, h: 300)]) == nil)   // 100 < 120
        #expect(land(300, 900, [win(1, x: 100, y: 200, w: 400, h: 600)]) == nil)   // 800 + 300 > 1000
    }

    @Test func skipsATopHiddenByAWindowInFront() {
        let back = win(1, x: 100, y: 200, w: 400, h: 300)    // top 500
        let front = win(2, x: 250, y: 400, w: 300, h: 300)  // covers x 250...550 at y 504
        #expect(land(300, 800, [front, back])?.id == 2)     // lands on the front one instead
        #expect(land(150, 800, [front, back])?.id == 1)     // the uncovered part of the back one
    }

    @Test func tracksAMovedWindowAndReportsWhenItIsGone() {
        let start = win(7, x: 100, y: 200, w: 400, h: 300)
        let moved = win(7, x: 180, y: 260, w: 400, h: 300)
        #expect(Ledges.track(start, x: 300, halfWidth: 60, windows: [moved])?.window == moved)
        #expect(Ledges.track(start, x: 300, halfWidth: 60, windows: [moved])?.covered == false)
        #expect(Ledges.track(start, x: 300, halfWidth: 60, windows: []) == nil)
        #expect(Ledges.track(start, x: 300, halfWidth: 60, windows: [win(7, x: 100, y: 200, w: 80, h: 300)]) == nil)
    }

    @Test func reportsAWindowCoveringTheSpot() {
        let start = win(7, x: 100, y: 200, w: 400, h: 300)
        let cover = win(8, x: 0, y: 300, w: 800, h: 400)
        #expect(Ledges.track(start, x: 300, halfWidth: 60, windows: [cover, start])?.covered == true)
        #expect(Ledges.track(start, x: 300, halfWidth: 60, windows: [start, cover])?.covered == false)  // it is behind
    }
}
