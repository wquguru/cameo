import CoreGraphics
import Foundation

enum CatAction: String, CaseIterable, Identifiable {
    case walk, sit, prone, stand, roll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk: "行走"
        case .sit: "蹲下"
        case .prone: "趴下"
        case .stand: "站立"
        case .roll: "打滚"
        }
    }
}

/// Decides what the cat does and animates its pose. `update` returns how far (design units)
/// the cat moved horizontally this frame; the caller moves the window and calls `turnAround`
/// when it hits a screen edge.
final class CatBrain {
    /// A user-chosen action; nil lets the cat pick on its own.
    var manual: CatAction? {
        didSet { if manual != oldValue { begin(manual ?? .stand) } }
    }
    var held = false

    private(set) var pose = CatPose.stand
    private(set) var spin: CGFloat = 0
    private(set) var facingLeft = false
    private(set) var eyeOpenness: CGFloat = 1

    private var action: CatAction = .stand
    private var time: Double = 0
    private var actionStart: Double = 0
    private var actionEnd: Double = 3
    private var phase: CGFloat = 0
    private var rollLeft: CGFloat = 0
    private var nextBlink: Double = 2
    private var blinkEnd: Double = 0

    static let walkSpeed: CGFloat = 86      // design units per second
    static let rollDegreesPerSecond: CGFloat = 320
    static let rollRadius: CGFloat = 72

    var currentAction: CatAction { action }

    func poke() {
        guard !held else { return }
        begin(.roll)
    }

    func turnAround() {
        facingLeft.toggle()
    }

    private func begin(_ next: CatAction) {
        action = next
        actionStart = time
        if next == .roll { rollLeft = 360 }
        let duration: ClosedRange<Double> = switch next {
        case .stand: 2...5
        case .walk: 3...8
        case .sit: 4...9
        case .prone: 7...16
        case .roll: 0...0
        }
        actionEnd = time + Double.random(in: duration)
    }

    private func pickNext() {
        let weights: [(CatAction, Double)] = switch action {
        case .stand: [(.walk, 6), (.sit, 2), (.prone, 1), (.roll, 1)]
        case .walk: [(.stand, 5), (.sit, 2), (.roll, 2), (.walk, 1)]
        case .sit: [(.stand, 6), (.prone, 3), (.walk, 1)]
        case .prone: [(.stand, 6), (.walk, 2), (.roll, 1)]
        case .roll: [(.stand, 6), (.walk, 3), (.prone, 1)]
        }
        if Bool.random(), action != .walk { facingLeft = Bool.random() }
        var pick = Double.random(in: 0..<weights.reduce(0) { $0 + $1.1 })
        for (candidate, weight) in weights {
            pick -= weight
            if pick < 0 { begin(candidate); return }
        }
        begin(.stand)
    }

    func update(_ dt: Double) -> CGFloat {
        time += dt
        let t = CGFloat(time)
        var target: CatPose
        var dx: CGFloat = 0
        var rate = min(1, CGFloat(dt) * 8)

        if held {
            target = .dangle
            target.tail += 10 * sin(t * 3)
            target.nearFront += 6 * sin(t * 4)
            target.farHind -= 6 * sin(t * 4)
        } else {
            if action == .roll && rollLeft <= 0 {
                if manual == .roll { rollLeft = 360 } else if manual != nil { begin(manual!) } else { pickNext() }
            } else if manual == nil, action != .roll, time >= actionEnd {
                pickNext()
            }

            switch action {
            case .stand:
                target = .stand
                target.tail += 8 * sin(t * 1.3)
                target.head += 2 * sin(t * 0.7)
            case .walk:
                phase += CGFloat(dt) * 2 * .pi / 0.9
                let a = 22 * sin(phase)
                target = .stand
                target.nearHind = a; target.farFront = a
                target.farHind = -a; target.nearFront = -a
                target.headDrop = 2 * abs(sin(phase))
                target.tail = 6 * sin(phase / 2)
                dx = Self.walkSpeed * CGFloat(dt)
                rate = min(1, CGFloat(dt) * 18)
            case .sit:
                target = .sit
                target.tail += 10 * sin(t * 1.1)
                target.head += 3 * sin(t * 0.6)
            case .prone:
                target = .prone
                target.tail += 5 * sin(t * 0.8)
            case .roll:
                target = .curl
                let d = Self.rollDegreesPerSecond * CGFloat(dt)
                // Curl up first, then roll.
                if time - actionStart > 0.25 {
                    spin += d
                    rollLeft -= d
                    dx = 2 * .pi * Self.rollRadius * d / 360
                }
                rate = min(1, CGFloat(dt) * 12)
            }
        }

        if action != .roll || held {
            let rest = (spin / 360).rounded() * 360
            spin += (rest - spin) * min(1, CGFloat(dt) * 8)
        }
        pose = pose.approaching(target, rate: rate)
        updateEyes()
        return facingLeft ? -dx : dx
    }

    private func updateEyes() {
        let sleeping = !held && action == .prone && time - actionStart > 4
        if time >= nextBlink {
            blinkEnd = time + 0.14
            nextBlink = time + Double.random(in: 2.5...6)
        }
        let target: CGFloat = sleeping || time < blinkEnd ? 0 : 1
        eyeOpenness += (target - eyeOpenness) * (sleeping ? 0.06 : 0.6)
    }
}
