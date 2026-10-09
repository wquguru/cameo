// Converts an animated image with transparency (WebP, GIF, APNG; decoded by ImageIO, which also
// composites each frame onto the full canvas) into an HEVC-with-alpha .mov for Cameo. Crops to the
// figure over all frames, with the bottom edge on its lowest pixel (where Cameo stands it).
// Usage: swift anim2mov.swift in.webp [out.mov] [max-height, default 960]   (TRIM=0 keeps the canvas)
import AVFoundation
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: swift anim2mov.swift in.webp [out.mov] [max-height]"); exit(1) }
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args.count > 2 ? args[2] : input.deletingPathExtension().path + ".mov")
let maxHeight = args.count > 3 ? Int(args[3]) ?? 960 : 960

guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), CGImageSourceGetCount(source) > 1 else {
    print("not an animated image ImageIO can read"); exit(1)
}
let count = CGImageSourceGetCount(source)

/// Frame duration in seconds, from whichever format dictionary the frame carries.
func delay(at index: Int) -> Double {
    let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
    for (dict, unclamped, clamped) in [
        (kCGImagePropertyWebPDictionary, kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime),
        (kCGImagePropertyGIFDictionary, kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime),
        (kCGImagePropertyPNGDictionary, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime),
    ] {
        if let d = props[dict] as? [CFString: Any], let t = (d[unclamped] ?? d[clamped]) as? Double, t > 0 { return t }
    }
    return 1.0 / 12
}

let frames: [CGImage] = (0..<count).map { index in
    guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { print("cannot decode frame \(index)"); exit(1) }
    return image
}
let canvasW = frames[0].width, canvasH = frames[0].height

/// Union of the opaque pixels over all frames, in top-left image coordinates.
func figureBounds() -> CGRect {
    var minX = canvasW, minY = canvasH, maxX = -1, maxY = -1
    var pixels = [UInt8](repeating: 0, count: canvasW * canvasH * 4)
    for image in frames {
        let ctx = CGContext(data: &pixels, width: canvasW, height: canvasH, bitsPerComponent: 8, bytesPerRow: canvasW * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
        for y in stride(from: 0, to: canvasH, by: 2) {   // row 0 of the buffer is the top of the image
            for x in stride(from: 0, to: canvasW, by: 2) where pixels[(y * canvasW + x) * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    guard maxX >= 0 else { return CGRect(x: 0, y: 0, width: canvasW, height: canvasH) }
    let pad = Double(maxY - minY) * 0.03            // margin on the top and sides, none below
    let x0 = max(0, Double(minX) - pad), x1 = min(Double(canvasW), Double(maxX + 2) + pad)
    let y0 = max(0, Double(minY) - pad), y1 = min(Double(canvasH), Double(maxY + 2))
    return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
}
let crop = ProcessInfo.processInfo.environment["TRIM"] == "0" ? CGRect(x: 0, y: 0, width: canvasW, height: canvasH) : figureBounds()

// HEVC wants even dimensions; scale down to max-height if taller.
let scale = min(1, Double(maxHeight) / crop.height)
let height = Int((crop.height * scale / 2).rounded()) * 2
let width = Int((crop.width * Double(height) / crop.height / 2).rounded()) * 2
let s = Double(height) / crop.height
// Where the whole canvas lands in the (bottom-left origin) output so the crop fills it.
let canvasRect = CGRect(x: -crop.minX * s, y: -(Double(canvasH) - crop.maxY) * s, width: Double(canvasW) * s, height: Double(canvasH) * s)

try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
])
video.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
])
writer.add(video)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

var time = 0.0
for (index, image) in frames.enumerated() {
    while !video.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    guard let pb = buffer else { print("no pixel buffer"); exit(1) }
    CVBufferSetAttachment(pb, kCVImageBufferAlphaChannelModeKey, kCVImageBufferAlphaChannelMode_PremultipliedAlpha, .shouldPropagate)
    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(pb), width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.interpolationQuality = .high
    ctx.draw(image, in: canvasRect)
    CVPixelBufferUnlockBaseAddress(pb, [])
    adaptor.append(pb, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600))
    time += delay(at: index)
}

video.markAsFinished()
writer.endSession(atSourceTime: CMTime(seconds: time, preferredTimescale: 600))
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { print("write failed: \(String(describing: writer.error))"); exit(1) }
print(String(format: "Wrote %@ (%dx%d, %d frames, %.2f s)", output.path, width, height, count, time))
