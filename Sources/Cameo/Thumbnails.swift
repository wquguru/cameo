import AVFoundation
import AppKit

/// First-frame thumbnails of imported characters, kept in memory.
@MainActor
final class Thumbnails: ObservableObject {
    @Published private(set) var images: [UUID: NSImage] = [:]
    private var pending: Set<UUID> = []

    func image(for character: Character, url: URL) -> NSImage? {
        if let image = images[character.id] { return image }
        guard !pending.contains(character.id) else { return nil }
        pending.insert(character.id)
        Task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)
            if let (cgImage, _) = try? await generator.image(at: .zero) {
                images[character.id] = NSImage(cgImage: cgImage, size: .zero)
            }
            pending.remove(character.id)
        }
        return nil
    }
}
