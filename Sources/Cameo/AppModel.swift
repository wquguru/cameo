import AppKit
import ServiceManagement

/// App state shared by the popover and the character window, persisted in UserDefaults.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var characters: [Character]
    @Published var selectedID: UUID? {
        didSet {
            defaults.set(selectedID?.uuidString, forKey: "selectedID")
            if let selectedID { markUsed(selectedID) }
        }
    }
    /// When each character was last shown (seconds since 1970, by id), for `recent`.
    @Published private(set) var lastUsed: [String: Double]
    /// Videos being checked and copied in (or downloaded from the gallery) right now.
    @Published private(set) var importing: [PendingImport] = []
    /// The character just moved to the Trash, while it can still be put back.
    @Published private(set) var trashed: Trashed?

    struct PendingImport: Identifiable {
        let id = UUID()
        let name: String
    }

    struct Trashed {
        let character: Character
        let index: Int
        let file: URL
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
    /// The app's language; `.system` follows macOS (see `AppLanguage`).
    @Published var language = AppLanguage.stored {
        didSet { language.apply() }
    }
    /// A newer release on GitHub, if the update checker found one.
    @Published private(set) var update: UpdateChecker.Update?
    /// What a "检查更新…" click is doing; returns to idle a few seconds after it finishes.
    @Published private(set) var updateCheck = UpdateCheck.idle
    /// Download progress (0...1) while an update installs; Cameo quits and relaunches when it's done.
    @Published private(set) var installProgress: Double?
    /// Why the last in-place update failed (the release page was opened instead).
    @Published var updateFailure: String?

    enum UpdateCheck { case idle, checking, upToDate, failed }

    let store = CharacterStore()
    private lazy var updateChecker = UpdateChecker { [weak self] in self?.update = $0 }
    private let defaults = UserDefaults.standard

    init() {
        characters = [.builtInCat] + store.load()
        defaults.register(defaults: ["scale": 0.8, "visible": true])
        lastUsed = defaults.dictionary(forKey: "lastUsed") as? [String: Double] ?? [:]
        scale = defaults.double(forKey: "scale")
        visible = defaults.bool(forKey: "visible")
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let saved = defaults.string(forKey: "selectedID").flatMap(UUID.init(uuidString:))
        selectedID = characters.contains { $0.id == saved } ? saved : characters.first?.id
    }

    var selected: Character? {
        characters.first { $0.id == selectedID }
    }

    /// Characters, most recently shown first; never-shown ones keep their order at the end.
    var recent: [Character] {
        characters.enumerated().sorted { a, b in
            let x = lastUsed[a.element.id.uuidString] ?? 0, y = lastUsed[b.element.id.uuidString] ?? 0
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    private func markUsed(_ id: UUID) {
        lastUsed[id.uuidString] = Date().timeIntervalSince1970
        defaults.set(lastUsed, forKey: "lastUsed")
    }

    func url(for character: Character) -> URL {
        store.url(for: character)
    }

    func add(_ urls: [URL]) async {
        for url in urls {
            let pending = PendingImport(name: url.deletingPathExtension().lastPathComponent)
            importing.append(pending)
            defer { importing.removeAll { $0.id == pending.id } }
            do {
                insert(try await store.importVideo(from: url))
            } catch {
                errorMessage = L("Couldn’t add “%@”: %@", url.lastPathComponent, error.localizedDescription)
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
        let pending = PendingImport(name: link.name)
        importing.append(pending)
        defer { importing.removeAll { $0.id == pending.id } }
        do {
            let file = try await link.download()
            defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            insert(try await store.importVideo(from: file, origin: link.source))
        } catch {
            errorMessage = L("Couldn’t add “%@”: %@", link.name, error.localizedDescription)
        }
    }

    private func insert(_ character: Character) {
        characters.append(character)
        store.save(characters.filter { !$0.isBuiltIn })
        selectedID = character.id
        visible = true
    }

    func rename(_ character: Character, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !character.isBuiltIn, !name.isEmpty, let i = characters.firstIndex(where: { $0.id == character.id }) else { return }
        characters[i].name = name
        store.save(characters.filter { !$0.isBuiltIn })
    }

    /// Moves the character's video to the Trash; `undoTrash` puts it back while `trashed` is set.
    func moveToTrash(_ character: Character) {
        guard !character.isBuiltIn, let index = characters.firstIndex(where: { $0.id == character.id }) else { return }
        guard let file = store.trash(character) else {
            errorMessage = L("Couldn’t move “%@” to the Trash.", character.name)
            return
        }
        characters.remove(at: index)
        store.save(characters.filter { !$0.isBuiltIn })
        if selectedID == character.id { selectedID = recent.first?.id }
        let item = Trashed(character: character, index: index, file: file)
        trashed = item
        Task {
            try? await Task.sleep(for: .seconds(8))
            if trashed?.file == item.file { trashed = nil }
        }
    }

    func undoTrash() {
        guard let item = trashed else { return }
        trashed = nil
        guard store.restore(item.character, from: item.file) else { return }
        characters.insert(item.character, at: min(item.index, characters.count))
        store.save(characters.filter { !$0.isBuiltIn })
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = L("Couldn’t change the login item: %@", error.localizedDescription)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func startUpdateChecks() {
        updateChecker.start()
    }

    func checkForUpdates() {
        guard updateCheck != .checking else { return }
        updateCheck = .checking
        Task {
            let reached = await updateChecker.check()
            updateCheck = update != nil ? .idle : reached ? .upToDate : .failed
            try? await Task.sleep(for: .seconds(3))
            if updateCheck != .checking { updateCheck = .idle }
        }
    }

    /// Installs the update in place; if that can't be done, says why and opens the release page.
    func installUpdate() {
        guard let update, installProgress == nil else { return }
        installProgress = 0
        updateFailure = nil
        Task {
            do {
                try await Updater.install(update) { [weak self] in self?.installProgress = $0 }
            } catch {
                installProgress = nil
                updateFailure = error.localizedDescription
                NSWorkspace.shared.open(update.url)
            }
        }
    }
}
