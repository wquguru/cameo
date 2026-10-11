import AVFoundation
import AppKit
import CameoShow
import QuartzCore

/// Shows a character package: the `Show` picks clips, this draws their decoded frames (mirrored
/// by a layer transform) and walks the window. Click acts, dragging holds the pose.
@MainActor
final class PackageView: FigureView {
    private var show: Show?
    /// Holds the frame. Mirrored with its own transform: the view's layer turns about its corner,
    /// which would flip the figure out of the window.
    private let content = CALayer()
    private var frames: [String: [PackedFrame]] = [:]
    private var lastTime: CFTimeInterval?
    private struct Drawn: Equatable { var clip: String, index: Int, mirrored: Bool }
    private var shown: Drawn?
    private var current: PackageFrame?
    /// Unpacked frames of the clip on screen: loops (idle, walk) replay them without unpacking
    /// again. Dropped when the clip changes, so at most one clip is held raw.
    private var cache: (clip: String, frames: [Int: PackageFrame]) = ("", [:])
    private var mirrored = false
    private var canvasHeight = 1.0
    private var needsStart = false
    private var entering = false
    /// A request made before the show started.
    private var waiting: String?
    private var requested: String?
    /// The requested action has played, or couldn't be.
    var onRequestEnded: (() -> Void)?

    /// How far the figure reaches either side of the canvas centre, in canvas widths.
    private(set) var reach: CGFloat = 0.5
    /// Where the figure stands, in screen points: feet x, the range of feet x that keeps the body
    /// on screen, and feet x just off-screen on each side with no display beyond it.
    var position: (() -> (x: CGFloat, bounds: ClosedRange<CGFloat>, entries: [CGFloat])?)?
    /// Moves the window sideways by `dx` points.
    var onMove: ((CGFloat) -> Void)?
    /// Puts the feet at the x the figure walks in from.
    var onStart: ((CGFloat) -> Void)?
    /// Freezes the show (dragged, falling).
    var held = false {
        didSet { show?.held = held }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.isOpaque = false
        content.contentsGravity = .resizeAspect
        content.isOpaque = false
        layer?.addSublayer(content)
        onClick = { [weak self] in self?.show?.poke() }
        onDragChanged = { [weak self] dragging in self?.held = dragging }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.transform = CATransform3DIdentity
        content.frame = CGRect(origin: .zero, size: newSize)
        content.transform = mirrored ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    /// Shows a package standing where the window is, or, `entering`, walking in from off-screen.
    func load(_ package: LoadedPackage?, entering: Bool = false) {
        show = nil
        waiting = nil
        requested = nil
        shown = nil
        current = nil
        cache = ("", [:])
        frames = package?.frames ?? [:]
        content.contents = nil
        guard let package else { return }
        show = Show(clips: package.manifest.clips, facingLeft: package.manifest.facingLeft)
        show?.held = held
        canvasHeight = Double(package.manifest.height)
        reach = CGFloat(package.reach)
        lastTime = nil
        needsStart = true
        self.entering = entering
    }

    /// Plays an action (clip id or `Show.walkRequest`) once, then carries on; nil carries on now.
    func request(_ id: String?) {
        guard let show, !needsStart else {
            waiting = id
            return
        }
        show.request(id)
        requested = show.requested
        if id != nil, requested == nil { onRequestEnded?() }
    }

    override func setPlaying(_ playing: Bool) {
        super.setPlaying(playing)
        guard !playing else { return }
        lastTime = nil
        // Paused (hidden, covered, asleep): a requested action would never play, so drop it.
        if waiting != nil || requested != nil {
            waiting = nil
            show?.request(nil)
            requested = nil
            onRequestEnded?()
        }
    }

    override func step(_ link: CADisplayLink) {
        guard let show, let place = position?() else { return }
        let dt = lastTime.map { min(0.1, link.timestamp - $0) } ?? 0
        lastTime = link.timestamp
        show.pointsPerPixel = Double(bounds.height) / canvasHeight
        let range = Double(place.bounds.lowerBound)...Double(place.bounds.upperBound)
        if needsStart {
            needsStart = false
            if entering, let from = place.entries.randomElement() {
                onStart?(from)
                show.start(bounds: range, x: Double(place.x), entering: Double(from))
            } else {
                show.start(bounds: range, x: Double(place.x))
            }
            if let id = waiting {
                waiting = nil
                request(id)
            }
            return
        }
        let dx = show.tick(dt: dt, x: Double(place.x), bounds: range)
        if requested != nil, show.requested == nil {
            requested = nil
            onRequestEnded?()
        }
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
        if cache.clip != clip { cache = (clip, [:]) }
        guard let frame = cache.frames[index] ?? list[index].unpack() else { return }
        cache.frames[index] = frame
        shown = drawn
        current = frame
        mirrored = flip
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.contents = current?.surface
        content.transform = flip ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    override func hasFigure(at point: NSPoint) -> Bool {
        guard let frame = current else { return false }
        let w = frame.width, h = frame.height
        let fit = AVMakeRect(aspectRatio: CGSize(width: w, height: h), insideRect: bounds)
        guard fit.contains(point) else { return false }
        var u = (point.x - fit.minX) / fit.width
        if mirrored { u = 1 - u }
        let x = Int(u * CGFloat(w)), y = Int((fit.maxY - point.y) / fit.height * CGFloat(h))
        return frame.alpha(x: x, y: y) > 24
    }
}
