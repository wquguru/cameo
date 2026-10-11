import CameoShow
import SwiftUI
import UniformTypeIdentifiers

/// The menu bar popover: native menu look (system appearance, separators, menu rows) around one
/// custom part, the character cards, where the selected card is lit like a stage.
struct PopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var thumbnails: Thumbnails
    var onAdd: () -> Void
    var onOpenLibrary: () -> Void
    @State private var dropTargeted = false
    /// Nudges the cards sideways when a ⌘-click finds the desktop full.
    @State private var shaking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !model.visible && !model.hideHintSeen {
                Text(L("Until you show it again, Cameo stays in the Dock, so you can find it even when the menu bar is full."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }
            separator
            section(L("Characters"), accessory: { libraryLink }) {
                cards
                if model.selected?.isBuiltIn == true {
                    catActions
                } else if let selected = model.selected, let actions = model.packageActions(for: selected) {
                    packageActions(actions)
                }
                if model.characters.count == 1 {
                    Text(L("Drop in a .mov with alpha (HEVC with Alpha or ProRes 4444)"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            separator
            section(L("Size")) { sizeSlider }
            if let message = model.errorMessage {
                separator
                MenuRow(action: { model.errorMessage = nil }) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }
                .help(L("Click to dismiss"))
            }
            separator
            updateRow
            MenuRow(action: AboutPanel.show) {
                HStack(spacing: 4) {
                    Color.clear.frame(width: 14, height: 1)
                    Text(L("About Cameo"))
                }
            }
            separator
            MenuRow(action: { model.setLaunchAtLogin(!model.launchAtLogin) }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(model.launchAtLogin ? 1 : 0)
                        .frame(width: 14)
                    Text(L("Open at Login"))
                }
            }
            .accessibilityAddTraits(model.launchAtLogin ? .isSelected : [])
            languageRow
            MenuRow(action: { NSApp.terminate(nil) }) {
                HStack(spacing: 4) {
                    Color.clear.frame(width: 14, height: 1)
                    Text(L("Quit Cameo"))
                    Spacer()
                    Text("⌘Q").font(.system(size: 12)).opacity(0.6)
                }
            }
            .keyboardShortcut("q")
        }
        .font(.system(size: 13))
        .padding(.vertical, 6)
        .frame(width: 320)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 2).padding(3)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.add(urls) }
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Cameo").fontWeight(.semibold)
                    if let dev = DevBuild.label {
                        // Dev builds only, so not translated.
                        Text("DEV").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.pink))
                            .help(dev)
                    }
                }
                Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
                if let dev = DevBuild.label {
                    Text(dev).font(.system(size: 11).monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            Toggle(L("Show Character"), isOn: $model.visible)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var status: String {
        guard model.visible, let name = model.selected?.name else { return L("Hidden") }
        let others = model.stage.count - 1
        return others > 0 ? L("Showing · %@ and %d more", name, others) : L("Showing · %@", name)
    }

    /// "检查更新…" with the current version; becomes the update itself once one is found,
    /// a progress bar while it installs, and says why when installing in place failed.
    @ViewBuilder private var updateRow: some View {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if let update = model.update, let progress = model.installProgress {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L("Downloading %@…", update.version))
                    Spacer()
                    Text("\(Int(progress * 100))%").font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
                ProgressView(value: progress).controlSize(.small).accessibilityLabel(L("Download progress"))
            }
            .padding(.leading, 32)
            .padding(.trailing, 14)
            .padding(.vertical, 4)
        } else if let update = model.update, let failure = model.updateFailure {
            MenuRow(action: { model.updateFailure = nil }) {
                VStack(alignment: .leading, spacing: 1) {
                    Label(L("Couldn’t update automatically"), systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Text(L("%@. Opened the download page.", failure)).font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 18)
                }
            }
            .help(L("Click to dismiss") + " · " + update.url.absoluteString)
        } else if let update = model.update {
            MenuRow(action: model.installUpdate) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Circle().fill(Theme.spotlight).frame(width: 6, height: 6).frame(width: 14)
                        Text(L("Update to %@", update.version))
                    }
                    Text(update.size > 0
                         ? L("%@ · reopens when done", ByteCountFormatter.string(fromByteCount: Int64(update.size), countStyle: .file))
                         : L("Reopens when done"))
                        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 18)
                }
            }
            .contextMenu {
                Button(L("Release Notes")) { NSWorkspace.shared.open(update.url) }
            }
        } else {
            MenuRow(action: model.checkForUpdates) {
                HStack(spacing: 4) {
                    Group {
                        switch model.updateCheck {
                        case .checking: ProgressView().controlSize(.mini)
                        case .upToDate: Image(systemName: "checkmark").foregroundStyle(.green)
                        case .failed: Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        case .idle: Color.clear
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14, height: 14)
                    Text(checkLabel)
                    Spacer()
                    Text(current).font(.system(size: 12)).opacity(0.6)
                }
            }
            .disabled(model.updateCheck == .checking)
        }
    }

    /// Language: a menu of the system language, English and 简体中文, like a pop-up in a menu.
    private var languageRow: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 14, height: 1)
            Text(L("Language"))
            Spacer()
            Menu {
                Picker(selection: $model.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                } label: { EmptyView() }
                .pickerStyle(.inline)
            } label: {
                Text(model.language.label)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(L("Language"))
        }
        .frame(minHeight: 22)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    private var checkLabel: String {
        switch model.updateCheck {
        case .checking: L("Checking for Updates…")
        case .upToDate: L("Cameo is up to date")
        case .failed: L("Couldn’t reach GitHub")
        case .idle: L("Check for Updates…")
        }
    }

    private var separator: some View {
        Divider().padding(.horizontal, 14).padding(.vertical, 6)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        section(title, accessory: { EmptyView() }, content: content)
    }

    private func section<Accessory: View, Content: View>(_ title: String, @ViewBuilder accessory: () -> Accessory,
                                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                accessory()
            }
            content()
        }
        .padding(.horizontal, 14)
    }

    /// The popover shows the most recent characters; the library has them all.
    static let recentCount = 7

    /// Opens the library window; the chevron marks it as staying in the app (the gallery is in
    /// the add menu).
    private var libraryLink: some View {
        Button(action: onOpenLibrary) {
            HStack(spacing: 2) {
                Text(L("All %@", String(model.characters.count)))
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
            }
        }
        .buttonStyle(.link)
        .font(.system(size: 11))
    }

    /// The ways to get a character: a video from disk, one from the gallery, or making one.
    private func showAddMenu() {
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(L("Choose Videos…"), onAdd))
        menu.addItem(LinkMenuItem(L("Add from Gallery"), GalleryLink.gallery))
        menu.addItem(.separator())
        menu.addItem(LinkMenuItem(L("Make Your Own"), GalleryLink.make))
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func toggle(_ character: Character) {
        guard !model.toggleOnStage(character.id) else { return }
        withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shaking = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shaking = false }
        }
    }

    private var cards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), alignment: .leading, spacing: 8) {
            ForEach(model.recent.prefix(Self.recentCount)) { character in
                let lit = model.stage.contains(character.id)
                VStack(spacing: 4) {
                    CharacterCard(image: thumbnails.image(for: character, url: model.url(for: character)), lit: lit) {
                        // As in Finder: a click shows only her, ⌘-click adds her or takes her off.
                        if NSEvent.modifierFlags.contains(.command) { toggle(character) } else { model.show(character.id) }
                    }
                    Text(character.name)
                        .font(.system(size: 11, weight: lit ? .medium : .regular))
                        .foregroundStyle(lit ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .help(lit ? L("%@ · ⌘-click to take off the Desktop", character.name)
                          : L("%@ · ⌘-click to also show on the Desktop", character.name))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(character.name)
                .contextMenu {
                    Button(L("Show on Desktop")) { model.show(character.id) }
                    Button(lit ? L("Take off the Desktop (⌘-Click)") : L("Also Show on Desktop (⌘-Click)")) { toggle(character) }
                    if !character.isBuiltIn {
                        Divider()
                        Button(L("Move “%@” to Trash", character.name), role: .destructive) { model.moveToTrash(character) }
                    }
                }
            }
            VStack(spacing: 4) {
                Button(action: showAddMenu) {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(height: CharacterCard.height)
                        .overlay(Image(systemName: "plus").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Add a character"))
                Text(L("Add")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .offset(x: shaking ? -8 : 0)
    }

    /// What the built-in cat does: on its own (Auto), or one action held until changed.
    private var catActions: some View {
        ActionChips(choices: [(nil, L("Auto"))] + CatAction.allCases.map { ($0.rawValue, $0.label) },
                    selected: model.catAction?.rawValue,
                    pick: { model.catAction = $0.flatMap(CatAction.init(rawValue:)) })
            .accessibilityLabel(L("Chaofei’s action"))
    }

    /// What a package can do, from its manifest: a click plays one once, then it carries on by
    /// itself (Auto), going through whatever transitions the action needs.
    private func packageActions(_ actions: PackageActions) -> some View {
        let walk: [(String?, String)] = actions.walks ? [(Show.walkRequest, L("Walk"))] : []
        return ActionChips(choices: [(nil, L("Auto"))] + walk + actions.actions.map { ($0.id, $0.label) },
                           selected: model.packageAction,
                           pick: { model.perform($0) })
            .help(L("Click to play it once, then back to Auto"))
            .accessibilityLabel(L("Actions"))
    }

    private var sizeSlider: some View {
        HStack(alignment: .bottom, spacing: 10) {
            FigureShape().fill(.secondary).frame(width: 8, height: 16)
            Slider(value: $model.scale, in: 0.2...2)
                .controlSize(.small)
                .padding(.bottom, 1)
                .accessibilityLabel(L("Character size"))
                .accessibilityValue("\(Int(model.scale * 100))%")
            FigureShape().fill(.secondary).frame(width: 13, height: 26)
        }
    }
}

/// Action buttons in equal cells, one row for up to six, else rows of four, so the popover keeps
/// its width; labels shrink to fit longer translations. The chosen one is filled with the accent.
private struct ActionChips: View {
    let choices: [(String?, String)]
    let selected: String?
    let pick: (String?) -> Void

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: choices.count <= 6 ? choices.count : 4)
        LazyVGrid(columns: columns, spacing: 4) {
            // By position: manifest labels may repeat.
            ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                let (id, label) = choice
                let on = selected == id
                Button { pick(id) } label: {
                    Text(label)
                        .font(.system(size: 12, weight: on ? .medium : .regular))
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.accentColor : Color.primary.opacity(0.07)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A full-width menu item: highlighted with the accent colour on hover, like an NSMenu item.
private struct MenuRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .foregroundStyle(hovered ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 5).fill(hovered ? Color.accentColor : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .onHover { hovered = $0 }
    }
}
