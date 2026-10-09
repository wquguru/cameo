// Writes a 4 s looping HEVC-with-alpha clip of a swaying figure, for manual testing.
// Usage: swift run CameoSample [out.mov]
import AVFoundation
import CoreGraphics
import Foundation

let width = 360, height = 720, fps: Int32 = 30, seconds = 4

func figurePath() -> CGPath {
    let p = CGMutablePath()
    p.addEllipse(in: CGRect(x: 33, y: 5, width: 34, height: 34))
    p.move(to: CGPoint(x: 50, y: 43))
    p.addCurve(to: CGPoint(x: 21, y: 70), control1: CGPoint(x: 33, y: 43), control2: CGPoint(x: 23, y: 53))
    for (x, y) in [(14, 128), (27, 128), (32, 200), (44, 200), (48, 140), (52, 140), (56, 200), (68, 200), (73, 128), (86, 128), (79, 70)] {
        p.addLine(to: CGPoint(x: x, y: y))
    }
    p.addCurve(to: CGPoint(x: 50, y: 43), control1: CGPoint(x: 77, y: 53), control2: CGPoint(x: 67, y: 43))
    p.closeSubpath()
    return p
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "sample.mov")
try? FileManager.default.removeItem(at: out)

let writer = try AVAssetWriter(outputURL: out, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let figure = figurePath()
let total = Int(fps) * seconds
for frame in 0..<total {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    guard let pb = buffer else { fatalError("no pixel buffer") }
    CVBufferSetAttachment(pb, kCVImageBufferAlphaChannelModeKey, kCVImageBufferAlphaChannelMode_PremultipliedAlpha, .shouldPropagate)
    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(pb), width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
    // y-down, then sway around the feet.
    let phase = Double(frame) / Double(total) * 2 * .pi
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    ctx.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) - 12)
    ctx.rotate(by: CGFloat(sin(phase)) * 0.06)
    ctx.translateBy(x: 0, y: CGFloat(sin(phase * 2)) * 6)
    ctx.scaleBy(x: 3.4, y: 3.4)
    ctx.translateBy(x: -50, y: -200)
    ctx.addPath(figure)
    ctx.setFillColor(CGColor(srgbRed: 0.96, green: 0.945, blue: 0.918, alpha: 1))
    ctx.fillPath()
    CVPixelBufferUnlockBaseAddress(pb, [])
    adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
}

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }
print("Wrote \(out.path)")
