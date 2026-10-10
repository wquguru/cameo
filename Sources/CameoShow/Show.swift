import Foundation

/// A clip scheduled to play, with what ends it.
public struct Play: Equatable {
    public var clip: ClipSpec
    /// Finite clips: how many passes.
    public var repeats: Int?
    /// Looping clips: minimum seconds before ending (at the end of a cycle).
    public var holdTime: Double?
    /// Walk: the x to stop at, or nil to wander until `holdTime`, turning at the edges.
    public var target: Double?
    /// Walk: +1 right, -1 left.
    public var direction: Double = 1

    public init(clip: ClipSpec, repeats: Int? = nil, holdTime: Double? = nil, target: Double? = nil, direction: Double = 1) {
        self.clip = clip; self.repeats = repeats; self.holdTime = holdTime; self.target = target; self.direction = direction
    }
}

/// The scheduler: strings clips into an iStripper-style show (enter walking, stop, turn to front,
/// idle, act, idle, turn, walk on) using only legal pose transitions. Pure logic; the host feeds
/// it time and screen position and draws `play.clip` at `frameIndex`, mirrored when `mirrored`.
public final class Show {
    public let clips: [ClipSpec]
    public let graph: ClipGraph
    /// Screen points per canvas pixel; scales walking speed.
    public var pointsPerPixel: Double = 1
    /// Dragged: time stands still and nothing moves.
    public var held = false
    /// Poses that are never mirrored (symmetric by assumption).
    public var unmirroredPoses: Set<String> = ["front"]

    public private(set) var play: Play
    public private(set) var elapsed: Double = 0
    /// Pose at the end of the current play.
    public private(set) var pose: String
    public private(set) var facingLeft = false
    /// Counts started plays, so a host can notice changes.
    public private(set) var playIndex = 0

    private let nativeLeft: Bool
    private var queue: [Play] = []
    private var stopAt: Double?
    private var pokePending = false
    private var x: Double = 0
    private var bounds: ClosedRange<Double> = 0...1
    private var direction: Double = 1
    private let random: () -> Double

    public init(clips: [ClipSpec], facingLeft: Bool = false, random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        let usable = clips.filter { $0.kind != .drag }
        self.clips = usable
        graph = ClipGraph(clips: usable)
        nativeLeft = facingLeft
        self.random = random
        let first = usable.first { $0.kind == .walk } ?? usable.first { $0.kind == .idle } ?? usable[0]
        pose = first.from
        play = Play(clip: first, repeats: 1)
    }

    // MARK: Queries

    private var walkClip: ClipSpec? { clips.first { $0.kind == .walk } }
    private var idleClip: ClipSpec? { clips.first { $0.kind == .idle } }

    /// Whether the current play should be drawn mirrored.
    public var mirrored: Bool {
        let involved = !unmirroredPoses.contains(play.clip.from) || !unmirroredPoses.contains(play.clip.to)
        return involved && facingLeft != nativeLeft
    }

    public var frameIndex: Int {
        let n = max(1, play.clip.frames)
        return Int(elapsed * play.clip.fps) % n
    }

    // MARK: Control

    /// Starts the show; returns where the figure should stand: at a screen edge when it can walk in.
    public func start(bounds: ClosedRange<Double>, x: Double) -> Double {
        self.bounds = bounds
        var startX = x
        if let walk = walkClip {
            let fromLeft = random() < 0.5
            startX = fromLeft ? bounds.lowerBound : bounds.upperBound
            let dir: Double = fromLeft ? 1 : -1
            let span = bounds.upperBound - bounds.lowerBound
            let target = startX + dir * span * (0.25 + 0.5 * random())
            pose = walk.from
            planStroll(direction: dir, target: target, maxTime: nil)
        } else {
            startX = (bounds.lowerBound + bounds.upperBound) / 2
            pose = (idleClip ?? clips[0]).from
            planStill()
        }
        self.x = startX
        activateNext()
        return startX
    }

    /// A click on the figure: play a random action at the next opportunity.
    public func poke() {
        guard !held, clips.contains(where: { $0.kind == .action }) else { return }
        pokePending = true
    }

    /// Advances the show by `dt` seconds with the figure standing at `x`; returns how far (points,
    /// signed) the figure should move.
    @discardableResult
    public func tick(dt: Double, x: Double, bounds: ClosedRange<Double>) -> Double {
        self.x = x
        self.bounds = bounds
        guard !held else { return 0 }
        elapsed += dt
        var dx = 0.0
        let cycle = play.clip.cycle

        if play.clip.kind == .walk {
            let step = play.clip.speed * pointsPerPixel * dt
            let moved = Walker.advance(x: x, direction: direction, distance: step, bounds: bounds)
            dx = moved.x - x
            direction = moved.direction
            facingLeft = direction < 0
            if stopAt == nil {
                var done = pokePending || (play.holdTime.map { elapsed >= $0 } ?? false)
                if let target = play.target {
                    if (play.direction > 0 && moved.x >= target) || (play.direction < 0 && moved.x <= target) { done = true }
                    if moved.bounced { done = true }
                }
                if done { stopAt = (elapsed / cycle).rounded(.up) * cycle }
            }
        } else if play.repeats == nil, stopAt == nil, pokePending || elapsed >= (play.holdTime ?? 0) {
            stopAt = (elapsed / cycle).rounded(.up) * cycle
        }

        let end = play.repeats.map { Double($0) * cycle } ?? stopAt
        if let end, elapsed >= end {
            finishPlay(carry: elapsed - end)
        }
        return dx
    }

    // MARK: Planning

    private func finishPlay(carry: Double) {
        pose = play.clip.to
        if pokePending {
            pokePending = false
            queue.removeAll()
            planAction()
        }
        if queue.isEmpty { plan() }
        activateNext()
        elapsed = min(carry, play.clip.cycle * 0.999)
    }

    private func activateNext() {
        play = queue.removeFirst()
        elapsed = 0
        stopAt = nil
        playIndex += 1
        if play.clip.kind == .walk {
            direction = play.direction
            facingLeft = direction < 0
        }
    }

    private func plan() {
        guard walkClip != nil, idleClip != nil else { return planStill() }
        let span = bounds.upperBound - bounds.lowerBound
        if random() < 0.2 {
            planStroll(direction: random() < 0.5 ? 1 : -1, target: nil, maxTime: 6 + 8 * random())
        } else {
            var target = bounds.lowerBound + span * random()
            if abs(target - x) < span * 0.15 { target = x < bounds.lowerBound + span / 2 ? x + span * 0.3 : x - span * 0.3 }
            planStroll(direction: target >= x ? 1 : -1, target: target, maxTime: nil)
        }
    }

    /// Walk (to a point, or wandering), settle into idle, maybe act.
    private func planStroll(direction dir: Double, target: Double?, maxTime: Double?) {
        guard let walk = walkClip, let idle = idleClip,
              let toWalk = graph.path(from: pose, to: walk.from),
              let fromWalk = graph.path(from: walk.to, to: idle.from) else { return planStill() }
        facingLeft = dir < 0
        queue += toWalk.map { Play(clip: $0, repeats: 1) }
        queue.append(Play(clip: walk, holdTime: maxTime, target: target, direction: dir))
        queue += fromWalk.map { Play(clip: $0, repeats: 1) }
        queue.append(Play(clip: idle, holdTime: 2 + 3 * random()))
        if random() < 0.7 { appendAction(from: idle.to) }
    }

    /// Stay put: idle, maybe act (also the fallback when the walk cannot be linked up).
    private func planStill() {
        guard let idle = idleClip else {
            queue.append(Play(clip: clips[0], holdTime: 3))
            return
        }
        if let path = graph.path(from: pose, to: idle.from) { queue += path.map { Play(clip: $0, repeats: 1) } }
        queue.append(Play(clip: idle, holdTime: 3 + 3 * random()))
        if random() < 0.7 { appendAction(from: idle.to) }
    }

    private func planAction() {
        appendAction(from: pose)
    }

    /// Path to a random reachable action, the action, and back to idle for a moment.
    private func appendAction(from start: String, then idle: ClipSpec? = nil) {
        let idle = idle ?? idleClip
        let options: [(ClipSpec, [ClipSpec])] = clips.filter { $0.kind == .action }.compactMap { action in
            guard let there = graph.path(from: start, to: action.from) else { return nil }
            if let idle, graph.path(from: action.to, to: idle.from) == nil { return nil }
            return (action, there)
        }
        guard !options.isEmpty else { return }
        let (action, there) = options[min(options.count - 1, Int(random() * Double(options.count)))]
        queue += there.map { Play(clip: $0, repeats: 1) }
        queue.append(Play(clip: action, repeats: action.repeatCount))
        guard let idle else { return }
        queue += (graph.path(from: action.to, to: idle.from) ?? []).map { Play(clip: $0, repeats: 1) }
        queue.append(Play(clip: idle, holdTime: 1.5 + 1.5 * random()))
    }
}
