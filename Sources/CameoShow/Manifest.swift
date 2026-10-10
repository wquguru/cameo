import Foundation

public enum ClipKind: String {
    case idle, walk, transition, action, drag
}

/// One clip of a character package (see cameo-video/docs/package-spec.md).
public struct ClipSpec: Equatable {
    public var id: String
    public var file: String
    public var kind: ClipKind
    public var from: String
    public var to: String
    public var loop: Bool
    public var fps: Double
    /// Walk only: canvas pixels per second at native size.
    public var speed: Double
    /// Action only: how many times it plays in a row.
    public var repeatCount: Int
    /// Number of decoded frames; filled in once the clip is loaded.
    public var frames: Int

    public init(id: String, file: String = "", kind: ClipKind, from: String, to: String, loop: Bool = false,
                fps: Double = 10, speed: Double = 0, repeatCount: Int = 1, frames: Int = 0) {
        self.id = id; self.file = file; self.kind = kind; self.from = from; self.to = to; self.loop = loop
        self.fps = fps; self.speed = speed; self.repeatCount = repeatCount; self.frames = frames
    }

    /// Seconds for one pass through the clip.
    public var cycle: Double { Double(max(1, frames)) / max(1, fps) }
}

public enum ManifestError: Error { case notJSON, unsupported, noClips }

public struct PackageManifest {
    public var name: String
    public var width: Int
    public var height: Int
    public var facingLeft: Bool
    public var clips: [ClipSpec]

    /// Lenient parser: unknown fields are ignored and clips with unknown kinds or missing keys are skipped.
    public static func parse(_ data: Data) throws -> PackageManifest {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ManifestError.notJSON }
        guard (root["spec"] as? Int ?? 1) == 1,
              let width = (root["width"] as? NSNumber)?.intValue, let height = (root["height"] as? NSNumber)?.intValue,
              width > 0, height > 0 else { throw ManifestError.unsupported }
        var clips: [ClipSpec] = []
        for case let item as [String: Any] in root["clips"] as? [Any] ?? [] {
            guard let id = item["id"] as? String, let file = item["file"] as? String,
                  let kind = (item["kind"] as? String).flatMap(ClipKind.init(rawValue:)),
                  !clips.contains(where: { $0.id == id }) else { continue }
            clips.append(ClipSpec(
                id: id, file: file, kind: kind,
                from: item["from"] as? String ?? "front", to: item["to"] as? String ?? "front",
                loop: item["loop"] as? Bool ?? (kind == .idle || kind == .walk),
                fps: (item["fps"] as? NSNumber)?.doubleValue ?? 10,
                speed: (item["speed"] as? NSNumber)?.doubleValue ?? 0,
                repeatCount: max(1, (item["repeat"] as? NSNumber)?.intValue ?? 1)))
        }
        guard clips.contains(where: { $0.kind == .idle || $0.kind == .walk || $0.kind == .action }) else { throw ManifestError.noClips }
        return PackageManifest(name: root["name"] as? String ?? "", width: width, height: height,
                               facingLeft: (root["facing"] as? String) == "left", clips: clips)
    }
}

/// Poses connected by transition clips.
public struct ClipGraph {
    public let transitions: [ClipSpec]

    public init(clips: [ClipSpec]) {
        transitions = clips.filter { $0.kind == .transition }
    }

    /// The shortest chain of transition clips from pose `a` to pose `b`; empty when they are the same
    /// pose, nil when `b` cannot be reached.
    public func path(from a: String, to b: String) -> [ClipSpec]? {
        if a == b { return [] }
        var best: [String: [ClipSpec]] = [a: []]
        var frontier = [a]
        while !frontier.isEmpty {
            var next: [String] = []
            for pose in frontier {
                for clip in transitions where clip.from == pose && best[clip.to] == nil {
                    best[clip.to] = best[pose]! + [clip]
                    if clip.to == b { return best[b] }
                    next.append(clip.to)
                }
            }
            frontier = next
        }
        return nil
    }
}
