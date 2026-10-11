import SwiftUI

/// The top of the library: who is on the desktop, side by side under equal spotlights, in the
/// order they came on. It only shows; the grid below decides (click: only her, ⌘-click: her too).
/// Hovering one offers × to take her off; it shakes when a ⌘-click finds the desktop full.
struct LibraryStage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var thumbnails: Thumbnails
    /// Bumped to shake the stage.
    let shake: Int
    @State private var hovered: UUID?
    @State private var shaking = false

    static let height: CGFloat = 168

    private var onStage: [Character] {
        model.stage.compactMap { id in model.characters.first { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()
            LinearGradient(colors: [Theme.figure.opacity(0), Theme.figure.opacity(0.16), Theme.figure.opacity(0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(maxWidth: 760)
                .frame(height: 1)
                .padding(.bottom, 26)
            HStack(spacing: 24) {
                ForEach(onStage) { character in spot(character) }
            }
            .offset(x: shaking ? -8 : 0)
        }
        .frame(height: Self.height)
        .animation(.spring(duration: 0.35), value: model.stage)
        .onChange(of: shake) { _, _ in
            withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shaking = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shaking = false }
            }
        }
    }

    private func spot(_ character: Character) -> some View {
        let lit = model.visible
        return ZStack(alignment: .bottom) {
            Beam(strength: lit ? 0.42 : 0)
            figure(character)
                .opacity(lit ? 1 : 0.35)
                .padding(.bottom, 28)
            Text(character.name)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.82))
                .lineLimit(1)
                .padding(.bottom, 5)
            if hovered == character.id, model.stage.count > 1 {
                Button { model.removeFromStage(character.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.figure)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .help(L("Take %@ off the Desktop", character.name))
                .accessibilityLabel(L("Take %@ off the Desktop", character.name))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 22)
                .transition(.opacity)
            }
        }
        .frame(width: 180, height: Self.height)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hovered = character.id } else if hovered == character.id { hovered = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(character.name)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    @ViewBuilder private func figure(_ character: Character) -> some View {
        if let image = thumbnails.image(for: character, url: model.url(for: character)) {
            Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 104, alignment: .bottom)
        } else {
            FigureShape().fill(Theme.figure.opacity(0.8)).frame(width: 42, height: 104)
        }
    }
}

/// The stage behind the figures: a faint night sky of fixed dots fading into a warmer floor.
private struct Backdrop: View {
    /// Same sky every time: x, y in 0…1, radius in points, brightness.
    private static let stars: [(CGFloat, CGFloat, CGFloat, Double)] = {
        var seed: UInt64 = 0x2545F4914F6CDD1D
        func next() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(seed % 10_000) / 10_000
        }
        return (0..<90).map { _ in
            let y = pow(next(), 1.6) * 0.78          // thicker towards the top
            return (CGFloat(next()), CGFloat(y), CGFloat(0.4 + next() * 0.8), 0.12 + next() * 0.4)
        }
    }()

    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: Color(red: 0.10, green: 0.10, blue: 0.13), location: 0),
                                   .init(color: Theme.stage, location: 0.62),
                                   .init(color: Color(red: 0.13, green: 0.11, blue: 0.09), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                for (x, y, r, a) in Self.stars {
                    let rect = CGRect(x: x * size.width - r, y: y * size.height - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.figure.opacity(a)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A spotlight from above with its pool of light on the floor.
private struct Beam: View {
    let strength: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            BeamShape()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.824, blue: 0.478).opacity(strength), Theme.spotlight.opacity(0)],
                                     startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.92)))
                .frame(width: 160)
                .padding(.bottom, 26)
            Ellipse()
                .fill(RadialGradient(colors: [Theme.spotlight.opacity(strength == 0 ? 0 : strength + 0.1), .clear],
                                     center: .center, startRadius: 0, endRadius: 70))
                .frame(width: 140, height: 14)
                .padding(.bottom, 18)
        }
    }
}
