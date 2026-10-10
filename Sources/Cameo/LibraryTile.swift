import SwiftUI

/// One character in the library (design/Library.dc.html): the figure itself, cropped to its
/// pixels and standing on the bottom edge, with no tile around it; only the one on the desktop gets
/// the lit stage. Click selects (name in an accent capsule, as in Finder), double-click shows it,
/// hovering plays it, the context menu shows, renames, reveals or trashes it.
struct LibraryTile: View {
    let character: Character
    let image: NSImage?
    let video: URL?
    /// Where the figure sits in the video frame, to crop the hover preview like the thumbnail.
    let box: CGRect?
    let height: CGFloat
    let lit: Bool
    let selected: Bool
    let onSelect: () -> Void
    let onShow: () -> Void
    let onRename: (String) -> Void
    let onTrash: () -> Void
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
            }
        }
        .help(character.name)
        .contextMenu {
            Button(L("Show on Desktop"), action: onShow)
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
            }
        }
    }

    private var stage: some View {
        ZStack(alignment: .bottom) {
            if lit {
                RoundedRectangle(cornerRadius: 14).fill(Theme.stage)
                StageLights(height: height)
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.spotlight, lineWidth: 1.5)
            } else if selected || hovered {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(selected ? 0.09 : 0.04))
            }
            if !lit {
                Ellipse()
                    .fill(RadialGradient(colors: [.black.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: height * 0.3))
                    .frame(width: height * 0.6, height: height * 0.08)
                    .padding(.bottom, height * 0.03)
            }
            figure
                .padding(.horizontal, height * 0.08)
                .padding(.top, height * (lit ? 0.1 : 0.06))
                .padding(.bottom, height * (lit ? 0.08 : 0.06))
        }
        .animation(.easeOut(duration: 0.2), value: lit)
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
                    .fill(lit ? Theme.figure : Color.primary.opacity(0.18))
                    .frame(width: geo.size.height * 0.4, height: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private var name: some View {
        let highlighted = selected && activeState == .key
        return Text(character.name)
            .font(.system(size: 12, weight: lit ? .semibold : .regular))
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
