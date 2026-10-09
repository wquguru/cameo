// Checks a gallery video for alpha, writes its poster and upserts gallery/characters.json.
// Usage: swift scripts/gallery-entry.swift <video.mov> <id> <name> <author> <video-url> <category>
import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Entry: Codable {
    var id, name, author, authorURL, license, video, poster: String
    var bytes: Int
    /// animal, person or other; drives the gallery's tabs. Optional for older entries.
    var category: String?
    /// Loop length in seconds.
    var duration: Double?
}

let args = CommandLine.arguments
guard args.count == 7, ["animal", "person", "other"].contains(args[6]) else {
    print("usage: swift scripts/gallery-entry.swift <video.mov> <id> <name> <author> <video-url> <animal|person|other>")
    exit(1)
}
let (file, id, name, author, videoURL, category) = (URL(fileURLWithPath: args[1]), args[2], args[3], args[4], args[5], args[6])
let gallery = URL(fileURLWithPath: "gallery")

let asset = AVURLAsset(url: file)
guard let track = try await asset.loadTracks(withMediaType: .video).first,
      let format = try await track.load(.formatDescriptions).first else {
    print("no video track"); exit(1)
}
let codec = CMFormatDescriptionGetMediaSubType(format)
let depth = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_Depth) as? Int
let alphaFlag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel) as? Bool
let isProRes4444 = codec == kCMVideoCodecType_AppleProRes4444 || codec == kCMVideoCodecType_AppleProRes4444XQ
guard alphaFlag == true || (isProRes4444 && depth == 32) else { print("no alpha channel"); exit(1) }

// Poster: a frame a quarter of the way in, at most 480 pt tall.
let duration = try await asset.load(.duration)
let generator = AVAssetImageGenerator(asset: asset)
generator.maximumSize = CGSize(width: 480, height: 480)
generator.appliesPreferredTrackTransform = true
let (image, _) = try await generator.image(at: CMTimeMultiplyByRatio(duration, multiplier: 1, divisor: 4))
let posterPath = "posters/\(id).png"
try FileManager.default.createDirectory(at: gallery.appendingPathComponent("posters"), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(gallery.appendingPathComponent(posterPath) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { print("could not write poster"); exit(1) }

let handle = author.hasPrefix("@") ? String(author.dropFirst()) : nil
let entry = Entry(id: id, name: name, author: author, authorURL: handle.map { "https://x.com/\($0)" } ?? "",
                  license: "CC BY 4.0", video: videoURL, poster: posterPath,
                  bytes: (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0,
                  category: category, duration: (CMTimeGetSeconds(duration) * 10).rounded() / 10)

let index = gallery.appendingPathComponent("characters.json")
var entries = (try? JSONDecoder().decode([Entry].self, from: Data(contentsOf: index))) ?? []
entries.removeAll { $0.id == id }
entries.insert(entry, at: 0)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try (encoder.encode(entries) + Data("\n".utf8)).write(to: index)
print("Added \(id) to gallery/characters.json")
