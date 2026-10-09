import AVFoundation
import AppKit

/// `Cameo --render-cat-video out.mov` writes Chaofei sitting, swaying its tail and blinking,
/// as a seamless 4 s HEVC-with-alpha loop: the built-in cat as an ordinary video character.
enum CatVideo {
    static func render(to url: URL) throws {
        let size = CGSize(width: 704, height: 608)          // 1.6 × the cat's canvas
        let fps: Int32 = 30, frames = 120
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            guard let pb = buffer else { throw CocoaError(.fileWriteUnknown) }
            CVBufferSetAttachment(pb, kCVImageBufferAlphaChannelModeKey, kCVImageBufferAlphaChannelMode_PremultipliedAlpha, .shouldPropagate)
            CVPixelBufferLockBaseAddress(pb, [])
            let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(pb), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            ctx.clear(CGRect(origin: .zero, size: size))
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)

            // Every motion completes whole cycles in 4 s, so the clip loops without a seam.
            let phase = CGFloat(frame) / CGFloat(frames) * 2 * .pi
            var pose = CatPose.sit
            pose.tail += 12 * sin(phase * 2)
            pose.head += 3 * sin(phase)
            let t = Double(frame) / Double(fps)
            let eyes: CGFloat = (2.0..<2.15).contains(t) ? 0 : 1
            CatArt.draw(CatRig.frame(pose: pose, spin: 0, facingLeft: false, eyeOpenness: eyes, viewSize: size), in: ctx)

            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    }
}
