import AVFoundation
import CameoShow
import CoreGraphics

/// One decoded frame, kept with its raw BGRA bytes so the alpha under a point can be read cheaply.
struct PackageFrame {
    let image: CGImage
    let data: CFData
    let bytesPerRow: Int
    /// The columns holding opaque pixels, or nil for an empty frame.
    let opaque: ClosedRange<Int>?

    func alpha(x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return 0 }
        return CFDataGetBytePtr(data)[y * bytesPerRow + x * 4 + 3]
    }
}

struct LoadedPackage {
    var manifest: PackageManifest
    var frames: [String: [PackageFrame]]

    /// How far the figure reaches either side of the canvas centre, in canvas widths (0...0.5),
    /// over every frame of every clip, so its body can stand flush with a screen edge whichever
    /// way it faces.
    var reach: Double {
        var lo = Int.max, hi = Int.min, width = 1
        for list in frames.values {
            for frame in list {
                width = frame.image.width
                guard let o = frame.opaque else { continue }
                lo = min(lo, o.lowerBound)
                hi = max(hi, o.upperBound)
            }
        }
        guard lo <= hi else { return 0.5 }
        let w = Double(width)
        return min(0.5, max(0.5 - Double(lo) / w, Double(hi + 1) / w - 0.5, 0))
    }
}

/// Reads a character package and decodes every clip once into memory (premultiplied BGRA),
/// so switching clips never waits on a decoder.
enum PackageLoader {
    static func manifest(in folder: URL) throws -> PackageManifest {
        try PackageManifest.parse(Data(contentsOf: folder.appendingPathComponent("manifest.json")))
    }

    static func load(_ folder: URL) async throws -> LoadedPackage {
        var manifest = try manifest(in: folder)
        var frames: [String: [PackageFrame]] = [:]
        for clip in manifest.clips {
            var decoded = try await decode(folder.appendingPathComponent(clip.file))
            // A looping clip's last frame repeats its first (both are the same keyframe); showing it
            // would hold that pose for two frames at every seam.
            if clip.loop, clip.from == clip.to, decoded.count > 2 { decoded.removeLast() }
            if !decoded.isEmpty { frames[clip.id] = decoded }
        }
        manifest.clips = manifest.clips.compactMap { clip in
            guard let n = frames[clip.id]?.count else { return nil }
            var clip = clip
            clip.frames = n
            return clip
        }
        guard !manifest.clips.isEmpty else { throw ManifestError.noClips }
        return LoadedPackage(manifest: manifest, frames: frames)
    }

    private static func decode(_ url: URL) async throws -> [PackageFrame] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ImportError.noVideo }
        return await Task.detached {
            var frames: [PackageFrame] = []
            while let sample = output.copyNextSampleBuffer() {
                if let buffer = CMSampleBufferGetImageBuffer(sample), let frame = copy(buffer) { frames.append(frame) }
            }
            return frames
        }.value
    }

    private static func copy(_ buffer: CVPixelBuffer) -> PackageFrame? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let data = CFDataCreate(nil, bytes, stride * h)!
        // Opaque column range, from every other row.
        var lo = w, hi = -1, y = 0
        while y < h {
            let row = bytes + y * stride
            var x = 0
            while x < lo { if row[x * 4 + 3] > 24 { lo = x; break }; x += 1 }
            x = w - 1
            while x > hi { if row[x * 4 + 3] > 24 { hi = x; break }; x -= 1 }
            y += 2
        }
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: stride,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return PackageFrame(image: image, data: data, bytesPerRow: stride, opaque: lo <= hi ? lo...hi : nil)
    }
}
