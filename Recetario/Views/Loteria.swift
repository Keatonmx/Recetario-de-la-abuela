import SwiftUI
import UIKit
import CoreText

// MARK: - Fonts

/// Registers the bundled display faces: Shrikhand (hand-painted sign lettering)
/// and Alfa Slab One (lotería card names).
enum BundledFonts {
    static func register() {
        let names = ["Shrikhand-Regular", "AlfaSlabOne-Regular"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing font \(name).ttf in the app bundle")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Rótulo: hand-painted market-sign lettering, for big titles.
    static func rotulo(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Shrikhand-Regular", size: size, relativeTo: style)
    }

    /// Heavy slab used for lotería card names, numbers and stamps.
    static func slab(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("AlfaSlabOne-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Sunburst

/// The radiating rays behind each card's drawing, like a retablo or a lotería scene.
struct Sunburst: View {
    let color: Color
    var rays = 24

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.58)
            let radius = hypot(geo.size.width, geo.size.height)
            let step = 2 * Double.pi / Double(rays)
            ZStack {
                color
                Path { path in
                    for i in 0..<rays {
                        let a0 = Double(i) * step - step / 4
                        let a1 = a0 + step / 2
                        path.move(to: center)
                        path.addLine(to: CGPoint(x: center.x + radius * cos(a0), y: center.y + radius * sin(a0)))
                        path.addLine(to: CGPoint(x: center.x + radius * cos(a1), y: center.y + radius * sin(a1)))
                        path.closeSubpath()
                    }
                }
                .fill(Color.white.opacity(0.32))
            }
        }
    }
}

// MARK: - Card pieces

struct NumberTab: View {
    let number: Int
    var size: CGFloat = 13

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomTrailingRadius: 5)
        Text("\(number)")
            .font(.slab(size, relativeTo: .caption))
            .monospacedDigit()
            .foregroundStyle(Color.ink)
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(shape.fill(Color.stock))
            .overlay(shape.strokeBorder(Color.ink, lineWidth: 2.5))
            .accessibilityHidden(true)
    }
}

/// Small round badge on cards that have a pressure-cooker version.
struct OllaBadge: View {
    var body: some View {
        Image("olla")
            .resizable()
            .frame(width: 18, height: 18)
            .foregroundStyle(Color.stampPaper)
            .frame(width: 28, height: 28)
            .background(Circle().fill(Color.stampGreen))
            .overlay(Circle().strokeBorder(Color.ink, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// The square drawing panel: sunburst, the dish, and the card number.
struct CardArt: View {
    let recipe: Recipe
    let color: Color
    var aspect: CGFloat = 1
    var cornerRadius: CGFloat = 4
    var numberSize: CGFloat = 13
    var artPadding: CGFloat = 10

    var body: some View {
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .background(Sunburst(color: color))
            .overlay {
                Image("art-\(recipe.id)")
                    .resizable()
                    .scaledToFit()
                    .padding(artPadding)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                NumberTab(number: recipe.number, size: numberSize)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.ink, lineWidth: 2.5))
    }
}

/// One recipe as a lotería card.
struct LoteriaCard: View {
    let recipe: Recipe
    let color: Color
    let isFavorite: Bool

    private var subline: String {
        let n = recipe.variations.count
        if n == 0 { return recipe.time }
        return "\(recipe.time) · \(n) \(n == 1 ? "variante" : "variantes")"
    }

    var body: some View {
        VStack(spacing: 7) {
            CardArt(recipe: recipe, color: color)
                .overlay(alignment: .bottomTrailing) {
                    if recipe.pressureCooker != nil {
                        OllaBadge().padding(5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isFavorite {
                        Image("milagro-fill")
                            .renderingMode(.original)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(4)
                    }
                }
            Text(recipe.cardName.uppercased())
                .font(.slab(15))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(subline)
                .font(.caption2)
                .foregroundStyle(Color.stockMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.top, 7)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.stock))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.inkShadow).offset(x: 3, y: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(recipe.cardName), \(recipe.en), \(recipe.region)"
        if recipe.pressureCooker != nil { text += ", pressure-cooker version" }
        if isFavorite { text += ", saved" }
        return text
    }
}

/// Cards sit slightly askew, as if dealt onto the table, and press down when tapped.
struct DealtCardStyle: ButtonStyle {
    let index: Int

    private var tilt: Double {
        [-0.8, 0.6, 0.4, -0.5][index % 4]
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rotationEffect(.degrees(configuration.isPressed ? 0 : tilt))
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Rótulo heading with talavera tiles

struct TileStrip: View {
    var body: some View {
        Image("talavera-tile")
            .resizable(resizingMode: .tile)
            .frame(height: 18)
            .overlay(alignment: .top) { Rectangle().fill(Color.ink).frame(height: 2) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.ink).frame(height: 2) }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .accessibilityHidden(true)
    }
}

struct RotuloHeader: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.rotulo(32, relativeTo: .title))
                    .foregroundStyle(color)
                    .shadow(color: Color.inkShadow, radius: 0, x: 2, y: 2)
                Text("\(count) \(count == 1 ? "carta" : "cartas")".uppercased())
                    .font(.slab(12, relativeTo: .caption))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            TileStrip()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
