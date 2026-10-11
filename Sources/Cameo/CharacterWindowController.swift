import AVFoundation
import AppKit
import CameoShow
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
    private let packageView = PackageView(frame: .zero)
    private var aspect: CGFloat = 0.5
    /// Where the figure was put (dragged, walked, restored). The window may stand elsewhere while
    /// this doesn't fit on screen, so growing and shrinking it back returns it to the same spot.
    private var feet: NSPoint?
    private var loadedID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    private var pollTimer: Timer?
    private var pollCount = 0
    private var screensAsleep = false
    /// The selection restored at launch has been loaded; packages chosen after that walk in.
    private var restored = false
    /// A right-click on the figure, with the view to show the popover beside.
    var onSecondaryClick: ((NSView) -> Void)?

    private var figureView: FigureView {
        if model.selected?.isBuiltIn == true { return catView }
        return model.selected?.isPackage == true ? packageView : playerView
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
        for view in [playerView, catView, packageView] as [FigureView] {
            view.onDragEnded = { [weak self] in self?.dropped() }
            view.onSecondaryClick = { [weak self, weak view] in
                if let view { self?.onSecondaryClick?(view) }
            }
        }
        catView.onMove = { [weak self] dx in self?.moveCat(by: dx) ?? false }
        packageView.position = { [weak self] in self?.walkPosition() }
        packageView.onMove = { [weak self] dx in self?.movePackage(by: dx) }
        packageView.onStart = { [weak self] x in self?.enter(at: x) }

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
            playerView.load(nil)
            packageView.load(nil)
            if character?.isBuiltIn == true {
                aspect = CatRig.canvas.width / CatRig.canvas.height
            } else if let character, character.isPackage {
                let entering = restored
                Task { await loadPackage(character, entering: entering) }
            } else {
                let url = character.map(model.url(for:))
                playerView.load(url)
                if let url { Task { await loadAspect(of: url, id: character?.id) } }
            }
            if panel.contentView !== figureView {
                panel.contentView = figureView
            }
        }
        if character != nil { restored = true }
        layout()
        if model.visible && character != nil {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        updatePlayback()
    }

    private func loadPackage(_ character: Character, entering: Bool) async {
        do {
            let package = try await PackageLoader.load(model.packageFolder(for: character))
            guard character.id == loadedID else { return }
            aspect = CGFloat(package.manifest.width) / CGFloat(package.manifest.height)
            layout()
            packageView.load(package, entering: entering)
        } catch {
            model.errorMessage = L("Couldn’t add “%@”: %@", character.name, error.localizedDescription)
        }
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
        packageView.setPlaying(onScreen && figureView === packageView)
    }

    // MARK: Geometry

    private func layout() {
        let factor = model.selected?.isBuiltIn == true ? Self.catHeightFactor : 1
        let height = Self.baseHeight * model.scale * factor
        let size = NSSize(width: (height * aspect).rounded(), height: height.rounded())
        if figureView.isDragging { feet = shownFeet }
        let wanted = anchor()
        feet = wanted
        // A package walks the screen bottom: it stands on the ground unless it is being dragged.
        let walker = figureView === packageView
        let shown = Self.keepVisible(wanted, size: size, walker: walker, grounded: walker && !figureView.isDragging)
        panel.setFrame(NSRect(x: shown.x - size.width / 2, y: shown.y, width: size.width, height: size.height), display: true)
    }

    /// A drag puts the figure where it was dropped, moved back on screen if it went off; a
    /// package dropped in the air falls back to the ground.
    private func dropped() {
        feet = shownFeet
        let from = panel.frame
        layout()
        feet = shownFeet
        saveAnchor()
        if figureView === packageView, from.minY - panel.frame.minY > 1 { fall(from: from) }
    }

    private func fall(from: NSRect) {
        let to = panel.frame
        panel.setFrame(from, display: false)
        packageView.held = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = min(0.5, 0.15 + (from.minY - to.minY) / 2000)
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(to, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.packageView.held = false }
        }
    }

    private var shownFeet: NSPoint { NSPoint(x: panel.frame.midX, y: panel.frame.minY) }

    private func anchor() -> NSPoint {
        if let feet { return feet }
        let defaults = UserDefaults.standard
        if let saved = defaults.array(forKey: "anchor") as? [Double], saved.count == 2 {
            let point = NSPoint(x: saved[0], y: saved[1])
            if NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }) { return point }
        }
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: visible.maxX - 220, y: visible.minY)
    }

    /// Moves feet that ended up off every screen (dragged away, a display unplugged) back so the
    /// feet stay on a screen and at least half the figure is below its menu bar. A `walker` may
    /// stand off the side of the screen (walking in, or dropped there: it walks back);
    /// `grounded`, it stands on the bottom of the visible frame.
    private static func keepVisible(_ feet: NSPoint, size: NSSize, walker: Bool = false, grounded: Bool = false) -> NSPoint {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return feet }
        func distance(_ frame: NSRect) -> CGFloat {
            hypot(max(frame.minX - feet.x, 0, feet.x - frame.maxX), max(frame.minY - feet.y, 0, feet.y - frame.maxY))
        }
        let screen = screens.min { distance($0.frame) < distance($1.frame) }!
        let visible = screen.visibleFrame
        let side = walker ? size.width / 2 : 0
        let x = min(max(feet.x, visible.minX - side), visible.maxX + side)
        let top = visible.maxY - min(size.height, visible.height) / 2
        let y = grounded ? visible.minY : min(max(feet.y, screen.frame.minY), max(top, screen.frame.minY))
        return NSPoint(x: x, y: y)
    }

    private func saveAnchor() {
        guard panel.frame.width > 0 else { return }
        UserDefaults.standard.set([shownFeet.x, shownFeet.y], forKey: "anchor")
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
        feet?.x = shownFeet.x
        return blocked
    }

    /// Where a package's feet are, how far they may walk with the body still on screen (the
    /// empty sides of the canvas may hang off), and where it can walk in from: just off each
    /// side of the screen that has no display beyond it.
    private func walkPosition() -> (x: CGFloat, bounds: ClosedRange<CGFloat>, entries: [CGFloat])? {
        guard let screen = panel.screen ?? NSScreen.main else { return nil }
        let visible = screen.visibleFrame, frame = screen.frame
        let reach = panel.frame.width * packageView.reach
        let lo = visible.minX + reach, hi = max(lo, visible.maxX - reach)
        func open(_ x: CGFloat) -> Bool {
            !NSScreen.screens.contains { $0 != screen && $0.frame.contains(NSPoint(x: x, y: visible.minY + 1)) }
        }
        // Keep a sliver of the canvas on this screen so the panel still belongs to it.
        var entries: [CGFloat] = []
        if open(frame.minX - 1) { entries.append(frame.minX - reach + 2) }
        if open(frame.maxX + 1) { entries.append(frame.maxX + reach - 2) }
        return (panel.frame.midX, lo...hi, entries)
    }

    private func movePackage(by dx: CGFloat) {
        let origin = panel.frame.origin
        panel.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y))
        feet?.x = shownFeet.x
    }

    /// Puts the figure off-screen where it walks in from.
    private func enter(at x: CGFloat) {
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: x - size.width / 2, y: panel.frame.minY))
        feet?.x = shownFeet.x
    }

    // MARK: Polling

    /// Lets clicks through wherever nothing is drawn, caps the frame rate on battery power,
    /// and remembers where a wandering cat ended up.
    private func poll() {
        guard panel.isVisible else { return }
        let view = figureView
        if !view.isPressed {
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
            packageView.maxFrameRate = rate
            catView.maxFrameRate = rate
            if view === catView || view === packageView { saveAnchor() }
        }
    }

    private static func onBattery() -> Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMBatteryPowerKey
    }
}
