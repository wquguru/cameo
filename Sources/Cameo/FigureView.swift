import AppKit
import QuartzCore

/// Base for the views shown in the character window: a display link driving `step`,
/// a frame-rate cap, dragging the window, a right-click (or Control-click) that asks for the menu,
/// and an alpha hit test for click-through.
@MainActor
class FigureView: NSView {
    var onDragEnded: (() -> Void)?
    var onClick: (() -> Void)?
    var onDragChanged: ((Bool) -> Void)?
    /// A right-click or Control-click (the second click of a double-click is ignored).
    var onSecondaryClick: (() -> Void)?

    private(set) var link: CADisplayLink?
    private var dragStart: (start: NSPoint, last: NSPoint)?
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
        guard window != nil else { return }
        if event.modifierFlags.contains(.control) { return rightMouseDown(with: event) }
        dragStart = (NSEvent.mouseLocation, NSEvent.mouseLocation)
        moved = false
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let drag = dragStart else { return }
        let now = NSEvent.mouseLocation
        if !moved && hypot(now.x - drag.start.x, now.y - drag.start.y) > 3 {
            moved = true
            onDragChanged?(true)
        }
        // Move by the delta since the last event, so the window may also move on its own (a walking cat).
        let origin = window.frame.origin
        window.setFrameOrigin(NSPoint(x: origin.x + now.x - drag.last.x, y: origin.y + now.y - drag.last.y))
        dragStart = (drag.start, now)
    }

    override func rightMouseDown(with event: NSEvent) {
        if event.clickCount == 1 { onSecondaryClick?() }
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
