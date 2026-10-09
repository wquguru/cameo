import SwiftUI
import UniformTypeIdentifiers

/// The menu bar popover: show switch, character cards, size, launch at login, quit.
struct PopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var thumbnails: Thumbnails
    var onAdd: () -> Void
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            cards
            if model.selected?.isBuiltIn == true {
                catActions
            }
            if model.characters.count == 1 {
                Text("拖入带透明通道的 .mov（HEVC with Alpha 或 ProRes 4444）")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 2)
            }
            sizeSlider
            if let message = model.errorMessage {
                Button { model.errorMessage = nil } label: {
                    Text(message).font(.system(size: 11)).foregroundStyle(Theme.spotlight).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .help("点按关闭")
            }
            footer
        }
        .padding(14)
        .frame(width: 340)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.spotlight, lineWidth: 2).padding(4)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.add(urls) }
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: Glyph.image(size: 18, color: Theme.spotlightNS))
            Text("Cameo").font(.system(size: 15, weight: .semibold))
            Spacer()
            Toggle("显示角色", isOn: $model.visible)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.spotlight)
                .controlSize(.small)
        }
        .padding(.horizontal, 2)
    }

    private var cards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(model.characters) { character in
                CharacterCard(
                    image: thumbnails.image(for: character, url: model.url(for: character)),
                    lit: character.id == model.selectedID
                ) {
                    model.selectedID = character.id
                    model.visible = true
                }
                .help(character.name)
                .accessibilityLabel(character.name)
                .contextMenu {
                    if !character.isBuiltIn {
                        Button("删除“\(character.name)”", role: .destructive) { model.remove(character) }
                    }
                }
            }
            Button(action: onAdd) {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(height: 96)
                    .overlay(Image(systemName: "plus").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.secondary))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加角色视频")
        }
    }

    /// What the built-in cat does: on its own (自由), or one action held until changed.
    private var catActions: some View {
        HStack(spacing: 4) {
            actionChip("自由", selected: model.catAction == nil) { model.catAction = nil }
            ForEach(CatAction.allCases) { action in
                actionChip(action.label, selected: model.catAction == action) { model.catAction = action }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
    }

    private func actionChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.white.opacity(0.9))
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Theme.spotlight : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var sizeSlider: some View {
        HStack(alignment: .bottom, spacing: 10) {
            FigureShape().fill(Theme.secondary).frame(width: 10, height: 20)
            Slider(value: $model.scale, in: 0.2...2)
                .tint(Theme.spotlight)
                .controlSize(.small)
                .padding(.bottom, 2)
                .accessibilityLabel("角色大小")
                .accessibilityValue("\(Int(model.scale * 100))%")
            FigureShape().fill(Theme.secondary).frame(width: 16, height: 32)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Divider().overlay(Color.white.opacity(0.12)).padding(.bottom, 4)
            HStack {
                Text("登录时启动")
                Spacer()
                Toggle("登录时启动", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .tint(Theme.spotlight)
            }
            .frame(height: 30)
            .padding(.horizontal, 8)
            Button { NSApp.terminate(nil) } label: {
                HStack {
                    Text("退出")
                    Spacer()
                    Text("⌘Q").foregroundStyle(Theme.secondary)
                }
                .frame(height: 30)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .font(.system(size: 13))
    }
}

/// A character card. The selected one is "lit": spotlight beam, floor glow, full-colour figure.
private struct CharacterCard: View {
    let image: NSImage?
    let lit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12).fill(Theme.card)
                BeamShape()
                    .fill(LinearGradient(
                        colors: [Color(red: 1, green: 0.824, blue: 0.478).opacity(0.38), Theme.spotlight.opacity(0)],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.85)))
                    .opacity(lit ? 1 : 0)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.784, blue: 0.392).opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: 30))
                    .frame(width: 52, height: 12)
                    .padding(.bottom, 6)
                    .opacity(lit ? 1 : 0)
                figure
                    .frame(height: 76)
                    .padding(.bottom, 10)
            }
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(lit ? Theme.spotlight : Color.white.opacity(0.08), lineWidth: lit ? 1.5 : 0.5))
            .animation(.easeOut(duration: 0.25), value: lit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(lit ? .isSelected : [])
    }

    @ViewBuilder private var figure: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .saturation(lit ? 1 : 0)
                .brightness(lit ? 0 : -0.25)
                .opacity(lit ? 1 : 0.6)
        } else {
            FigureShape().fill(lit ? Theme.figure : Theme.dimFigure).frame(width: 36)
        }
    }
}
