// Checks that a video will work in Cameo: an alpha channel, a transparent background and an
// opaque figure. Prints a short report and exits non-zero on failure.
// Usage: swift verify.swift out.mov [preview.png]   (preview: the middle frame on a checkerboard)
import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

let url = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "")
let asset = AVURLAsset(url: url)
guard let track = try? await asset.loadTracks(withMediaType: .video).first,
      let format = try await track.load(.formatDescriptions).first else {
    print("FAIL: no video track"); exit(1)
}
let codec = CMFormatDescriptionGetMediaSubType(format)
let depth = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_Depth) as? Int
let flag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel) as? Bool
let proRes = codec == kCMVideoCodecType_AppleProRes4444 || codec == kCMVideoCodecType_AppleProRes4444XQ
guard flag == true || (proRes && depth == 32) else { print("FAIL: no alpha channel"); exit(1) }

let size = try await track.load(.naturalSize)
let duration = try await asset.load(.duration).seconds
let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
print(String(format: "size %.0fx%.0f, %.1f s, %.1f MB", size.width, size.height, duration, Double(bytes) / 1e6))

// Sample the middle frame: share of transparent pixels, and alpha along the border.
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
let (image, _) = try await generator.image(at: CMTime(seconds: duration / 2, preferredTimescale: 600))
let w = image.width, h = image.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * w + x) * 4 + 3] }

var clear = 0, border = 0, borderOpaque = 0
for y in 0..<h { for x in 0..<w {
    if alpha(x, y) < 16 { clear += 1 }
    if x == 0 || y == 0 || x == w - 1 || y == h - 1 { border += 1; if alpha(x, y) > 128 { borderOpaque += 1 } }
} }
let clearShare = Double(clear) / Double(w * h)
print(String(format: "transparent %.0f%%, opaque border %.0f%%", clearShare * 100, Double(borderOpaque) / Double(border) * 100))
if clearShare < 0.2 { print("FAIL: background is not transparent (key colour or similarity off?)"); exit(1) }
if clearShare > 0.98 { print("FAIL: almost everything is transparent (similarity too high?)"); exit(1) }

if CommandLine.arguments.count > 2 {
    let preview = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let tile = 16
    for ty in stride(from: 0, to: h, by: tile) { for tx in stride(from: 0, to: w, by: tile) {
        let light = (tx / tile + ty / tile) % 2 == 0
        preview.setFillColor(gray: light ? 0.8 : 0.6, alpha: 1)
        preview.fill(CGRect(x: tx, y: ty, width: tile, height: tile))
    } }
    preview.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let out = URL(fileURLWithPath: CommandLine.arguments[2])
    let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, preview.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    print("preview: \(out.path)")
}
print("OK")
