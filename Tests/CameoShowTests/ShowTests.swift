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
private func run(_ show: Show, seconds: Double, bounds: ClosedRange<Double> = 0...1000,
                 onTick: ((Show) -> Void)? = nil) -> (plays: [Play], xs: [Double]) {
    var x = show.start(bounds: bounds, x: 500)
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

    @Test func walkerTurnsAtEdges() {
        let b = 0.0...100.0
        let right = Walker.advance(x: 95, direction: 1, distance: 10, bounds: b)
        #expect(right.x == 100 && right.direction == -1 && right.bounced)
        let left = Walker.advance(x: 4, direction: -1, distance: 10, bounds: b)
        #expect(left.x == 0 && left.direction == 1 && left.bounced)
        let free = Walker.advance(x: 50, direction: -1, distance: 10, bounds: b)
        #expect(free.x == 40 && free.direction == -1 && !free.bounced)
    }

    @Test func wanderingFlipsAtEdges() {
        // Force wandering plays by making the random source always small.
        let show = Show(clips: basic, random: { 0.01 })
        var flips = 0
        var last = false
        var started = false
        let (_, xs) = run(show, seconds: 60) { s in
            if s.play.clip.kind == .walk {
                if started && s.facingLeft != last { flips += 1 }
                last = s.facingLeft; started = true
            }
        }
        #expect(flips >= 1)
        #expect(xs.allSatisfy { (0...1000).contains($0) })
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
        var x = show.start(bounds: 0...1000, x: 500)
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
