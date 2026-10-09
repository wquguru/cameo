import AppKit

/// Draws and animates the built-in cat. Clicking it makes it roll; dragging it makes it dangle.
@MainActor
final class CatView: FigureView {
    let brain = CatBrain()
    /// Moves the window by `dx` points; returns true when blocked by a screen edge.
    var onMove: ((CGFloat) -> Bool)?

    private static let tailOutline = CatArt.tail.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 10)
    private var lastTime: CFTimeInterval?
    private var frame_: CatRig.Frame?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        onClick = { [weak self] in self?.brain.poke() }
        onDragChanged = { [weak self] dragging in self?.brain.held = dragging }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func setPlaying(_ playing: Bool) {
        super.setPlaying(playing)
        if !playing { lastTime = nil }
    }

    override func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastTime.map { min(0.1, now - $0) } ?? 0
        lastTime = now
        let dx = brain.update(dt)
        if dx != 0, let onMove, onMove(dx * bounds.height / CatRig.canvas.height) {
            brain.turnAround()
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let frame = CatRig.frame(pose: brain.pose, spin: brain.spin, facingLeft: brain.facingLeft,
                                 eyeOpenness: brain.eyeOpenness, viewSize: bounds.size)
        frame_ = frame
        CatArt.draw(frame, in: ctx)
    }

    override func hasFigure(at point: NSPoint) -> Bool {
        guard let f = frame_ else { return false }
        if CatArt.body.contains(point, using: .winding, transform: f.body) { return true }
        if CatArt.head.contains(point, using: .winding, transform: f.head) { return true }
        for t in f.legs.values where CatArt.leg.contains(point, using: .winding, transform: t) { return true }
        return Self.tailOutline.contains(point, using: .winding, transform: f.tail)
    }

    /// A still image of the cat standing, for the popover card.
    static func thumbnail(size: CGSize) -> NSImage {
        NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let frame = CatRig.frame(pose: .stand, spin: 0, facingLeft: false, eyeOpenness: 1, viewSize: rect.size)
            CatArt.draw(frame, in: ctx)
            return true
        }
    }
}
