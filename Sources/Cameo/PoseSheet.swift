import AppKit

/// `Cameo --render-poses out.png` writes a contact sheet of the cat's poses (a development aid).
enum PoseSheet {
    static func render(to url: URL) {
        let poses: [(CatPose, CGFloat, Bool, CGFloat)] = [
            (.stand, 0, false, 1), (walk(0.25), 0, false, 1), (walk(0.75), 0, true, 1), (.sit, 0, false, 1),
            (.prone, 0, false, 0), (.curl, 0, false, 1), (.curl, 120, false, 1), (.dangle, 0, false, 1),
        ]
        let cell = CGSize(width: 330, height: 285)
        let image = NSImage(size: CGSize(width: cell.width * 4, height: cell.height * 2), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(CGColor(gray: 0.17, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: cell.width * 4, height: cell.height * 2))
            for (i, (pose, spin, left, eyes)) in poses.enumerated() {
                ctx.saveGState()
                ctx.translateBy(x: CGFloat(i % 4) * cell.width, y: CGFloat(i / 4) * cell.height)
                let frame = CatRig.frame(pose: pose, spin: spin, facingLeft: left, eyeOpenness: eyes, viewSize: cell)
                CatArt.draw(frame, in: ctx)
                ctx.restoreGState()
            }
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    private static func walk(_ cycle: CGFloat) -> CatPose {
        let a = 22 * sin(cycle * 2 * .pi)
        var p = CatPose.stand
        p.nearHind = a; p.farFront = a; p.farHind = -a; p.nearFront = -a
        return p
    }
}
