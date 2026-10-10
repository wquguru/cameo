import AVFoundation
import AppKit

/// Thumbnails of characters, kept in memory: the first frame cropped to the figure, the union of
/// its opaque pixels over a few frames across the loop, so a waving hand stays inside.
@MainActor
final class Thumbnails: ObservableObject {
    @Published private(set) var images: [UUID: NSImage] = [:]
    /// Where the figure sits in the video frame (unit coordinates, origin top-left), so a hover
    /// preview can be cropped the same way as its thumbnail.
    private(set) var bounds: [UUID: CGRect] = [:]
    private var pending: Set<UUID> = []

    init() {
        let cat = CatView.thumbnail(size: CGSize(width: 440, height: 380))
        if let cgImage = cat.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let box = Self.opaqueBounds([cgImage]), let cropped = Self.crop(cgImage, to: box) {
            images[Character.builtInCat.id] = NSImage(cgImage: cropped, size: .zero)
        } else {
            images[Character.builtInCat.id] = cat
        }
    }

    func image(for character: Character, url: URL) -> NSImage? {
        if let image = images[character.id] { return image }
        guard !pending.contains(character.id) else { return nil }
        pending.insert(character.id)
        Task {
            if let (image, box) = await Self.render(url) {
                bounds[character.id] = box
                images[character.id] = image
            }
            pending.remove(character.id)
        }
        return nil
    }

    private nonisolated static func render(_ url: URL) async -> (NSImage, CGRect)? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        let seconds = (try? await asset.load(.duration).seconds) ?? 0
        let times = [0, 0.25, 0.5, 0.75].map { CMTime(seconds: seconds.isFinite ? seconds * $0 : 0, preferredTimescale: 600) }
        var frames: [CGImage] = []
        for time in times {
            if let (frame, _) = try? await generator.image(at: time) { frames.append(frame) }
        }
        guard let first = frames.first else { return nil }
        guard let box = opaqueBounds(frames), let cropped = crop(first, to: box) else {
            return (NSImage(cgImage: first, size: .zero), CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return (NSImage(cgImage: cropped, size: .zero), box)
    }

    /// The smallest rectangle (unit coordinates, origin top-left) holding every pixel that is more
    /// than faintly opaque in any of `frames`, with a little room around it; nil when all are clear.
    nonisolated static func opaqueBounds(_ frames: [CGImage]) -> CGRect? {
        guard let size = frames.first.map({ CGSize(width: $0.width, height: $0.height) }) else { return nil }
        let scale = min(1, 160 / max(size.width, size.height))
        let width = max(1, Int(size.width * scale)), height = max(1, Int(size.height * scale))
        var minX = width, minY = height, maxX = -1, maxY = -1
        var alpha = [UInt8](repeating: 0, count: width * height)
        for frame in frames {
            let found: Bool = alpha.withUnsafeMutableBytes { buffer in
                guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return false }
                ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
                ctx.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard found else { continue }
            for y in 0..<height {
                for x in 0..<width where alpha[y * width + x] > 12 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // Rows in the bitmap run top to bottom, like the unit rectangle.
        let pad = 1
        let x0 = max(0, minX - pad), y0 = max(0, minY - pad)
        let x1 = min(width, maxX + 1 + pad), y1 = min(height, maxY + 1 + pad)
        return CGRect(x: CGFloat(x0) / CGFloat(width), y: CGFloat(y0) / CGFloat(height),
                      width: CGFloat(x1 - x0) / CGFloat(width), height: CGFloat(y1 - y0) / CGFloat(height))
    }

    nonisolated static func crop(_ image: CGImage, to box: CGRect) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let rect = CGRect(x: box.minX * w, y: box.minY * h, width: box.width * w, height: box.height * h).integral
        return image.cropping(to: rect)
    }
}
