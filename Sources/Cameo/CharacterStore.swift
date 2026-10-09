import AVFoundation
import Foundation

struct Character: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let name: String

    /// The cat drawn in code; always present, never stored or deleted.
    static let builtInCat = Character(id: UUID(uuidString: "00000000-0000-0000-0000-000000000CA7")!, fileName: "", name: "小银")

    var isBuiltIn: Bool { id == Self.builtInCat.id }
}

enum ImportError: LocalizedError {
    case noVideo, noAlpha

    var errorDescription: String? {
        switch self {
        case .noVideo: "文件里没有视频轨道。"
        case .noAlpha: "这个视频没有透明通道。请使用 HEVC with Alpha 或 ProRes 4444 编码的 .mov。"
        }
    }
}

/// Imported videos live in ~/Library/Application Support/Cameo/Characters, indexed by characters.json.
@MainActor
final class CharacterStore {
    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("characters.json") }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("Cameo/Characters", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for character: Character) -> URL {
        directory.appendingPathComponent(character.fileName)
    }

    func load() -> [Character] {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? JSONDecoder().decode([Character].self, from: data) else { return [] }
        return list.filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
    }

    func save(_ characters: [Character]) {
        guard let data = try? JSONEncoder().encode(characters) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// Validates that the file has a video track with alpha, then copies it in.
    func importVideo(from source: URL) async throws -> Character {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ImportError.noVideo }
        let formats = try await track.load(.formatDescriptions)
        guard formats.contains(where: Self.hasAlpha) else { throw ImportError.noAlpha }

        let id = UUID()
        let fileName = "\(id.uuidString).\(source.pathExtension.lowercased())"
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(fileName))
        return Character(id: id, fileName: fileName, name: source.deletingPathExtension().lastPathComponent)
    }

    func delete(_ character: Character) {
        try? FileManager.default.removeItem(at: url(for: character))
    }

    nonisolated static func hasAlpha(_ format: CMFormatDescription) -> Bool {
        let codec = CMFormatDescriptionGetMediaSubType(format)
        if codec == kCMVideoCodecType_AppleProRes4444 || codec == kCMVideoCodecType_AppleProRes4444XQ { return true }
        let flag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel)
        return (flag as? Bool) == true
    }
}
