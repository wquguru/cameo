import SwiftUI

/// The library window's content (design/Library*.dc.html): every character in a grid, most
/// recently shown first as of opening (showing one doesn't reshuffle the grid under the pointer).
/// Click selects, double-click or Return shows it on the desktop, Space previews it large, arrow
/// keys move, Delete trashes (with undo), ⌘+/⌘− resize; hover plays a character, right-click
/// renames, reveals or trashes it, drop videos anywhere to add them.
struct LibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var thumbnails: Thumbnails
    var onAdd: () -> Void
    @State private var query = ""
    @State private var dropTargeted = false
    @State private var selection: UUID?
    @State private var previewing = false
    @State private var order: [UUID] = []
    @State private var columns = 1
    @FocusState private var gridFocused: Bool
    @AppStorage(LibraryZoom.key) private var zoom = LibraryZoom.standard
    @Environment(\.undoManager) private var undoManager

    private static let padding: CGFloat = 24
    private static let spacing: CGFloat = 8

    private var height: CGFloat { LibraryZoom.height(zoom) }

    private var shown: [Character] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let all = q.isEmpty ? model.recent : model.recent.filter {
            $0.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
        }
        // Characters added since the order was taken come first, then the order as of opening.
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return all.enumerated()
            .sorted { (rank[$0.element.id] ?? -1, $0.offset) < (rank[$1.element.id] ?? -1, $1.offset) }
            .map(\.element)
    }

    private var selected: Character? { shown.first { $0.id == selection } }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let message = model.errorMessage { banner(message) }
                        if shown.isEmpty && model.importing.isEmpty {
                            noResults
                        } else {
                            grid
                        }
                        if model.characters.count == 1 && query.isEmpty && model.importing.isEmpty { dropZone }
                    }
                    .padding(.horizontal, Self.padding)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
                }
                .focusable()
                .focusEffectDisabled()
                .focused($gridFocused)
                .onKeyPress(phases: .down) { press in handle(press, proxy) }
            }
            .onAppear { columns = Self.columns(geo.size.width, height) }
            .onChange(of: geo.size.width) { _, width in columns = Self.columns(width, height) }
            .onChange(of: zoom) { _, _ in columns = Self.columns(geo.size.width, height) }
        }
        .overlay { if previewing, let selected { preview(selected) } }
        .overlay(alignment: .bottom) { if let item = model.trashed { undoToast(item) } }
        .overlay { if dropTargeted { dropOverlay } }
        .animation(.easeOut(duration: 0.2), value: model.trashed?.file)
        .animation(.easeOut(duration: 0.15), value: previewing)
        .animation(.easeOut(duration: 0.2), value: zoom)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.add(urls) }
            return true
        } isTargeted: { dropTargeted = $0 }
        .onAppear {
            order = model.recent.map(\.id)
            if selection == nil { selection = model.visible ? model.selectedID : nil }
            gridFocused = true
        }
        .onChange(of: model.characters.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) { self.selection = nil }
        }
        .onChange(of: selection) { _, id in if id == nil { previewing = false } }
        .navigationTitle(L("Characters"))
        .navigationSubtitle(String(model.characters.count))
        .searchable(text: $query, placement: .toolbar, prompt: L("Search"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAdd) { Label(L("Add"), systemImage: "plus") }
                    .help(L("Add a character video"))
            }
        }
    }

    private static func columns(_ width: CGFloat, _ height: CGFloat) -> Int {
        let cell = height * 1.2
        return max(2, Int((width - 2 * padding + spacing) / (cell + spacing)))
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing, alignment: .top), count: columns),
                  spacing: 18) {
            ForEach(model.importing) { pending in
                PendingCard(name: pending.name, height: height)
            }
            ForEach(shown) { character in
                let video = character.isBuiltIn ? nil : model.url(for: character)
                LibraryTile(
                    character: character,
                    image: thumbnails.image(for: character, url: model.url(for: character)),
                    video: video,
                    box: thumbnails.bounds[character.id],
                    height: height,
                    lit: model.visible && character.id == model.selectedID,
                    selected: character.id == selection,
                    onSelect: { selection = character.id; gridFocused = true },
                    onShow: { selection = character.id; show(character) },
                    onRename: { model.rename(character, to: $0) },
                    onTrash: { trash(character) })
                .id(character.id)
            }
        }
    }

    private func show(_ character: Character) {
        model.selectedID = character.id
        model.visible = true
    }

    /// The grid's keys, as in Finder and Photos.
    private func handle(_ press: KeyPress, _ proxy: ScrollViewProxy) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            switch press.characters {
            case "=": LibraryZoom.shared.zoomIn(nil)
            default: return .ignored
            }
            return .handled
        }
        let list = shown
        let index = list.firstIndex { $0.id == selection }
        func move(_ by: Int) {
            guard !list.isEmpty else { return }
            let next = index.map { min(max($0 + by, 0), list.count - 1) } ?? 0
            selection = list[next].id
            proxy.scrollTo(list[next].id)
        }
        switch press.key {
        case .leftArrow: move(-1)
        case .rightArrow: move(1)
        case .upArrow: move(-columns)
        case .downArrow: move(columns)
        case .return:
            guard let selected else { return .ignored }
            show(selected)
        case .space:
            guard selected != nil else { return .ignored }
            previewing.toggle()
        case .escape:
            guard previewing else { return .ignored }
            previewing = false
        case .delete, .deleteForward:
            guard let selected, !selected.isBuiltIn, let index else { return .ignored }
            let neighbour = list.indices.contains(index + 1) ? list[index + 1] : index > 0 ? list[index - 1] : nil
            trash(selected)
            selection = neighbour?.id
        default:
            return .ignored
        }
        return .handled
    }

    /// Space's large preview, like Quick Look: the character playing on a lit stage.
    private func preview(_ character: Character) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { previewing = false }
            VStack(spacing: 14) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 18).fill(Theme.stage)
                    StageLights(height: 380)
                    if character.isBuiltIn {
                        if let image = thumbnails.images[character.id] {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                .padding(.horizontal, 48).padding(.top, 80).padding(.bottom, 34)
                        }
                    } else {
                        LoopingVideo(url: model.url(for: character))
                            .id(character.id)
                            .padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 20)
                    }
                }
                .frame(width: 380, height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                HStack(spacing: 12) {
                    Text(character.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    Button(L("Show on Desktop")) {
                        show(character)
                        previewing = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 380)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 26).fill(.regularMaterial))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        }
        .transition(.opacity)
    }

    private func trash(_ character: Character) {
        model.moveToTrash(character)
        undoManager?.registerUndo(withTarget: model) { $0.undoTrash() }
        undoManager?.setActionName(L("Move to Trash"))
    }

    private func banner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).lineLimit(2)
            Spacer()
            Button { model.errorMessage = nil } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("Click to dismiss"))
        }
        .font(.system(size: 13))
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(minHeight: 40)
        .background(Capsule().fill(Color.red.opacity(0.1)))
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundStyle(.tertiary)
            Text(L("No characters named “%@”", query)).font(.system(size: 17, weight: .semibold))
            Link(L("Find one in the gallery ↗"), destination: GalleryLink.gallery).font(.system(size: 13))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 140)
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 40, weight: .light)).foregroundStyle(.tertiary)
            Text(L("Drop videos with an alpha channel here")).font(.system(size: 20, weight: .semibold))
            Text(L("A .mov encoded as HEVC with Alpha or ProRes 4444; you can drop several at once."))
                .font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(L("Choose Videos…"), action: onAdd).buttonStyle(.borderedProminent)
                Link(L("Browse the Gallery ↗"), destination: GalleryLink.gallery).buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.top, 6)
            Link(L("No video? Make your own ↗"), destination: GalleryLink.make).font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(RoundedRectangle(cornerRadius: 22).strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.accentColor, lineWidth: 2.5)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor.opacity(0.06)))
            .overlay(alignment: .bottom) {
                Label(L("Release to add"), systemImage: "arrow.down.to.line")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.accentColor))
                    .padding(.bottom, 24)
            }
            .padding(12)
            .allowsHitTesting(false)
    }

    private func undoToast(_ item: AppModel.Trashed) -> some View {
        HStack(spacing: 8) {
            Text(L("Moved “%@” to the Trash", item.character.name)).lineLimit(1)
            Button(L("Undo")) { model.undoTrash() }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(.white.opacity(0.14)))
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(Capsule().fill(Color(white: 0.17).opacity(0.94)))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        .padding(.bottom, 22)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// A video being checked and copied in.
private struct PendingCard: View {
    let name: String
    let height: CGFloat

    var body: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.06))
                .frame(height: height)
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L("Importing…")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        ProgressView().progressViewStyle(.linear).controlSize(.small)
                    }
                    .padding(12)
                }
            Text(name).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
    }
}
