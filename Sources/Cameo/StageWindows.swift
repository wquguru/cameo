import AppKit
import Combine

/// One figure window per character on the stage (`AppModel.stage`). Characters coming on take
/// over the windows of those going off (the most recently chosen first), so a click that swaps the
/// desktop for another character puts her where the last one stood; any others get new windows.
@MainActor
final class StageWindows {
    private let model: AppModel
    private var windows: [UUID: CharacterWindowController] = [:]
    private var cancellables: Set<AnyCancellable> = []
    /// A right-click on a figure: which character, and the view to show the popover beside.
    var onSecondaryClick: ((UUID, NSView) -> Void)?

    init(model: AppModel) {
        self.model = model
        sync(model.stage, entering: false)
        model.$stage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stage in self?.sync(stage, entering: true) }
            .store(in: &cancellables)
        // The popover's action chips play on the chosen character.
        model.onPackageAction = { [weak self] action in
            guard let self, let id = self.model.selectedID else { return }
            self.windows[id]?.request(action)
        }
    }

    private func sync(_ stage: [UUID], entering: Bool) {
        let used = model.lastUsed
        var gone = windows.keys.filter { !stage.contains($0) }
            .sorted { used[$0.uuidString] ?? 0 > used[$1.uuidString] ?? 0 }
        var new = stage.filter { windows[$0] == nil }
        while !gone.isEmpty, !new.isEmpty, let window = windows.removeValue(forKey: gone.removeFirst()) {
            let id = new.removeFirst()
            window.characterID = id
            windows[id] = window
        }
        for id in gone { windows.removeValue(forKey: id)?.close() }
        for id in new {
            let window = CharacterWindowController(model: model, characterID: id, slot: stage.firstIndex(of: id) ?? 0, entering: entering)
            window.onSecondaryClick = { [weak self, weak window] view in
                guard let self, let window else { return }
                self.onSecondaryClick?(window.characterID, view)
            }
            windows[id] = window
        }
    }
}
