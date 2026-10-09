import Foundation
import ServiceManagement

/// App state shared by the popover and the character window, persisted in UserDefaults.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var characters: [Character]
    @Published var selectedID: UUID? {
        didSet { defaults.set(selectedID?.uuidString, forKey: "selectedID") }
    }
    @Published var scale: Double {
        didSet { defaults.set(scale, forKey: "scale") }
    }
    @Published var visible: Bool {
        didSet { defaults.set(visible, forKey: "visible") }
    }
    @Published private(set) var launchAtLogin: Bool
    @Published var errorMessage: String?
    /// What the built-in cat should do; nil lets it wander on its own.
    @Published var catAction: CatAction?
    /// A newer release on GitHub, if the update checker found one.
    @Published var update: UpdateChecker.Update?

    let store = CharacterStore()
    private let defaults = UserDefaults.standard

    init() {
        characters = [.builtInCat] + store.load()
        defaults.register(defaults: ["scale": 0.8, "visible": true])
        scale = defaults.double(forKey: "scale")
        visible = defaults.bool(forKey: "visible")
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let saved = defaults.string(forKey: "selectedID").flatMap(UUID.init(uuidString:))
        selectedID = characters.contains { $0.id == saved } ? saved : characters.first?.id
    }

    var selected: Character? {
        characters.first { $0.id == selectedID }
    }

    func url(for character: Character) -> URL {
        store.url(for: character)
    }

    func add(_ urls: [URL]) async {
        for url in urls {
            do {
                insert(try await store.importVideo(from: url))
            } catch {
                errorMessage = "无法添加“\(url.lastPathComponent)”：\(error.localizedDescription)"
            }
        }
    }

    /// Downloads and adds a gallery character; one that was added before is just selected.
    func add(_ link: GalleryLink) async {
        if let existing = characters.first(where: { $0.source == link.source }) {
            selectedID = existing.id
            visible = true
            return
        }
        do {
            let file = try await link.download()
            defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            insert(try await store.importVideo(from: file, origin: link.source))
        } catch {
            errorMessage = "无法添加“\(link.name)”：\(error.localizedDescription)"
        }
    }

    private func insert(_ character: Character) {
        characters.append(character)
        store.save(characters.filter { !$0.isBuiltIn })
        selectedID = character.id
        visible = true
    }

    func remove(_ character: Character) {
        guard !character.isBuiltIn else { return }
        characters.removeAll { $0.id == character.id }
        store.delete(character)
        store.save(characters.filter { !$0.isBuiltIn })
        if selectedID == character.id { selectedID = characters.first?.id }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = "无法更改登录项：\(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
