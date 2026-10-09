import AppKit

/// The built-in silver tabby, side view facing right (design/cats: variant D).
/// Coordinates are the design's y-down units; `CatRig` supplies one transform per part.
enum CatArt {
    // Palette.
    static let outline = CGColor(srgbRed: 0.290, green: 0.306, blue: 0.329, alpha: 1)   // #4A4E54
    static let fur = CGColor(srgbRed: 0.894, green: 0.898, blue: 0.910, alpha: 1)       // #E4E5E8
    static let farFur = CGColor(srgbRed: 0.788, green: 0.796, blue: 0.812, alpha: 1)    // #C9CBCF
    static let backEar = CGColor(srgbRed: 0.839, green: 0.847, blue: 0.863, alpha: 1)   // #D6D8DC
    static let cream = CGColor(srgbRed: 0.984, green: 0.984, blue: 0.988, alpha: 1)     // #FBFBFC
    static let stripe = CGColor(srgbRed: 0.502, green: 0.518, blue: 0.541, alpha: 1)    // #80848A
    static let innerEar = CGColor(srgbRed: 0.949, green: 0.722, blue: 0.710, alpha: 1)  // #F2B8B5
    static let blush = CGColor(srgbRed: 0.961, green: 0.655, blue: 0.655, alpha: 0.6)   // #F5A7A7
    static let nose = CGColor(srgbRed: 0.898, green: 0.604, blue: 0.557, alpha: 1)      // #E59A8E
    static let whisker = CGColor(srgbRed: 0.643, green: 0.659, blue: 0.682, alpha: 1)   // #A4A8AE
    static let eyeRing = CGColor(srgbRed: 0.180, green: 0.200, blue: 0.180, alpha: 1)   // #2E332E
    static let pupil = CGColor(srgbRed: 0.102, green: 0.122, blue: 0.106, alpha: 1)     // #1A1F1B
    static let white = CGColor(gray: 1, alpha: 1)
    static let eyeGradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(srgbRed: 0.839, green: 0.894, blue: 0.706, alpha: 1),
            CGColor(srgbRed: 0.616, green: 0.698, blue: 0.514, alpha: 1),
            CGColor(srgbRed: 0.373, green: 0.459, blue: 0.322, alpha: 1),
        ] as CFArray,
        locations: [0, 0.65, 1])!

    // Legs: local space, pivot at the hip/shoulder (0, 0), paw at y ≈ 50.
    static let leg = CGPath(roundedRect: CGRect(x: -13, y: -4, width: 26, height: 54), cornerWidth: 13, cornerHeight: 13, transform: nil)
    static let legPivots: [CatLeg: CGPoint] = [.farHind: CGPoint(x: 104, y: 232), .nearHind: CGPoint(x: 132, y: 232),
                                               .farFront: CGPoint(x: 200, y: 232), .nearFront: CGPoint(x: 226, y: 232)]

    // Tail: local space, root at (0, 0) (design point 76, 200).
    static let tailRoot = CGPoint(x: 76, y: 200)
    static let tail = SVGPath.parse("M0 0 Q-54 -24 -42 -84 Q-36 -104 -18 -100")
    static let tailStripes = SVGPath.parse("M-32 -28 l12 -8 M-44 -54 l15 -2 M-40 -80 l14 6")

    // Body.
    static let body = SVGPath.parse("M112 152 Q62 156 62 206 Q64 256 118 258 L210 258 Q254 254 250 204 Q246 158 196 154 Z")
    static let belly = SVGPath.parse("M120 236 Q160 262 214 236 Q214 254 200 256 L124 256 Q112 252 120 236 Z")
    static let backStripes = SVGPath.parse("M108 160 Q116 180 104 196 M136 156 Q144 178 134 196 M164 156 Q172 176 164 192")
    static let bodyCenter = CGPoint(x: 156, y: 206)

    // Head (design space; rotated about `neck`).
    static let neck = CGPoint(x: 222, y: 172)
    static let backEarPath = SVGPath.parse("M190 70 Q184 14 216 16 Q234 40 238 60 Z")
    static let frontEarPath = SVGPath.parse("M256 62 Q270 8 300 22 Q300 56 292 78 Z")
    static let innerEarPath = SVGPath.parse("M266 62 Q276 28 292 32 Q292 54 286 70 Z")
    static let head = SVGPath.parse("M234 46 C294 46 322 82 322 122 C322 136 328 144 318 150 C312 176 284 194 236 194 C186 194 158 174 154 150 C146 142 150 134 150 122 C150 82 176 46 234 46 Z")
    static let muzzle = SVGPath.parse("M226 168 Q270 204 312 160 Q302 186 262 190 Q236 190 226 168 Z")
    static let foreheadStripes: [(CGPath, CGFloat)] = [
        (SVGPath.parse("M222 52 L226 82"), 6.5), (SVGPath.parse("M204 58 L212 82"), 5.5),
        (SVGPath.parse("M240 52 L240 78"), 5.5), (SVGPath.parse("M154 118 L174 124 M156 138 L176 138"), 5),
    ]
    static let nosePath = SVGPath.parse("M256 150 Q264 145 272 150 Q269 158 264 160 Q259 158 256 150 Z")
    static let mouth = SVGPath.parse("M254 168 Q259 175 264 167 Q269 175 274 168")
    static let whiskers = SVGPath.parse("M276 160 L318 154 M276 166 L318 168 M246 162 L212 158")

    struct Eye {
        let center: CGPoint, rx: CGFloat, ry: CGFloat, pupil: CGSize, highlights: [(CGPoint, CGFloat)]
    }
    static let eyes = [
        Eye(center: CGPoint(x: 220, y: 124), rx: 20, ry: 24, pupil: CGSize(width: 6.5, height: 14), highlights: [(CGPoint(x: -5, y: -10), 6), (CGPoint(x: 8, y: 9), 2.6)]),
        Eye(center: CGPoint(x: 284, y: 124), rx: 16, ry: 22, pupil: CGSize(width: 5.5, height: 13), highlights: [(CGPoint(x: -3, y: -9), 5), (CGPoint(x: 7, y: 8), 2.2)]),
    ]

    // MARK: Drawing

    static func draw(_ frame: CatRig.Frame, in ctx: CGContext) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        // Ground shadow.
        ctx.saveGState()
        ctx.concatenate(frame.world)
        ctx.addEllipse(in: CGRect(x: frame.shadowCenter.x - 100, y: frame.shadowCenter.y - 7, width: 200, height: 14))
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.18))
        ctx.fillPath()
        ctx.restoreGState()

        legPart(.farHind, frame, ctx, color: farFur)
        legPart(.farFront, frame, ctx, color: farFur)

        // Tail: outline stroke, fur stroke, stripes.
        with(ctx, frame.tail) {
            stroke(ctx, tail, outline, 30)
            stroke(ctx, tail, fur, 21)
            stroke(ctx, tailStripes, stripe, 6)
        }

        with(ctx, frame.body) {
            fillStroke(ctx, body, fur)
            fill(ctx, belly, cream)
            stroke(ctx, backStripes, stripe, 6)
        }

        legPart(.nearHind, frame, ctx, color: fur)
        legPart(.nearFront, frame, ctx, color: fur)

        with(ctx, frame.head) {
            fillStroke(ctx, backEarPath, backEar)
            fillStroke(ctx, frontEarPath, fur)
            fill(ctx, innerEarPath, innerEar)
            fillStroke(ctx, head, fur)
            fill(ctx, muzzle, cream)
            for (path, width) in foreheadStripes { stroke(ctx, path, stripe, width) }
            for eye in eyes { drawEye(eye, openness: frame.eyeOpenness, ctx) }
            ctx.addEllipse(in: CGRect(x: 183, y: 149.5, width: 26, height: 13))
            ctx.setFillColor(blush)
            ctx.fillPath()
            fillStroke(ctx, nosePath, nose, width: 3)
            stroke(ctx, mouth, outline, 3)
            stroke(ctx, whiskers, whisker, 2)
        }
    }

    private static func legPart(_ leg: CatLeg, _ frame: CatRig.Frame, _ ctx: CGContext, color: CGColor) {
        with(ctx, frame.legs[leg]!) { fillStroke(ctx, CatArt.leg, color) }
    }

    private static func drawEye(_ eye: Eye, openness: CGFloat, _ ctx: CGContext) {
        let c = eye.center
        if openness < 0.25 {
            // Closed: a content little curve.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: c.x - eye.rx, y: c.y))
            path.addQuadCurve(to: CGPoint(x: c.x + eye.rx, y: c.y), control: CGPoint(x: c.x, y: c.y + eye.ry * 0.7))
            stroke(ctx, path, eyeRing, 4)
            return
        }
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.scaleBy(x: 1, y: min(openness, 1))
        let rect = CGRect(x: -eye.rx, y: -eye.ry, width: eye.rx * 2, height: eye.ry * 2)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        ctx.drawRadialGradient(eyeGradient, startCenter: CGPoint(x: 0, y: eye.ry * 0.24), startRadius: 0,
                               endCenter: CGPoint(x: 0, y: eye.ry * 0.24), endRadius: eye.ry * 1.24, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
        ctx.addEllipse(in: rect)
        ctx.setStrokeColor(eyeRing)
        ctx.setLineWidth(4)
        ctx.strokePath()
        ctx.addEllipse(in: CGRect(x: 3 - eye.pupil.width, y: -eye.pupil.height, width: eye.pupil.width * 2, height: eye.pupil.height * 2))
        ctx.setFillColor(pupil)
        ctx.fillPath()
        ctx.setFillColor(white)
        for (p, r) in eye.highlights {
            ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    // MARK: Helpers

    private static func with(_ ctx: CGContext, _ t: CGAffineTransform, _ body: () -> Void) {
        ctx.saveGState()
        ctx.concatenate(t)
        body()
        ctx.restoreGState()
    }

    private static func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor) {
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    private static func fillStroke(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, width: CGFloat = 4.5) {
        fill(ctx, path, color)
        stroke(ctx, path, outline, width)
    }

    private static func stroke(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, _ width: CGFloat) {
        ctx.addPath(path)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }
}
