import CameoShow
import Foundation

/// What a package can be asked to do, read from its manifest: the actions its show can reach,
/// each with button text, and whether it walks.
struct PackageActions {
    struct Action: Identifiable {
        let id: String
        let label: String
    }

    let actions: [Action]
    let walks: Bool

    init?(folder: URL) {
        guard let manifest = try? PackageLoader.manifest(in: folder), !manifest.clips.isEmpty else { return nil }
        // Actions from the resting pose first, then those that need a change of pose (lying down).
        let rest = manifest.clips.first { $0.kind == .idle }?.from
        let reachable = Show(clips: manifest.clips).actions
        actions = (reachable.filter { $0.from == rest } + reachable.filter { $0.from != rest })
            .map { Action(id: $0.id, label: $0.label ?? Self.label(for: $0.id)) }
        walks = manifest.clips.contains { $0.kind == .walk } && manifest.clips.contains { $0.kind == .idle }
    }

    /// Clip ids the package skill writes get translated names; any other id is made readable
    /// ("lie_phone" → "Lie phone").
    static func label(for id: String) -> String {
        switch id {
        case "wave": L("Wave")
        case "bow": L("Bow")
        case "jump": L("Jump")
        case "spin": L("Spin")
        case "cheer": L("Cheer")
        case "stretch": L("Stretch")
        case "dance": L("Dance")
        case "lie_idle": L("Rest")
        case "lie_phone": L("Phone")
        case "high_five": L("High Five")
        case "pillow_fight": L("Pillow Fight")
        default: Self.readable(id)
        }
    }

    private static func readable(_ id: String) -> String {
        let words = id.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
