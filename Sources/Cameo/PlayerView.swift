import AVFoundation
import AppKit
import QuartzCore

/// Plays a looping alpha video into its layer and answers "is there a figure under this point?".
/// Frames are pulled through AVPlayerItemVideoOutput on the display link, so the frame rate can be capped
/// and the current frame's alpha can be sampled for click-through.
@MainActor
final class PlayerView: FigureView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var itemObservation: NSKeyValueObservation?
    private var frame_: CVPixelBuffer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        layer?.isOpaque = false
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachOutputs() }
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
        attachOutputs()
    }

    override func setPlaying(_ playing: Bool) {
        if playing { player.play() } else { player.pause() }
        super.setPlaying(playing)
    }

    // MARK: Frames

    /// Each looped replica item needs its own output; attaching ahead of time keeps the loop seamless.
    private func attachOutputs() {
        for item in player.items() where item.outputs.isEmpty {
            item.add(AVPlayerItemVideoOutput(pixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            ]))
        }
    }

    private var output: AVPlayerItemVideoOutput? {
        player.currentItem?.outputs.first as? AVPlayerItemVideoOutput
    }

    override func step(_ link: CADisplayLink) {
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

    override func hasFigure(at point: NSPoint) -> Bool {
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
}
