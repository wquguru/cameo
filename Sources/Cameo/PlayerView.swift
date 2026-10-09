import AVFoundation
import AppKit
import QuartzCore

/// Plays a looping alpha video into its layer and answers "is there a figure under this point?".
/// Frames are pulled through AVPlayerItemVideoOutput on a display link, so the frame rate can be capped
/// and the current frame's alpha can be sampled for click-through.
@MainActor
final class PlayerView: NSView {
    var onDragEnded: (() -> Void)?

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var output: AVPlayerItemVideoOutput?
    private var itemObservation: NSKeyValueObservation?
    private var link: CADisplayLink?
    private var frame_: CVPixelBuffer?
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    var maxFrameRate: Float = 60 {
        didSet { applyFrameRate() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        layer?.isOpaque = false
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            MainActor.assumeIsolated { self?.attachOutput(to: player.currentItem) }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func load(_ url: URL?) {
        looper?.disableLooping()
        player.removeAllItems()
        looper = nil
        frame_ = nil
        layer?.contents = nil
        guard let url else { return }
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func setPlaying(_ playing: Bool) {
        if playing { player.play() } else { player.pause() }
        link?.isPaused = !playing
    }

    // MARK: Frames

    private func attachOutput(to item: AVPlayerItem?) {
        guard let item else { return }
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ])
        item.add(output)
        self.output = output
    }

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
        guard let output else { return }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil),
              let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else { return }
        frame_ = buffer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = surface
        CATransaction.commit()
    }

    // MARK: Hit testing

    /// True when the current frame has a visible pixel at `point` (view coordinates).
    func hasFigure(at point: NSPoint) -> Bool {
        guard let buffer = frame_ else { return false }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let fit = AVMakeRect(aspectRatio: CGSize(width: w, height: h), insideRect: bounds)
        guard fit.contains(point) else { return false }
        let x = Int((point.x - fit.minX) / fit.width * CGFloat(w))
        let y = Int((fit.maxY - point.y) / fit.height * CGFloat(h))
        guard (0..<w).contains(x), (0..<h).contains(y) else { return false }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return false }
        let alpha = base.load(fromByteOffset: y * CVPixelBufferGetBytesPerRow(buffer) + x * 4 + 3, as: UInt8.self)
        return alpha > 24
    }

    // MARK: Dragging

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStart = (NSEvent.mouseLocation, window.frame.origin)
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStart else { return }
        let now = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(x: start.origin.x + now.x - start.mouse.x, y: start.origin.y + now.y - start.mouse.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        NSCursor.pop()
        onDragEnded?()
    }

    var isDragging: Bool { dragStart != nil }
}
