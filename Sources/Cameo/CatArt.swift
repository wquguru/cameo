import AppKit

/// The built-in cat, a silver tabby British Shorthair in a semi-realistic side view facing right,
/// modelled on the owner's photos. Coordinates are design units (y down); `CatRig` supplies
/// one transform per part.
enum CatArt {
    private static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    private static func gradient(_ stops: [(UInt32, CGFloat)]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                   colors: stops.map { rgb($0.0) } as CFArray, locations: stops.map(\.1))!
    }

    // Palette.
    static let edge = rgb(0x7A7F86, 0.5)
    static let stripe = rgb(0x5F646B, 0.75)
    static let legStripe = rgb(0x6C7178, 0.55)
    static let tailFur = rgb(0xB9BEC5)
    static let tailRing = rgb(0x5E636A, 0.85)
    static let tailTip = rgb(0x4E5258)
    static let backEarFur = rgb(0xA9AEB5)
    static let frontEarFur = rgb(0xB7BCC2)
    static let muzzleFur = rgb(0xEEF0F2)
    static let faceStripe = rgb(0x5F646B, 0.8)
    static let eyeLine = rgb(0x2E2A22)
    static let pupil = rgb(0x141414)
    static let white = rgb(0xFFFFFF)
    static let nose = rgb(0xB88D88)
    static let noseEdge = rgb(0x6E5A58)
    static let noseShine = rgb(0xD9B2AE)
    static let mouthLine = rgb(0x6E5E5C)
    static let whiskerDot = rgb(0x9DA2A9)
    static let whisker = rgb(0xFFFFFF, 0.9)
    static let toe = rgb(0x9A9EA5)
    static let bodyGradient = gradient([(0xA3A8AF, 0), (0xC6CAD0, 0.45), (0xECEEF0, 1)])
    static let legGradient = gradient([(0xBFC3C9, 0), (0xE4E6E9, 1)])
    static let farLegGradient = gradient([(0x9DA2A9, 0), (0xC3C7CC, 1)])
    static let headGradient = gradient([(0xE9EBEE, 0), (0xCACED3, 0.6), (0xA7ACB3, 1)])
    static let irisGradient = gradient([(0xE6DF92, 0), (0xC9C155, 0.6), (0x858139, 1)])
    static let innerEarGradient = gradient([(0xD9AFAC, 0), (0xEBCFCC, 1)])

    // Legs: local space, pivot at the hip/shoulder (0, 0), paw bottom at y = 66.
    static let hindLeg = SVGPath.parse("M-18 -10 C-20 15 -12 38 -10 55 C-11 62 -6 66 1 66 C9 66 13 62 11 55 C12 35 16 12 16 -10 Z")
    static let frontLeg = SVGPath.parse("M-12 -6 C-14 18 -11 42 -11 55 C-12 62 -6 66 0 66 C8 66 13 62 12 55 C12 40 13 18 12 -6 Z")
    static let hindStripes = SVGPath.parse("M-13 22 C-4 25 6 25 14 21 M-11 38 C-3 41 5 41 11 38")
    static let frontStripes = SVGPath.parse("M-12 20 C-4 23 4 23 12 20 M-11 36 C-3 39 5 39 12 36")
    static let toes = SVGPath.parse("M-4 59 L-4 65 M4 59 L4 65")
    static let legPivots: [CatLeg: CGPoint] = [.farHind: CGPoint(x: 104, y: 232), .nearHind: CGPoint(x: 132, y: 232),
                                               .farFront: CGPoint(x: 200, y: 232), .nearFront: CGPoint(x: 226, y: 232)]

    static func legPath(_ leg: CatLeg) -> CGPath {
        leg == .farHind || leg == .nearHind ? hindLeg : frontLeg
    }

    // Tail: local space, root at (0, 0) (design point 76, 200); drawn as thick strokes with rings.
    static let tailRoot = CGPoint(x: 76, y: 200)
    static let tail = SVGPath.parse("M0 0 C-30 -10 -50 -40 -44 -84 C-42 -98 -32 -104 -22 -100")
    static let tailTipPath = SVGPath.parse("M-34 -101 C-30 -103 -26 -102 -22 -100")
    static let tailWidth: CGFloat = 20

    // Body.
    static let body = SVGPath.parse("M100 150 C70 156 58 182 60 210 C62 244 86 262 122 264 L206 264 C238 262 256 240 254 208 C252 176 232 154 200 150 C170 146 130 146 100 150 Z")
    static let bodyStripes = SVGPath.parse("""
        M88 160 C96 178 92 200 82 214 C90 198 90 178 82 162 Z \
        M110 152 C118 172 114 196 104 212 C112 194 112 172 104 154 Z \
        M132 149 C140 170 136 194 128 208 C134 192 134 170 126 150 Z \
        M154 148 C162 168 158 190 150 204 C156 188 156 168 148 149 Z \
        M176 149 C184 168 180 188 172 200 C178 186 178 168 170 150 Z \
        M198 151 C204 166 202 182 196 192 C200 180 200 166 192 152 Z
        """)
    static let dorsalLine = SVGPath.parse("M96 154 C140 144 180 144 214 154")
    static let bellySheen = SVGPath.parse("M120 246 C150 258 190 258 220 246")
    static let bodyCenter = CGPoint(x: 156, y: 206)

    // Head: drawn in its own design space, then placed (scaled down) at the neck and rotated there.
    static let neck = CGPoint(x: 222, y: 172)
    static let headPlacement = CGAffineTransform(translationX: -222, y: -172)
        .concatenating(CGAffineTransform(scaleX: 0.82, y: 0.82))
        .concatenating(CGAffineTransform(translationX: 230, y: 176))
    // The face looks at the viewer (the body stays in profile), so it is symmetric about x = 240.
    static let backEar = SVGPath.parse("M168 92 C164 70 170 52 180 44 C196 50 208 60 214 66 Z")
    static let frontEar = SVGPath.parse("M312 92 C316 70 310 52 300 44 C284 50 272 60 266 66 Z")
    static let innerEars = SVGPath.parse("M176 82 C174 68 178 58 184 53 C194 58 202 64 206 68 Z M304 82 C306 68 302 58 296 53 C286 58 278 64 274 68 Z")
    static let head = SVGPath.parse("M240 52 C292 52 326 88 326 128 C326 166 290 192 240 192 C190 192 154 166 154 128 C154 88 188 52 240 52 Z")
    static let headCenter = CGPoint(x: 240, y: 122)
    static let muzzle = SVGPath.parse("M240 140 C226 136 212 142 210 154 C208 166 220 174 232 172 C236 171 238 169 240 166 C242 169 244 171 248 172 C260 174 272 166 270 154 C268 142 254 136 240 140 Z")
    static let faceStripes: [(CGPath, CGFloat)] = [
        (SVGPath.parse("M240 58 L240 84"), 3.5),
        (SVGPath.parse("M228 60 C229 70 231 78 233 86 M252 60 C251 70 249 78 247 86"), 3),
        (SVGPath.parse("M216 64 C218 72 221 80 224 86 M264 64 C262 72 259 80 256 86"), 2.5),
        (SVGPath.parse("M184 130 C176 132 168 132 160 128 M296 130 C304 132 312 132 320 128"), 2.5),
        (SVGPath.parse("M186 144 C178 148 170 148 162 146 M294 144 C302 148 310 148 318 146"), 2.5),
        (SVGPath.parse("M192 120 C187 123 181 125 175 125 M288 120 C293 123 299 125 305 125"), 2),
    ]
    static let nosePath = SVGPath.parse("M232 140 C236 137 244 137 248 140 C247 146 242 150 240 151 C238 150 233 146 232 140 Z")
    static let noseHighlight = SVGPath.parse("M236 140 C238 139 242 139 244 140")
    static let mouth = SVGPath.parse("M240 151 L240 158 M230 162 C235 165 238 163 240 158 C242 163 245 165 250 162")
    static let whiskerDots = [(224, 154), (220, 160), (226, 163), (256, 154), (260, 160), (254, 163)].map { CGPoint(x: $0.0, y: $0.1) }
    static let whiskers = SVGPath.parse("M222 156 C200 150 180 150 158 154 M222 162 C200 162 180 166 162 174 M258 156 C280 150 300 150 322 154 M258 162 C280 162 300 166 318 174")

    struct Eye {
        let center: CGPoint, rx: CGFloat, ry: CGFloat, pupil: CGSize, line: CGFloat, highlight: CGFloat
    }
    static let eyes = [CGPoint(x: 210, y: 116), CGPoint(x: 270, y: 116)].map {
        Eye(center: $0, rx: 17, ry: 18, pupil: CGSize(width: 7, height: 10), line: 2.8, highlight: 4.2)
    }

    // MARK: Drawing

    static func draw(_ frame: CatRig.Frame, in ctx: CGContext) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        // Ground shadow.
        ctx.saveGState()
        ctx.concatenate(frame.world)
        ctx.addEllipse(in: CGRect(x: frame.shadowCenter.x - 108, y: frame.shadowCenter.y - 7, width: 216, height: 14))
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.18))
        ctx.fillPath()
        ctx.restoreGState()

        // Everything else casts one soft shadow, so the cat reads on light and dark wallpapers.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2 * frame.scale), blur: 6 * frame.scale, color: CGColor(gray: 0, alpha: 0.28))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)

        drawLeg(.farHind, frame, ctx, far: true)
        drawLeg(.farFront, frame, ctx, far: true)

        with(ctx, frame.tail) {
            stroke(ctx, tail, edge, tailWidth + 3)
            stroke(ctx, tail, tailFur, tailWidth)
            ctx.saveGState()
            ctx.setLineCap(.butt)
            ctx.setLineDash(phase: -10, lengths: [7, 15])
            stroke(ctx, tail, tailRing, tailWidth)
            ctx.restoreGState()
            stroke(ctx, tailTipPath, tailTip, tailWidth - 1)
        }

        drawLeg(.nearHind, frame, ctx, far: false)
        drawLeg(.nearFront, frame, ctx, far: false)

        with(ctx, frame.body) {
            fillGradient(ctx, body, bodyGradient, from: CGPoint(x: 0, y: 146), to: CGPoint(x: 0, y: 264))
            stroke(ctx, body, edge, 1.5)
            fill(ctx, bodyStripes, stripe)
            stroke(ctx, dorsalLine, rgb(0x6E737A, 0.6), 9)
            stroke(ctx, bellySheen, rgb(0xFFFFFF, 0.35), 10)
        }

        with(ctx, frame.head) {
            fill(ctx, backEar, backEarFur); stroke(ctx, backEar, edge, 1.5)
            fill(ctx, frontEar, frontEarFur); stroke(ctx, frontEar, edge, 1.5)
            fillGradient(ctx, innerEars, innerEarGradient, from: CGPoint(x: 0, y: 53), to: CGPoint(x: 0, y: 82))
            ctx.saveGState()
            ctx.addPath(head)
            ctx.clip()
            ctx.drawRadialGradient(headGradient, startCenter: CGPoint(x: 240, y: 146), startRadius: 0,
                                   endCenter: CGPoint(x: 240, y: 146), endRadius: 112, options: [.drawsAfterEndLocation])
            ctx.restoreGState()
            stroke(ctx, head, edge, 1.5)
            fill(ctx, muzzle, muzzleFur)
            for (path, width) in faceStripes { stroke(ctx, path, faceStripe, width) }
            for eye in eyes { drawEye(eye, openness: frame.eyeOpenness, ctx) }
            fill(ctx, nosePath, nose); stroke(ctx, nosePath, noseEdge, 1.4)
            stroke(ctx, noseHighlight, noseShine, 1.5)
            stroke(ctx, mouth, mouthLine, 1.6)
            ctx.setFillColor(whiskerDot)
            for p in whiskerDots { ctx.fillEllipse(in: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)) }
            stroke(ctx, whiskers, whisker, 1.3)
        }

        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    private static func drawLeg(_ leg: CatLeg, _ frame: CatRig.Frame, _ ctx: CGContext, far: Bool) {
        let hind = leg == .farHind || leg == .nearHind
        with(ctx, frame.legs[leg]!) {
            let path = legPath(leg)
            fillGradient(ctx, path, far ? farLegGradient : legGradient, from: CGPoint(x: 0, y: -10), to: CGPoint(x: 0, y: 66))
            stroke(ctx, path, edge, 1.5)
            stroke(ctx, hind ? hindStripes : frontStripes, legStripe, 4)
            if !far { stroke(ctx, toes, toe, 1.4) }
        }
    }

    private static func drawEye(_ eye: Eye, openness: CGFloat, _ ctx: CGContext) {
        let c = eye.center
        if openness < 0.25 {
            // Closed: a relaxed curve.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: c.x - eye.rx, y: c.y + 2))
            path.addQuadCurve(to: CGPoint(x: c.x + eye.rx, y: c.y + 2), control: CGPoint(x: c.x, y: c.y + eye.ry * 0.55))
            stroke(ctx, path, eyeLine, eye.line)
            return
        }
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.scaleBy(x: 1, y: min(openness, 1))
        let rect = CGRect(x: -eye.rx, y: -eye.ry, width: eye.rx * 2, height: eye.ry * 2)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        let center = CGPoint(x: 0, y: eye.ry * 0.1)
        ctx.drawRadialGradient(irisGradient, startCenter: center, startRadius: 0, endCenter: center,
                               endRadius: eye.ry * 1.1, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
        ctx.addEllipse(in: rect)
        ctx.setStrokeColor(eyeLine)
        ctx.setLineWidth(eye.line)
        ctx.strokePath()
        ctx.setFillColor(pupil)
        ctx.fillEllipse(in: CGRect(x: -eye.pupil.width, y: -eye.pupil.height, width: eye.pupil.width * 2, height: eye.pupil.height * 2))
        ctx.setFillColor(white)
        let r = eye.highlight
        ctx.fillEllipse(in: CGRect(x: -eye.rx * 0.3 - r, y: -eye.ry * 0.38 - r, width: r * 2, height: r * 2))
        ctx.setFillColor(rgb(0xFFFFFF, 0.8))
        ctx.fillEllipse(in: CGRect(x: eye.rx * 0.35 - r * 0.38, y: eye.ry * 0.38 - r * 0.38, width: r * 0.76, height: r * 0.76))
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

    private static func fillGradient(_ ctx: CGContext, _ path: CGPath, _ gradient: CGGradient, from: CGPoint, to: CGPoint) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    private static func stroke(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, _ width: CGFloat) {
        ctx.addPath(path)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }
}
