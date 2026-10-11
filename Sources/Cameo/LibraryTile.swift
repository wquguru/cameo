import SwiftUI

/// One character in the library (design/Library.dc.html): the figure itself, cropped to its
/// pixels and standing on the bottom edge, with no tile around it. Those on the desktop (shown in
/// `LibraryStage` above) are faded, with an amber dot by the name. Click shows only it, ⌘-click
/// adds it or takes it off (`onToggle`), hovering plays it, the context menu does the same and
/// renames, reveals or trashes it.
struct LibraryTile: View {
    let character: Character
    let image: NSImage?
    let video: URL?
    /// Where the figure sits in the video frame, to crop the hover preview like the thumbnail.
    let box: CGRect?
    let height: CGFloat
    /// A small line under the name: what a package can do.
    let detail: String?
    /// On the desktop (and in the library's stage).
    let onStage: Bool
    let selected: Bool
    /// ⌘-click: on the desktop too, or off it.
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onShow: () -> Void
    let onRename: (String) -> Void
    let onTrash: () -> Void
    /// Space's large preview.
    let onPreview: () -> Void
    @State private var hovered = false
    @State private var draft: String?
    @FocusState private var editing: Bool
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        VStack(spacing: 5) {
            stage
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
                // One tap gesture for both: a second gesture for double-clicks would delay or swallow
                // the single click that selects.
                .onTapGesture {
                    onSelect()
                    if (NSApp.currentEvent?.clickCount ?? 1) >= 2 { onShow() }
                }
                .accessibilityElement()
                .accessibilityLabel(character.name)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { onShow() }
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
                name
                if let detail {
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .help(onStage ? L("%@ · ⌘-click to take off the Desktop", character.name)
                      : L("%@ · ⌘-click to also show on the Desktop", character.name))
        .contextMenu {
            // The grid's own keys, shown as the items' shortcuts; ⌘-click has no key, so it goes in the text.
            Button(L("Show on Desktop"), action: onShow)
                .keyboardShortcut(.return, modifiers: [])
            Button(onStage ? L("Take off the Desktop (⌘-Click)") : L("Also Show on Desktop (⌘-Click)"), action: onToggle)
            Button(L("Quick Look"), action: onPreview)
                .keyboardShortcut(.space, modifiers: [])
            if !character.isBuiltIn {
                Divider()
                Button(L("Rename")) {
                    draft = character.name
                    DispatchQueue.main.async { editing = true }
                }
                Button(L("Show in Finder")) {
                    if let video { NSWorkspace.shared.activateFileViewerSelecting([video]) }
                }
                Divider()
                Button(L("Move to Trash"), role: .destructive, action: onTrash)
                    .keyboardShortcut(.delete, modifiers: [])
            }
        }
    }

    private var stage: some View {
        ZStack(alignment: .bottom) {
            if selected || hovered {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(selected ? 0.09 : 0.04))
            }
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: height * 0.3))
                .frame(width: height * 0.6, height: height * 0.08)
                .padding(.bottom, height * 0.03)
            figure
                .opacity(onStage && !hovered ? 0.4 : 1)
                .padding(.horizontal, height * 0.08)
                .padding(.top, height * 0.06)
                .padding(.bottom, height * 0.06)
        }
        .animation(.easeOut(duration: 0.2), value: onStage)
    }

    /// The thumbnail, fitted and standing on the bottom; while hovered, the video in its place,
    /// scaled and shifted so the figure covers exactly the same rectangle.
    private var figure: some View {
        GeometryReader { geo in
            if let image {
                let fit = Self.fit(image.size, in: geo.size)
                Group {
                    if hovered, let video, let box, box.width > 0, box.height > 0 {
                        let full = CGSize(width: fit.width / box.width, height: fit.height / box.height)
                        LoopingVideo(url: video)
                            .frame(width: full.width, height: full.height)
                            .offset(x: -box.minX * full.width, y: -box.minY * full.height)
                            .frame(width: fit.width, height: fit.height, alignment: .topLeading)
                    } else {
                        Image(nsImage: image).resizable().interpolation(.high)
                    }
                }
                .frame(width: fit.width, height: fit.height)
                .position(x: geo.size.width / 2, y: geo.size.height - fit.height / 2)
            } else {
                FigureShape()
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: geo.size.height * 0.4, height: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private var name: some View {
        let highlighted = selected && activeState == .key
        return HStack(spacing: 5) {
            if onStage { Circle().fill(Theme.spotlight).frame(width: 6, height: 6) }
            Text(character.name)
        }
            .font(.system(size: 12))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(highlighted ? Color.accentColor : Color.primary.opacity(0.12))
                }
            }
    }

    private static func fit(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, box.width > 0, box.height > 0 else { return .zero }
        let scale = min(box.width / size.width, box.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private func commit() {
        if let draft { onRename(draft) }
        draft = nil
    }
}
