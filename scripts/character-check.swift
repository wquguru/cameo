// Checks a character video, or a character package folder (docs/package-spec.md), against the
// gallery's rules and prints a JSON report.
// Usage: swift scripts/character-check.swift <video.mov | package-folder>
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
    /// Packages only: clips, actions and whether it walks.
    var clips: Int?
    var actions: Int?
    var walks: Bool?
    var problems: [String] = []
}

/// What one video file is.
struct Video {
    var codec = "", alpha = false, width = 0, height = 0, duration = 0.0
}

// maxBytes matches website uploads; the GitHub form has its own 10 MB attachment limit.
let limits = (maxSeconds: 10.0, maxHeight: 1080, maxBytes: 20 * 1024 * 1024)

func inspect(_ file: URL) async -> Video? {
    let asset = AVURLAsset(url: file)
    guard let track = try? await asset.loadTracks(withMediaType: .video).first,
          let format = try? await track.load(.formatDescriptions).first else { return nil }
    var video = Video()
    let fourCC = CMFormatDescriptionGetMediaSubType(format)
    video.codec = String(bytes: [24, 16, 8, 0].map { UInt8((fourCC >> $0) & 0xFF) }, encoding: .ascii) ?? "?"
    let alphaFlag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel) as? Bool
    let depth = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_Depth) as? Int
    let isProRes4444 = fourCC == kCMVideoCodecType_AppleProRes4444 || fourCC == kCMVideoCodecType_AppleProRes4444XQ
    video.alpha = alphaFlag == true || (isProRes4444 && depth == 32)
    let size = (try? await track.load(.naturalSize)) ?? .zero
    video.width = Int(size.width.rounded())
    video.height = Int(size.height.rounded())
    video.duration = ((try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0).rounded(toPlaces: 1)
    return video
}

func finish(_ report: Report, status: Int32? = nil) -> Never {
    print(String(data: try! JSONEncoder().encode(report), encoding: .utf8)!)
    exit(status ?? (report.ok ? 0 : 1))
}

func bytes(of url: URL, folder: Bool) -> Int {
    let size = { (url: URL) in (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }
    guard folder, let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return size(url) }
    return files.compactMap { $0 as? URL }.map(size).reduce(0, +)
}

/// A package: the manifest as Cameo reads it (spec 1, a canvas size, clips of known kinds), an
/// idle clip, every pose reachable from "front", and every clip a transparent video of the canvas
/// size, at most 10 s.
func checkPackage(_ folder: URL, into report: inout Report) async {
    guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        report.problems.append("manifest.json is missing or not valid JSON. manifest.json 缺失或不是合法的 JSON。")
        return
    }
    let width = (root["width"] as? NSNumber)?.intValue ?? 0, height = (root["height"] as? NSNumber)?.intValue ?? 0
    guard (root["spec"] as? Int ?? 1) == 1, width > 0, height > 0 else {
        report.problems.append("manifest.json needs spec 1 and a width and height. manifest.json 需要 spec 1 以及 width、height。")
        return
    }
    report.width = width
    report.height = height
    let kinds = Set(["idle", "walk", "transition", "action", "drag"])
    let clips = (root["clips"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }.filter {
        $0["id"] is String && $0["file"] is String && kinds.contains($0["kind"] as? String ?? "")
    }
    let kind = { (clip: [String: Any]) in clip["kind"] as! String }
    let pose = { (clip: [String: Any], key: String) in clip[key] as? String ?? "front" }
    report.clips = clips.count
    report.actions = clips.filter { kind($0) == "action" }.count
    report.walks = clips.contains { kind($0) == "walk" }
    if !clips.contains(where: { kind($0) == "idle" }) {
        report.problems.append("The package has no idle clip. 角色包没有 idle 片段。")
    }
    var reached: Set<String> = ["front"], frontier = ["front"]
    while let from = frontier.popLast() {
        for clip in clips where kind(clip) == "transition" && pose(clip, "from") == from && !reached.contains(pose(clip, "to")) {
            reached.insert(pose(clip, "to"))
            frontier.append(pose(clip, "to"))
        }
    }
    let stranded = Set(clips.flatMap { [pose($0, "from"), pose($0, "to")] }).subtracting(reached).sorted()
    if !stranded.isEmpty {
        report.problems.append("No transitions lead from front to: \(stranded.joined(separator: ", ")). 从 front 无法过渡到：\(stranded.joined(separator: "、"))。")
    }
    report.alpha = true
    for clip in clips {
        let id = clip["id"] as! String
        guard let video = await inspect(folder.appendingPathComponent(clip["file"] as! String)) else {
            report.problems.append("Clip \(id) is not a playable video. 片段 \(id) 不是可以播放的视频。")
            continue
        }
        if kind(clip) == "idle" || report.codec.isEmpty { report.codec = video.codec; report.duration = video.duration }
        if !video.alpha {
            report.alpha = false
            report.problems.append("Clip \(id) has no transparent background. 片段 \(id) 没有透明背景。")
        }
        if video.width != width || video.height != height {
            report.problems.append("Clip \(id) is \(video.width) × \(video.height), not the manifest's \(width) × \(height). 片段 \(id) 是 \(video.width) × \(video.height)，与 manifest 的 \(width) × \(height) 不符。")
        }
        if video.duration <= 0 || video.duration > limits.maxSeconds {
            report.problems.append("Clip \(id) is \(video.duration) s; at most 10 s. 片段 \(id) 时长 \(video.duration) 秒，最长 10 秒。")
        }
    }
}

guard CommandLine.arguments.count == 2 else {
    print("usage: swift scripts/character-check.swift <video.mov | package-folder>")
    exit(2)
}
let file = URL(fileURLWithPath: CommandLine.arguments[1])
var report = Report()
var isFolder: ObjCBool = false
let folder = FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && isFolder.boolValue
report.bytes = bytes(of: file, folder: folder)

if folder {
    await checkPackage(file, into: &report)
} else {
    guard let video = await inspect(file) else {
        report.problems.append("Not a playable video. 不是可以播放的视频。")
        finish(report, status: 2)
    }
    (report.codec, report.alpha, report.width, report.height, report.duration) = (video.codec, video.alpha, video.width, video.height, video.duration)
    if !report.alpha {
        report.problems.append("No transparent background (needs HEVC with Alpha or ProRes 4444). 没有透明背景（需要 HEVC with Alpha 或 ProRes 4444）。")
    }
    if report.duration <= 0 || report.duration > limits.maxSeconds {
        report.problems.append("Length is \(report.duration) s; at most 10 s. 时长 \(report.duration) 秒，最长 10 秒。")
    }
}
if report.height > limits.maxHeight {
    report.problems.append("Height is \(report.height) px; at most 1080. 高度 \(report.height) 像素，最多 1080。")
}
if report.bytes > limits.maxBytes {
    report.problems.append("File is \(report.bytes / 1024 / 1024) MB; under 20 MB please. 文件 \(report.bytes / 1024 / 1024) MB，需小于 20 MB。")
}
report.ok = report.problems.isEmpty
finish(report)

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10, Double(places))
        return (self * p).rounded() / p
    }
}
