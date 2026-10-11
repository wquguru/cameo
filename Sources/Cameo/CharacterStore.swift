import AVFoundation
import CameoShow
import Foundation

struct Character: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    var name: String
    /// Where a gallery character was downloaded from, so adding it twice selects it instead.
    var source: URL? = nil
    /// A package folder (manifest.json + clips) instead of a single video.
    var package: Bool? = nil

    /// The cat drawn in code; always present, never stored or deleted.
    static let builtInCat = Character(id: UUID(uuidString: "00000000-0000-0000-0000-000000000CA7")!, fileName: "", name: "Chaofei")

    var isBuiltIn: Bool { id == Self.builtInCat.id }
    var isPackage: Bool { package == true }
    /// A package shown straight from where it is (`CAMEO_PACKAGE`); never saved to the library.
    var isTransient: Bool { fileName.hasPrefix("/") }
}

enum ImportError: LocalizedError {
    case noVideo, noAlpha, download, tooLarge, badPackage

    var errorDescription: String? {
        switch self {
        case .noVideo: L("The file has no video track.")
        case .noAlpha: L("This video has no alpha channel. Use a .mov encoded as HEVC with Alpha or ProRes 4444.")
        case .download: L("The download failed.")
        case .badPackage: L("This folder is not a valid character package (manifest.json and clips).")
        case .tooLarge: L("The file is larger than 200 MB.")
        }
    }
}

/// Imported videos live in ~/Library/Application Support/Cameo/Characters, indexed by characters.json.
@MainActor
final class CharacterStore {
    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("characters.json") }

    /// `CAMEO_DATA_DIR` points at another folder, for testing without touching the real library;
    /// dev builds keep theirs in "Cameo Dev".
    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = ProcessInfo.processInfo.environment["CAMEO_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? support.appendingPathComponent(DevBuild.isDev ? "Cameo Dev/Characters" : "Cameo/Characters", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private var previews: [UUID: URL] = [:]

    /// A character's file or folder.
    func url(for character: Character) -> URL {
        character.isTransient ? URL(fileURLWithPath: character.fileName, isDirectory: true)
            : directory.appendingPathComponent(character.fileName)
    }

    /// A video to show in tiles and thumbnails: the file itself, or a package's idle clip.
    func previewURL(for character: Character) -> URL {
        guard character.isPackage else { return url(for: character) }
        if let cached = previews[character.id] { return cached }
        let folder = url(for: character)
        let clips = (try? PackageLoader.manifest(in: folder))?.clips ?? []
        let clip = clips.first { $0.kind == .idle } ?? clips.first
        let preview = folder.appendingPathComponent(clip?.file ?? "")
        previews[character.id] = preview
        return preview
    }

    static func isPackageFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Validates a package folder (manifest and every clip file), then copies it in.
    func importPackage(from folder: URL) async throws -> Character {
        let manifest: PackageManifest
        do { manifest = try PackageLoader.manifest(in: folder) } catch { throw ImportError.badPackage }
        guard manifest.clips.allSatisfy({ FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.file).path) })
        else { throw ImportError.badPackage }
        let id = UUID()
        let destination = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        try await Task.detached { try FileManager.default.copyItem(at: folder, to: destination) }.value
        let name = manifest.name.isEmpty ? folder.lastPathComponent : manifest.name
        return Character(id: id, fileName: id.uuidString, name: name, package: true)
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
    func importVideo(from source: URL, origin: URL? = nil) async throws -> Character {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ImportError.noVideo }
        let formats = try await track.load(.formatDescriptions)
        guard formats.contains(where: Self.hasAlpha) else { throw ImportError.noAlpha }

        let id = UUID()
        let fileName = "\(id.uuidString).\(source.pathExtension.lowercased())"
        let destination = directory.appendingPathComponent(fileName)
        try await Task.detached { try FileManager.default.copyItem(at: source, to: destination) }.value
        return Character(id: id, fileName: fileName, name: source.deletingPathExtension().lastPathComponent, source: origin)
    }

    /// Moves the character's video to the Trash; returns where it went, for undo.
    func trash(_ character: Character) -> URL? {
        var trashed: NSURL?
        try? FileManager.default.trashItem(at: url(for: character), resultingItemURL: &trashed)
        return trashed as URL?
    }

    /// Puts a trashed video back.
    func restore(_ character: Character, from trashed: URL) -> Bool {
        (try? FileManager.default.moveItem(at: trashed, to: url(for: character))) != nil
    }

    nonisolated static func hasAlpha(_ format: CMFormatDescription) -> Bool {
        let codec = CMFormatDescriptionGetMediaSubType(format)
        if codec == kCMVideoCodecType_AppleProRes4444 || codec == kCMVideoCodecType_AppleProRes4444XQ {
            // ProRes 4444 may be opaque; a 32-bit depth means it carries alpha.
            let depth = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_Depth) as? Int
            return depth.map { $0 == 32 } ?? true
        }
        let flag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel)
        return (flag as? Bool) == true
    }
}
