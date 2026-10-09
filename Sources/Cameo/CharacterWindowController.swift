import AVFoundation
import AppKit
import Combine
import IOKit.ps

/// The transparent, always-on-top panel that shows the selected character.
/// Its anchor is the figure's feet (bottom-centre), so resizing keeps it standing in place.
@MainActor
final class CharacterWindowController {
    /// Height of the character at 100 % scale, in points.
    static let baseHeight: CGFloat = 400

    private let model: AppModel
    private let panel: NSPanel
    private let playerView = PlayerView(frame: .zero)
    private var aspect: CGFloat = 0.5
    private var loadedID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    private var pollTimer: Timer?
    private var pollCount = 0
    private var screensAsleep = false

    init(model: AppModel) {
        self.model = model
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = playerView
        playerView.onDragEnded = { [weak self] in self?.saveAnchor() }

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)

        let center = NotificationCenter.default
        center.publisher(for: NSWindow.didChangeOcclusionStateNotification, object: panel)
            .sink { [weak self] _ in self?.updatePlayback() }
            .store(in: &cancellables)
        center.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &cancellables)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in self?.screensAsleep = true; self?.updatePlayback() }
            .store(in: &cancellables)
        workspace.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in self?.screensAsleep = false; self?.updatePlayback() }
            .store(in: &cancellables)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        update()
    }

    // MARK: State

    private func update() {
        let character = model.selected
        if character?.id != loadedID {
            loadedID = character?.id
            let url = character.map(model.url(for:))
            playerView.load(url)
            if let url { Task { await loadAspect(of: url, id: character?.id) } }
        }
        layout()
        if model.visible && character != nil {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        updatePlayback()
    }

    private func loadAspect(of url: URL, id: UUID?) async {
        guard let track = try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize), size.height > 0,
              id == loadedID else { return }
        aspect = size.width / size.height
        layout()
    }

    private func updatePlayback() {
        let onScreen = panel.isVisible && panel.occlusionState.contains(.visible) && !screensAsleep
        playerView.setPlaying(onScreen)
    }

    // MARK: Geometry

    private func layout() {
        let height = Self.baseHeight * model.scale
        let size = NSSize(width: (height * aspect).rounded(), height: height.rounded())
        let feet = anchor()
        panel.setFrame(NSRect(x: feet.x - size.width / 2, y: feet.y, width: size.width, height: size.height), display: true)
    }

    private func anchor() -> NSPoint {
        if panel.frame.width > 0 { return NSPoint(x: panel.frame.midX, y: panel.frame.minY) }
        let defaults = UserDefaults.standard
        if let saved = defaults.array(forKey: "anchor") as? [Double], saved.count == 2 {
            let point = NSPoint(x: saved[0], y: saved[1])
            if NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }) { return point }
        }
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: visible.maxX - 220, y: visible.minY)
    }

    private func saveAnchor() {
        UserDefaults.standard.set([panel.frame.midX, panel.frame.minY], forKey: "anchor")
    }

    // MARK: Polling

    /// Lets clicks through wherever the current frame is transparent, and caps the
    /// frame rate on battery power.
    private func poll() {
        guard panel.isVisible else { return }
        if !playerView.isDragging {
            let mouse = NSEvent.mouseLocation
            var hit = false
            if panel.frame.contains(mouse) {
                let local = playerView.convert(panel.convertPoint(fromScreen: mouse), from: nil)
                hit = playerView.hasFigure(at: local)
            }
            if panel.ignoresMouseEvents == hit { panel.ignoresMouseEvents = !hit }
        }
        pollCount += 1
        if pollCount % 150 == 1 {
            playerView.maxFrameRate = Self.onBattery() ? 30 : 60
        }
    }

    private static func onBattery() -> Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMBatteryPowerKey
    }
}
