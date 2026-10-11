import Foundation
import Testing
@testable import CameoShow

private func clip(_ id: String, _ kind: ClipKind, _ from: String, _ to: String, loop: Bool = false,
                  speed: Double = 0, repeats: Int = 1, frames: Int = 10) -> ClipSpec {
    ClipSpec(id: id, kind: kind, from: from, to: to, loop: loop, fps: 10, speed: speed, repeatCount: repeats, frames: frames)
}

private let basic: [ClipSpec] = [
    clip("idle", .idle, "front", "front", loop: true),
    clip("walk", .walk, "side", "side", loop: true, speed: 100),
    clip("to_front", .transition, "side", "front"),
    clip("to_side", .transition, "front", "side"),
    clip("wave", .action, "front", "front", repeats: 2),
    clip("bow", .action, "front", "front"),
]

private func seeded(_ seed: UInt64) -> () -> Double {
    var state = seed
    return {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

/// Runs a show for `seconds`, returning the plays in order and the x positions visited.
private func run(_ show: Show, seconds: Double, bounds: ClosedRange<Double> = 0...1000, entering: Double? = nil,
                 onTick: ((Show) -> Void)? = nil) -> (plays: [Play], xs: [Double]) {
    show.start(bounds: bounds, x: 500, entering: entering)
    var x = entering ?? 500
    var plays = [show.play], xs = [x]
    var index = show.playIndex
    var t = 0.0
    while t < seconds {
        x += show.tick(dt: 0.05, x: x, bounds: bounds)
        t += 0.05
        xs.append(x)
        onTick?(show)
        if show.playIndex != index { index = show.playIndex; plays.append(show.play) }
    }
    return (plays, xs)
}

@Suite struct ShowTests {
    @Test func onlyLegalTransitions() {
        for seed in 1...5 as ClosedRange<UInt64> {
            let show = Show(clips: basic, random: seeded(seed))
            let (plays, _) = run(show, seconds: 600)
            #expect(plays.count > 40)
            for (a, b) in zip(plays, plays.dropFirst()) {
                #expect(a.clip.to == b.clip.from, "\(a.clip.id) -> \(b.clip.id)")
            }
            #expect(plays.contains { $0.clip.kind == .action })
            #expect(plays.contains { $0.clip.kind == .walk })
        }
    }

    @Test func pathGoesThroughTransitions() {
        let graph = ClipGraph(clips: basic + [clip("side_to_back", .transition, "side", "back"), clip("back_to_side", .transition, "back", "side")])
        #expect(graph.path(from: "front", to: "front")?.isEmpty == true)
        #expect(graph.path(from: "front", to: "side")?.map(\.id) == ["to_side"])
        #expect(graph.path(from: "front", to: "back")?.map(\.id) == ["to_side", "side_to_back"])
        #expect(graph.path(from: "back", to: "front")?.map(\.id) == ["back_to_side", "to_front"])
        #expect(graph.path(from: "front", to: "nowhere") == nil)
    }

    @Test func pathIsShortest() {
        let clips = [clip("a", .transition, "p", "q"), clip("b", .transition, "q", "r"), clip("c", .transition, "p", "r")]
        #expect(ClipGraph(clips: clips).path(from: "p", to: "r")?.map(\.id) == ["c"])
    }

    @Test func walkerStopsAtEdges() {
        let b = 0.0...100.0
        let right = Walker.advance(x: 95, direction: 1, distance: 10, bounds: b)
        #expect(right.x == 100 && right.bounced)
        let left = Walker.advance(x: 4, direction: -1, distance: 10, bounds: b)
        #expect(left.x == 0 && left.bounced)
        let free = Walker.advance(x: 50, direction: -1, distance: 10, bounds: b)
        #expect(free.x == 40 && !free.bounced)
        // Outside the bounds: walking back in is free, walking further out doesn't move or jump.
        let back = Walker.advance(x: -30, direction: 1, distance: 10, bounds: b)
        #expect(back.x == -20 && !back.bounced)
        let out = Walker.advance(x: 130, direction: 1, distance: 10, bounds: b)
        #expect(out.x == 130 && out.bounced)
    }

    @Test func walksStopBeforeEdgesWithoutTurningMidStride() {
        for seed in 1...5 as ClosedRange<UInt64> {
            let show = Show(clips: basic, random: seeded(seed))
            var walking: (index: Int, left: Bool)?
            var hardStops = 0
            let (_, xs) = run(show, seconds: 600) { s in
                guard s.play.clip.kind == .walk else { walking = nil; return }
                if let w = walking, w.index == s.playIndex { #expect(w.left == s.facingLeft) }
                walking = (s.playIndex, s.facingLeft)
            }
            #expect(xs.allSatisfy { (0...1000).contains($0) })
            for (a, b) in zip(xs, xs.dropFirst()) where (a == 0 || a == 1000) && a == b { hardStops += 1 }
            #expect(hardStops == 0, "seed \(seed) pressed against an edge")
        }
    }

    @Test func entersFromOffScreenAndStartsStillOtherwise() {
        let show = Show(clips: basic, random: seeded(4))
        let (plays, xs) = run(show, seconds: 20, entering: -80)
        #expect(plays[0].clip.kind == .walk && plays[0].direction == 1)
        #expect(xs.contains { $0 >= 250 })
        let still = Show(clips: basic, random: seeded(4))
        still.start(bounds: 0...1000, x: 600)
        #expect(still.play.clip.kind == .idle)
        #expect(still.tick(dt: 0.05, x: 600, bounds: 0...1000) == 0)
    }

    @Test func droppedOutsideWalksBackWithoutJumping() {
        var x = 980.0
        let s = Show(clips: basic, random: seeded(7))
        s.start(bounds: 100...900, x: x)
        var maxStep = 0.0
        for _ in 0..<4000 {
            let dx = s.tick(dt: 0.05, x: x, bounds: 100...900)
            maxStep = max(maxStep, abs(dx))
            x += dx
        }
        #expect(maxStep <= 100 * 0.05 + 1e-9)
        #expect((100...900).contains(x))
    }

    @Test func stopsNearTarget() {
        // A target-bound walk ends within half a stride (speed × cycle / 2) of where it aimed,
        // unless the target is within a stride of an edge (stopping short of the edge wins).
        for seed in 1...5 as ClosedRange<UInt64> {
            let show = Show(clips: basic, random: seeded(seed))
            var current: Play?
            var x = 500.0
            show.start(bounds: 0...1000, x: x)
            for _ in 0..<12000 {
                x += show.tick(dt: 0.05, x: x, bounds: 0...1000)
                if current?.clip.kind == .walk, let target = current?.target, (100...900).contains(target), show.play != current {
                    #expect(abs(x - target) <= 100 * 1.0 / 2 + 5 + 1e-6, "seed \(seed): stopped at \(x) for \(target)")
                }
                current = show.play
            }
        }
    }

    @Test func mirroringFollowsDirectionButNotFront() {
        let show = Show(clips: basic, random: seeded(3))
        var sawLeftWalk = false, sawRightWalk = false
        _ = run(show, seconds: 300) { s in
            switch s.play.clip.kind {
            case .walk:
                #expect(s.mirrored == s.facingLeft)
                if s.facingLeft { sawLeftWalk = true } else { sawRightWalk = true }
            case .idle, .action: #expect(!s.mirrored)
            default: break
            }
        }
        #expect(sawLeftWalk && sawRightWalk)
    }

    @Test func heldFreezesAndPokeQueuesAction() {
        let show = Show(clips: basic, random: seeded(9))
        var x = 500.0
        show.start(bounds: 0...1000, x: x, entering: -50)
        x = -50
        for _ in 0..<5 { x += show.tick(dt: 0.05, x: x, bounds: 0...1000) }
        let frozen = (show.playIndex, show.elapsed)
        show.held = true
        for _ in 0..<100 { #expect(show.tick(dt: 0.05, x: x, bounds: 0...1000) == 0) }
        #expect(show.playIndex == frozen.0 && show.elapsed == frozen.1)
        show.held = false
        show.poke()
        var kinds: [ClipKind] = []
        var index = show.playIndex
        for _ in 0..<2000 {
            x += show.tick(dt: 0.05, x: x, bounds: 0...1000)
            if show.playIndex != index { index = show.playIndex; kinds.append(show.play.clip.kind) }
            if kinds.contains(.action) { break }
        }
        #expect(kinds.contains(.action))
        #expect(show.play.clip.from == "front")
    }

    @Test func manifestParsing() throws {
        let json = """
        {"spec":1,"name":"N","width":512,"height":768,"facing":"right","future":1,"clips":[
         {"id":"idle","file":"clips/idle.mov","kind":"idle","from":"front","to":"front","fps":6},
         {"id":"w","file":"clips/w.mov","kind":"walk","from":"side","to":"side","speed":95},
         {"id":"x","file":"clips/x.mov","kind":"mystery"}]}
        """
        let m = try PackageManifest.parse(Data(json.utf8))
        #expect(m.clips.map(\.id) == ["idle", "w"])
        #expect(m.clips[1].speed == 95 && m.clips[1].loop)
    }
}
