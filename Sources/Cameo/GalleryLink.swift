import Foundation

/// A `cameo://add?url=<https .mov>&name=<name>` link, as used by the character gallery.
struct GalleryLink {
    static let maxBytes = 200_000_000
    static let gallery = URL(string: "https://wquguru.github.io/cameo/")!

    let source: URL
    let name: String

    init?(_ url: URL) {
        guard url.scheme == "cameo", url.host == "add",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let value = items.first(where: { $0.name == "url" })?.value,
              let source = URL(string: value), source.scheme == "https" else { return nil }
        self.source = source
        let raw = items.first { $0.name == "name" }?.value ?? source.deletingPathExtension().lastPathComponent
        let name = raw.components(separatedBy: CharacterSet(charactersIn: "/:")).joined(separator: "-")
        self.name = name.isEmpty ? "Character" : String(name.prefix(60))
    }

    /// Downloads the video into a fresh temporary folder, named after the character.
    func download() async throws -> URL {
        let (temp, response) = try await URLSession.shared.download(from: source)
        defer { try? FileManager.default.removeItem(at: temp) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ImportError.download }
        let size = (try? temp.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxBytes else { throw ImportError.tooLarge }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(name).appendingPathExtension("mov")
        try FileManager.default.moveItem(at: temp, to: file)
        return file
    }
}
