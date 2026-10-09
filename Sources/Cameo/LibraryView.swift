import SwiftUI

/// The library window's content (design/Library*.dc.html): every character in a grid, most
/// recently shown first. Click to show one, hover to preview it, right-click to rename, reveal
/// or trash it, drop videos anywhere to add them.
struct LibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var thumbnails: Thumbnails
    var onAdd: () -> Void
    @State private var query = ""
    @State private var dropTargeted = false
    @Environment(\.undoManager) private var undoManager

    private var shown: [Character] {
        let all = model.recent
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
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
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
        }
        .overlay(alignment: .bottom) { if let item = model.trashed { undoToast(item) } }
        .overlay { if dropTargeted { dropOverlay } }
        .animation(.easeOut(duration: 0.2), value: model.trashed?.file)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.add(urls) }
            return true
        } isTargeted: { dropTargeted = $0 }
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

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 136, maximum: 168), spacing: 17)], spacing: 18) {
            ForEach(model.importing) { pending in
                PendingCard(name: pending.name)
            }
            ForEach(shown) { character in
                LibraryCard(
                    character: character,
                    image: thumbnails.image(for: character, url: model.url(for: character)),
                    video: character.isBuiltIn ? nil : model.url(for: character),
                    lit: model.visible && character.id == model.selectedID,
                    onSelect: {
                        model.selectedID = character.id
                        model.visible = true
                    },
                    onRename: { model.rename(character, to: $0) },
                    onTrash: { trash(character) })
            }
        }
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

/// One character in the library: its card (playing on hover), its name (editable after "Rename"),
/// and the context menu.
private struct LibraryCard: View {
    let character: Character
    let image: NSImage?
    let video: URL?
    let lit: Bool
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onTrash: () -> Void
    @State private var hovered = false
    @State private var draft: String?
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 7) {
            CharacterCard(image: image, lit: lit, height: 106, cornerRadius: 14, greysUnlit: false,
                          preview: hovered ? video : nil, action: onSelect)
                .shadow(color: .black.opacity(hovered ? 0.12 : 0), radius: 8, y: 4)
                .onHover { hovered = $0 }
            if let draft {
                TextField(L("Name"), text: Binding(get: { draft }, set: { self.draft = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .focused($editing)
                    .onSubmit { commit() }
                    .onExitCommand { self.draft = nil }
                    .onChange(of: editing) { _, focused in if !focused { commit() } }
            } else {
                Text(character.name)
                    .font(.system(size: 12, weight: lit ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .help(character.name)
        .contextMenu {
            if !character.isBuiltIn {
                Button(L("Rename")) {
                    draft = character.name
                    DispatchQueue.main.async { editing = true }
                }
                Button(L("Show in Finder")) {
                    if let video { NSWorkspace.shared.activateFileViewerSelecting([video]) }
                }
                Divider()
                Button(L("Move to Trash"), role: .destructive, action: onTrash)
            }
        }
    }

    private func commit() {
        if let draft { onRename(draft) }
        draft = nil
    }
}

/// A video being checked and copied in.
private struct PendingCard: View {
    let name: String

    var body: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.06))
                .frame(height: 106)
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
