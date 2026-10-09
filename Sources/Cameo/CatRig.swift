import CoreGraphics
import Foundation

enum CatLeg: CaseIterable { case farHind, nearHind, farFront, nearFront }

/// Joint angles in degrees. Legs and tail rotate about their roots (+ = clockwise on screen,
/// i.e. a leg swings backward); `tilt` rotates the body (− = front up); `head` rotates about the neck.
struct CatPose {
    var tilt: CGFloat = 0
    var farHind: CGFloat = 5, nearHind: CGFloat = -5, farFront: CGFloat = -5, nearFront: CGFloat = 5
    var tail: CGFloat = 0
    var head: CGFloat = 0
    var headDrop: CGFloat = 0
    /// Front-leg length multiplier, so the front paws can reach the floor while sitting.
    var frontLength: CGFloat = 1

    static let stand = CatPose()
    static let sit = CatPose(tilt: -26, farHind: -56, nearHind: -62, farFront: 22, nearFront: 28, tail: -38, head: 22, headDrop: 0, frontLength: 1.7)
    static let prone = CatPose(tilt: 0, farHind: -72, nearHind: -78, farFront: -86, nearFront: -90, tail: -85, head: 6, headDrop: 8)
    static let curl = CatPose(tilt: 0, farHind: -70, nearHind: -76, farFront: -62, nearFront: -68, tail: -110, head: 24, headDrop: 6)
    static let dangle = CatPose(tilt: -12, farHind: 6, nearHind: 18, farFront: 4, nearFront: 16, tail: -150, head: 14, headDrop: 0)

    func approaching(_ target: CatPose, rate: CGFloat) -> CatPose {
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * rate }
        return CatPose(
            tilt: mix(tilt, target.tilt), farHind: mix(farHind, target.farHind), nearHind: mix(nearHind, target.nearHind),
            farFront: mix(farFront, target.farFront), nearFront: mix(nearFront, target.nearFront),
            tail: mix(tail, target.tail), head: mix(head, target.head), headDrop: mix(headDrop, target.headDrop),
            frontLength: mix(frontLength, target.frontLength))
    }

    func angle(of leg: CatLeg) -> CGFloat {
        switch leg {
        case .farHind: farHind
        case .nearHind: nearHind
        case .farFront: farFront
        case .nearFront: nearFront
        }
    }
}

/// Turns a pose into per-part transforms: tilts and spins the body, rests the lowest point on the
/// ground, centres the body horizontally, mirrors when facing left, and scales to the view.
enum CatRig {
    /// The drawing space, in design units.
    static let canvas = CGSize(width: 440, height: 380)
    static let ground: CGFloat = 368

    struct Frame {
        var world: CGAffineTransform
        var body: CGAffineTransform
        var tail: CGAffineTransform
        var head: CGAffineTransform
        var legs: [CatLeg: CGAffineTransform]
        var shadowCenter: CGPoint
        var eyeOpenness: CGFloat
    }

    private static func rotate(_ degrees: CGFloat, about p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -p.x, y: -p.y)
            .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
    }

    private static func parts(_ pose: CatPose, spin: CGFloat) -> (body: CGAffineTransform, tail: CGAffineTransform, head: CGAffineTransform, legs: [CatLeg: CGAffineTransform]) {
        let tilt = rotate(pose.tilt, about: CGPoint(x: 130, y: 240))
        let center = CatArt.bodyCenter.applying(tilt)
        let body = tilt.concatenating(rotate(spin, about: center))
        let tail = CGAffineTransform(rotationAngle: pose.tail * .pi / 180)
            .concatenating(CGAffineTransform(translationX: CatArt.tailRoot.x, y: CatArt.tailRoot.y))
            .concatenating(body)
        let head = rotate(pose.head, about: CatArt.neck)
            .concatenating(CGAffineTransform(translationX: 0, y: pose.headDrop))
            .concatenating(body)
        var legs: [CatLeg: CGAffineTransform] = [:]
        for leg in CatLeg.allCases {
            let pivot = CatArt.legPivots[leg]!
            let length = leg == .farFront || leg == .nearFront ? pose.frontLength : 1
            legs[leg] = CGAffineTransform(scaleX: 1, y: length)
                .concatenating(CGAffineTransform(rotationAngle: pose.angle(of: leg) * .pi / 180))
                .concatenating(CGAffineTransform(translationX: pivot.x, y: pivot.y))
                .concatenating(body)
        }
        return (body, tail, head, legs)
    }

    private static let bodySamples = [(62, 206), (118, 258), (210, 258), (250, 204), (156, 154), (112, 152), (196, 154), (66, 232), (240, 236), (90, 252), (180, 258)]
        .map { CGPoint(x: $0.0, y: $0.1) }
    private static let headSamples: [CGPoint] = (0..<16).map { i in
        let a = CGFloat(i) * .pi / 8
        return CGPoint(x: 236 + 86 * cos(a), y: 120 + 76 * sin(a))
    } + [CGPoint(x: 216, y: 16), CGPoint(x: 300, y: 22)]
    private static let tailSamples = [(0, 15), (-42, -84), (-18, -100), (-30, -50), (-50, -40), (-57, -84), (-27, -84), (-18, -115), (-45, -25), (-15, -15)]
        .map { CGPoint(x: $0.0, y: $0.1) }
    private static let pawSamples = [CGPoint(x: 0, y: 50), CGPoint(x: -10, y: 46), CGPoint(x: 10, y: 46), CGPoint(x: -13, y: 20), CGPoint(x: 13, y: 20)]

    static func frame(pose: CatPose, spin: CGFloat, facingLeft: Bool, eyeOpenness: CGFloat, viewSize: CGSize) -> Frame {
        var p = parts(pose, spin: spin)
        var lowest = -CGFloat.infinity
        func consider(_ points: [CGPoint], _ t: CGAffineTransform) {
            for q in points { lowest = max(lowest, q.applying(t).y) }
        }
        consider(bodySamples, p.body)
        consider(headSamples, p.head)
        consider(tailSamples, p.tail)
        for leg in CatLeg.allCases { consider(pawSamples, p.legs[leg]!) }

        let center = CatArt.bodyCenter.applying(p.body)
        var place = CGAffineTransform(translationX: canvas.width / 2 - center.x, y: ground - lowest)
        if facingLeft {
            place = place.concatenating(CGAffineTransform(translationX: -canvas.width / 2, y: 0))
                .concatenating(CGAffineTransform(scaleX: -1, y: 1))
                .concatenating(CGAffineTransform(translationX: canvas.width / 2, y: 0))
        }
        let s = viewSize.height / canvas.height
        let world = CGAffineTransform(scaleX: s, y: s)
            .concatenating(CGAffineTransform(translationX: (viewSize.width - canvas.width * s) / 2, y: 0))
        let toView = place.concatenating(world)
        p.body = p.body.concatenating(toView)
        p.tail = p.tail.concatenating(toView)
        p.head = p.head.concatenating(toView)
        for leg in CatLeg.allCases { p.legs[leg] = p.legs[leg]!.concatenating(toView) }
        return Frame(world: world, body: p.body, tail: p.tail, head: p.head, legs: p.legs,
                     shadowCenter: CGPoint(x: canvas.width / 2, y: ground), eyeOpenness: eyeOpenness)
    }
}
