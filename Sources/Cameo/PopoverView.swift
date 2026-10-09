import SwiftUI
import UniformTypeIdentifiers

/// The menu bar popover: native menu look (system appearance, separators, menu rows) around one
/// custom part, the character cards, where the selected card is lit like a stage.
struct PopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var thumbnails: Thumbnails
    var onAdd: () -> Void
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            separator
            section("角色") {
                cards
                if model.selected?.isBuiltIn == true {
                    catActions
                }
                if model.characters.count == 1 {
                    Text("拖入带透明通道的 .mov（HEVC with Alpha 或 ProRes 4444）")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            separator
            section("大小") { sizeSlider }
            if let message = model.errorMessage {
                separator
                MenuRow(action: { model.errorMessage = nil }) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }
                .help("点按关闭")
            }
            if let update = model.update {
                separator
                MenuRow(action: { model.installUpdate() }) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.spotlight).frame(width: 6, height: 6)
                            Text("新版本 \(update.version) 可用")
                        }
                        Text(model.installingUpdate ? "正在下载并安装…" : "点击更新，完成后自动重新打开")
                            .font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 12)
                    }
                }
                .disabled(model.installingUpdate)
                .contextMenu {
                    Button("查看更新说明") { NSWorkspace.shared.open(update.url) }
                }
            }
            separator
            MenuRow(action: { model.setLaunchAtLogin(!model.launchAtLogin) }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(model.launchAtLogin ? 1 : 0)
                        .frame(width: 14)
                    Text("登录时启动")
                }
            }
            .accessibilityAddTraits(model.launchAtLogin ? .isSelected : [])
            MenuRow(action: { NSApp.terminate(nil) }) {
                HStack(spacing: 4) {
                    Color.clear.frame(width: 14, height: 1)
                    Text("退出 Cameo")
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
            Toggle("显示角色", isOn: $model.visible)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var status: String {
        guard model.visible, let name = model.selected?.name else { return "已隐藏" }
        return "显示中 · \(name)"
    }

    private var separator: some View {
        Divider().padding(.horizontal, 14).padding(.vertical, 6)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
        .padding(.horizontal, 14)
    }

    private var cards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), alignment: .leading, spacing: 8) {
            ForEach(model.characters) { character in
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
                        Button("删除“\(character.name)”", role: .destructive) { model.remove(character) }
                    }
                }
            }
            VStack(spacing: 4) {
                Button(action: onAdd) {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(height: CharacterCard.height)
                        .overlay(Image(systemName: "plus").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加角色视频")
                Text("添加").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    /// What the built-in cat does: on its own (自由), or one action held until changed.
    private var catActions: some View {
        Picker("小银的动作", selection: $model.catAction) {
            Text("自由").tag(CatAction?.none)
            ForEach(CatAction.allCases) { action in
                Text(action.label).tag(CatAction?.some(action))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
    }

    private var sizeSlider: some View {
        HStack(alignment: .bottom, spacing: 10) {
            FigureShape().fill(.secondary).frame(width: 8, height: 16)
            Slider(value: $model.scale, in: 0.2...2)
                .controlSize(.small)
                .padding(.bottom, 1)
                .accessibilityLabel("角色大小")
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

/// A character card. The selected one is "lit": a dark stage with spotlight beam, floor glow and
/// full-colour figure, in light and dark mode alike. Others are plain system-grey tiles.
private struct CharacterCard: View {
    static let height: CGFloat = 66

    let image: NSImage?
    let lit: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 9).fill(lit ? Theme.stage : Color.primary.opacity(0.07))
                BeamShape()
                    .fill(LinearGradient(
                        colors: [Color(red: 1, green: 0.824, blue: 0.478).opacity(0.42), Theme.spotlight.opacity(0)],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.85)))
                    .opacity(lit ? 1 : 0)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.784, blue: 0.392).opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: 24))
                    .frame(width: 44, height: 10)
                    .padding(.bottom, 4)
                    .opacity(lit ? 1 : 0)
                figure
                    .frame(height: 50)
                    .padding(.bottom, 7)
            }
            .frame(height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(lit ? Theme.spotlight : Color.primary.opacity(0.1), lineWidth: lit ? 1.5 : 0.5))
            .animation(.easeOut(duration: 0.25), value: lit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(lit ? .isSelected : [])
    }

    /// Unlit figures are greyed: darker on a light tile, dimmer on a dark one.
    private var dim: Color { Color(white: colorScheme == .dark ? 0.38 : 0.62) }

    @ViewBuilder private var figure: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .saturation(lit ? 1 : 0)
                .colorMultiply(lit ? .white : dim)
        } else {
            FigureShape().fill(lit ? Theme.figure : dim).frame(width: 26)
        }
    }
}
