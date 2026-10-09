// Checks a character video against the gallery's rules and prints a JSON report.
// Usage: swift scripts/character-check.swift <video.mov>
// Exit status 0 when it passes, 1 when it has problems, 2 when it can't be read.
import AVFoundation
import Foundation

struct Report: Encodable {
    var ok = false
    var codec = ""
    var alpha = false
    var width = 0
    var height = 0
    var duration = 0.0
    var bytes = 0
    var problems: [String] = []
}

// maxBytes matches website uploads; the GitHub form has its own 10 MB attachment limit.
let limits = (maxSeconds: 10.0, maxHeight: 1080, maxBytes: 20 * 1024 * 1024)

guard CommandLine.arguments.count == 2 else {
    print("usage: swift scripts/character-check.swift <video.mov>")
    exit(2)
}
let file = URL(fileURLWithPath: CommandLine.arguments[1])
var report = Report()
report.bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

let asset = AVURLAsset(url: file)
guard let track = try? await asset.loadTracks(withMediaType: .video).first,
      let format = try? await track.load(.formatDescriptions).first else {
    report.problems.append("Not a playable video. 不是可以播放的视频。")
    print(String(data: try! JSONEncoder().encode(report), encoding: .utf8)!)
    exit(2)
}

let fourCC = CMFormatDescriptionGetMediaSubType(format)
report.codec = String(bytes: [24, 16, 8, 0].map { UInt8((fourCC >> $0) & 0xFF) }, encoding: .ascii) ?? "?"
let alphaFlag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel) as? Bool
let depth = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_Depth) as? Int
let isProRes4444 = fourCC == kCMVideoCodecType_AppleProRes4444 || fourCC == kCMVideoCodecType_AppleProRes4444XQ
report.alpha = alphaFlag == true || (isProRes4444 && depth == 32)
let size = (try? await track.load(.naturalSize)) ?? .zero
report.width = Int(size.width.rounded())
report.height = Int(size.height.rounded())
report.duration = ((try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0).rounded(toPlaces: 1)

if !report.alpha {
    report.problems.append("No transparent background (needs HEVC with Alpha or ProRes 4444). 没有透明背景（需要 HEVC with Alpha 或 ProRes 4444）。")
}
if report.duration <= 0 || report.duration > limits.maxSeconds {
    report.problems.append("Length is \(report.duration) s; at most 10 s. 时长 \(report.duration) 秒，最长 10 秒。")
}
if report.height > limits.maxHeight {
    report.problems.append("Height is \(report.height) px; at most 1080. 高度 \(report.height) 像素，最多 1080。")
}
if report.bytes > limits.maxBytes {
    report.problems.append("File is \(report.bytes / 1024 / 1024) MB; under 20 MB please. 文件 \(report.bytes / 1024 / 1024) MB，需小于 20 MB。")
}
report.ok = report.problems.isEmpty
print(String(data: try! JSONEncoder().encode(report), encoding: .utf8)!)
exit(report.ok ? 0 : 1)

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10, Double(places))
        return (self * p).rounded() / p
    }
}
