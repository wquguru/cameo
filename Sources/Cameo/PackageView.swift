import AVFoundation
import AppKit
import CameoShow
import QuartzCore

/// Shows a character package: the `Show` picks clips, this draws their decoded frames (mirrored
/// by a layer transform) and walks the window. Click acts, dragging holds the pose.
@MainActor
final class PackageView: FigureView {
    private var show: Show?
    private var frames: [String: [PackageFrame]] = [:]
    private var lastTime: CFTimeInterval?
    private struct Drawn: Equatable { var clip: String, index: Int, mirrored: Bool }
    private var shown: Drawn?
    private var current: PackageFrame?
    private var mirrored = false

    /// The figure's feet x and the walkable range of that x, in screen points.
    var position: (() -> (x: CGFloat, bounds: ClosedRange<CGFloat>)?)?
    /// Moves the window sideways by `dx` points.
    var onMove: ((CGFloat) -> Void)?
    /// Starts a show at the screen edge it chose (feet x).
    var onStart: ((CGFloat) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        layer?.isOpaque = false
        onClick = { [weak self] in self?.show?.poke() }
        onDragChanged = { [weak self] dragging in self?.show?.held = dragging }
    }

    required init?(coder: NSCoder) { fatalError() }

    func load(_ package: LoadedPackage?) {
        show = nil
        shown = nil
        current = nil
        frames = package?.frames ?? [:]
        layer?.contents = nil
        guard let package else { return }
        show = Show(clips: package.manifest.clips, facingLeft: package.manifest.facingLeft)
        lastTime = nil
        needsStart = true
    }

    private var needsStart = false

    /// Screen points per canvas pixel at the current window size.
    private var pointsPerPixel: Double {
        guard let image = frames.values.first?.first?.image, image.height > 0 else { return 1 }
        return Double(bounds.height) / Double(image.height)
    }

    override func setPlaying(_ playing: Bool) {
        super.setPlaying(playing)
        if !playing { lastTime = nil }
    }

    override func step(_ link: CADisplayLink) {
        guard let show, let place = position?() else { return }
        let dt = lastTime.map { min(0.1, link.timestamp - $0) } ?? 0
        lastTime = link.timestamp
        show.pointsPerPixel = pointsPerPixel
        let range = Double(place.bounds.lowerBound)...Double(place.bounds.upperBound)
        if needsStart {
            needsStart = false
            onStart?(CGFloat(show.start(bounds: range, x: Double(place.x))))
            return
        }
        let dx = show.tick(dt: dt, x: Double(place.x), bounds: range)
        if dx != 0 { onMove?(CGFloat(dx)) }
        draw(show)
    }

    private func draw(_ show: Show) {
        let clip = show.play.clip.id
        guard let list = frames[clip], !list.isEmpty else { return }
        let index = min(show.frameIndex, list.count - 1)
        let flip = show.mirrored
        let drawn = Drawn(clip: clip, index: index, mirrored: flip)
        if shown == drawn { return }
        shown = drawn
        current = list[index]
        mirrored = flip
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = current?.image
        layer?.transform = flip ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    override func hasFigure(at point: NSPoint) -> Bool {
        guard let frame = current else { return false }
        let w = frame.image.width, h = frame.image.height
        let fit = AVMakeRect(aspectRatio: CGSize(width: w, height: h), insideRect: bounds)
        guard fit.contains(point) else { return false }
        var u = (point.x - fit.minX) / fit.width
        if mirrored { u = 1 - u }
        let x = Int(u * CGFloat(w)), y = Int((fit.maxY - point.y) / fit.height * CGFloat(h))
        return frame.alpha(x: x, y: y) > 24
    }
}
