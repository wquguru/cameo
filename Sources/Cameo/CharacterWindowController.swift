import AVFoundation
import AppKit
import Combine
import IOKit.ps

/// The transparent, always-on-top panel that shows the selected character: a video in a
/// `PlayerView`, or the built-in cat in a `CatView`. Its anchor is the figure's feet
/// (bottom-centre), so resizing keeps it standing in place.
@MainActor
final class CharacterWindowController {
    /// Height of a video character at 100 % scale, in points.
    static let baseHeight: CGFloat = 400
    /// The cat's canvas is drawn a little smaller than a video at the same scale.
    static let catHeightFactor: CGFloat = 0.75

    private let model: AppModel
    private let panel: NSPanel
    private let playerView = PlayerView(frame: .zero)
    private let catView = CatView(frame: .zero)
    private var aspect: CGFloat = 0.5
    private var loadedID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    private var pollTimer: Timer?
    private var pollCount = 0
    private var screensAsleep = false
    /// A right-click on the figure, with the view to show the popover beside.
    var onSecondaryClick: ((NSView) -> Void)?

    private var figureView: FigureView {
        model.selected?.isBuiltIn == true ? catView : playerView
    }

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
        for view in [playerView, catView] as [FigureView] {
            view.onDragEnded = { [weak self] in self?.saveAnchor() }
            view.onSecondaryClick = { [weak self, weak view] in
                if let view { self?.onSecondaryClick?(view) }
            }
        }
        catView.onMove = { [weak self] dx in self?.moveCat(by: dx) ?? false }

        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)

        let center = NotificationCenter.default
        center.publisher(for: NSWindow.didChangeOcclusionStateNotification, object: panel)
            .sink { [weak self] _ in self?.updatePlayback() }
            .store(in: &cancellables)
        center.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &cancellables)
        center.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.saveAnchor() }
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
        catView.brain.manual = model.catAction
        if character?.id != loadedID {
            loadedID = character?.id
            if character?.isBuiltIn == true {
                playerView.load(nil)
                aspect = CatRig.canvas.width / CatRig.canvas.height
            } else {
                let url = character.map(model.url(for:))
                playerView.load(url)
                if let url { Task { await loadAspect(of: url, id: character?.id) } }
            }
            if panel.contentView !== figureView {
                panel.contentView = figureView
            }
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
        playerView.setPlaying(onScreen && figureView === playerView)
        catView.setPlaying(onScreen && figureView === catView)
    }

    // MARK: Geometry

    private func layout() {
        let factor = model.selected?.isBuiltIn == true ? Self.catHeightFactor : 1
        let height = Self.baseHeight * model.scale * factor
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
        guard panel.frame.width > 0 else { return }
        UserDefaults.standard.set([panel.frame.midX, panel.frame.minY], forKey: "anchor")
    }

    /// Walks the cat's window sideways, keeping it on its screen. Returns true at an edge.
    private func moveCat(by dx: CGFloat) -> Bool {
        let frame = panel.frame
        guard let bounds = (panel.screen ?? NSScreen.main)?.visibleFrame else { return false }
        // The cat occupies the middle of its canvas; let the empty sides hang off-screen.
        let slack = frame.width * 0.22
        let minX = bounds.minX - slack, maxX = bounds.maxX - frame.width + slack
        var x = frame.minX + dx
        var blocked = false
        if x < minX { x = minX; blocked = dx < 0 }
        if x > maxX { x = maxX; blocked = dx > 0 }
        panel.setFrameOrigin(NSPoint(x: x, y: frame.minY))
        return blocked
    }

    // MARK: Polling

    /// Lets clicks through wherever nothing is drawn, caps the frame rate on battery power,
    /// and remembers where a wandering cat ended up.
    private func poll() {
        guard panel.isVisible else { return }
        let view = figureView
        if !view.isDragging {
            let mouse = NSEvent.mouseLocation
            var hit = false
            if panel.frame.contains(mouse) {
                let local = view.convert(panel.convertPoint(fromScreen: mouse), from: nil)
                hit = view.hasFigure(at: local)
            }
            if panel.ignoresMouseEvents == hit { panel.ignoresMouseEvents = !hit }
        }
        pollCount += 1
        if pollCount % 150 == 1 {
            let rate: Float = Self.onBattery() ? 30 : 60
            playerView.maxFrameRate = rate
            catView.maxFrameRate = rate
            if view === catView { saveAnchor() }
        }
    }

    private static func onBattery() -> Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMBatteryPowerKey
    }
}
