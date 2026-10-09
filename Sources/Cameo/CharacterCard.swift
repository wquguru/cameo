import AVFoundation
import SwiftUI

/// A character card. The selected one is "lit": a dark stage with spotlight beam, floor glow and
/// full-colour figure, in light and dark mode alike. Others are plain system-grey tiles.
struct CharacterCard: View {
    static let height: CGFloat = 66

    let image: NSImage?
    let lit: Bool
    var height: CGFloat = Self.height
    var cornerRadius: CGFloat = 9
    /// Unlit cards grey their figure (the popover); the library keeps every thumbnail in colour.
    var greysUnlit = true
    /// A video to loop over the card (the library plays one on hover).
    var preview: URL? = nil
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: cornerRadius).fill(lit ? Theme.stage : Color.primary.opacity(0.07))
                BeamShape()
                    .fill(LinearGradient(
                        colors: [Color(red: 1, green: 0.824, blue: 0.478).opacity(0.42), Theme.spotlight.opacity(0)],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.85)))
                    .opacity(lit ? 1 : 0)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.784, blue: 0.392).opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: height * 0.36))
                    .frame(width: height * 0.66, height: height * 0.15)
                    .padding(.bottom, 4)
                    .opacity(lit ? 1 : 0)
                if let preview {
                    LoopingVideo(url: preview)
                        .frame(height: height * 0.86)
                        .padding(.bottom, height * 0.06)
                } else {
                    figure
                        .frame(height: height * 0.76)
                        .padding(.bottom, height * 0.1)
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
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
                .saturation(lit || !greysUnlit ? 1 : 0)
                .colorMultiply(lit || !greysUnlit ? .white : dim)
        } else {
            FigureShape().fill(lit ? Theme.figure : dim).frame(width: height * 0.4)
        }
    }
}

/// A muted, looping video with transparency, for previews.
struct LoopingVideo: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.isOpaque = false
        layer.backgroundColor = .clear
        let view = NSView()
        view.layer = layer
        view.wantsLayer = true
        player.play()
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        (view.layer as? AVPlayerLayer)?.player?.pause()
        coordinator.looper = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }
}
