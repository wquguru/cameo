import AppKit
import QuartzCore

/// Base for the views shown in the character window: a display link driving `step`,
/// a frame-rate cap, dragging the window, and an alpha hit test for click-through.
@MainActor
class FigureView: NSView {
    var onDragEnded: (() -> Void)?
    var onClick: (() -> Void)?
    var onDragChanged: ((Bool) -> Void)?

    private(set) var link: CADisplayLink?
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?
    private var moved = false

    var maxFrameRate: Float = 60 {
        didSet { applyFrameRate() }
    }

    var isDragging: Bool { dragStart != nil }

    /// True when something is drawn at `point` (view coordinates).
    func hasFigure(at point: NSPoint) -> Bool { false }

    func setPlaying(_ playing: Bool) {
        link?.isPaused = !playing
    }

    /// Called on every display-link frame.
    func step(_ link: CADisplayLink) {}

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        link?.invalidate()
        link = nil
        guard window != nil else { return }
        let link = displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        applyFrameRate()
    }

    private func applyFrameRate() {
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(15, maxFrameRate), maximum: maxFrameRate, preferred: maxFrameRate)
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(link)
    }

    // MARK: Dragging

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStart = (NSEvent.mouseLocation, window.frame.origin)
        moved = false
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStart else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.mouse.x, dy = now.y - start.mouse.y
        if !moved && hypot(dx, dy) > 3 {
            moved = true
            onDragChanged?(true)
        }
        window.setFrameOrigin(NSPoint(x: start.origin.x + dx, y: start.origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        NSCursor.pop()
        if moved {
            onDragChanged?(false)
            onDragEnded?()
        } else {
            onClick?()
        }
    }
}
