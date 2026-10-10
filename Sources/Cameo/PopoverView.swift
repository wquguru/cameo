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
                Text("Cameo").fontWeight(.semibold)
                Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
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
        return L("Showing · %@", name)
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

    private var cards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), alignment: .leading, spacing: 8) {
            ForEach(model.recent.prefix(Self.recentCount)) { character in
                let lit = character.id == model.selectedID
                VStack(spacing: 4) {
                    CharacterCard(image: thumbnails.image(for: character, url: model.url(for: character)), lit: lit) {
                        model.selectedID = character.id
                        model.visible = true
                    }
                    Text(character.name)
                        .font(.system(size: 11, weight: lit ? .medium : .regular))
                        .foregroundStyle(lit ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .help(character.name)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(character.name)
                .contextMenu {
                    if !character.isBuiltIn {
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
    }

    /// What the built-in cat does: on its own (Auto), or one action held until changed.
    /// Drawn like a small segmented control, but with equal segments whose labels shrink to fit,
    /// so longer translations never widen the popover (NSSegmentedControl won't compress).
    private var catActions: some View {
        let choices: [(CatAction?, String)] = [(nil, L("Auto"))] + CatAction.allCases.map { ($0, $0.label) }
        return HStack(spacing: 2) {
            ForEach(choices, id: \.1) { action, label in
                let selected = model.catAction == action
                Button { model.catAction = action } label: {
                    Text(label)
                        .font(.system(size: 12, weight: selected ? .medium : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Chaofei’s action"))
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
