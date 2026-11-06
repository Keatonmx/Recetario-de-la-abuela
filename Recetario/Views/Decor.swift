import SwiftUI
import UIKit

// The kitchen around the cards, by day: a whitewashed wall (pared de cal) with an añil
// guardapolvo painted along the bottom, and a flowered hule on the table under the deck.
// By night it is the kitchen on the night of the ofrenda: see Muertos.swift.

/// A small fixed-seed random generator, so the wall's texture comes out the same every draw.
private struct SeededRandom {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

/// Every screen's background.
struct WallBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            // The band starts a little above the tab bar and runs under it.
            let bandHeight = geo.safeAreaInsets.bottom + 24
            ZStack(alignment: .bottom) {
                Color.paper
                if scheme == .light {
                    Limewash()
                    Guardapolvo(underBar: geo.safeAreaInsets.bottom).frame(height: bandHeight)
                } else {
                    NocheDeVelas()
                    OfrendaEdge().frame(height: bandHeight)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea(.keyboard)
        .accessibilityHidden(true)
    }
}

/// Lime wash: soft, uneven patches of whiter and warmer white, and a fine grit.
struct Limewash: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(state: 0x5EED_CA1)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex6: 0xF8F1E3)))
            var patches = context
            patches.addFilter(.blur(radius: 28))
            for _ in 0..<26 {
                let w = rng.range(120, 320), h = rng.range(80, 220)
                let rect = CGRect(x: rng.range(-60, size.width), y: rng.range(-60, size.height), width: w, height: h)
                let warm = rng.next() < 0.5
                patches.fill(Path(ellipseIn: rect), with: .color(warm ? Color(hex6: 0xEBDDC3).opacity(0.55) : Color.white.opacity(0.7)))
            }
            for _ in 0..<Int(size.width * size.height / 900) {
                let d = rng.range(0.6, 1.6)
                let rect = CGRect(x: rng.range(0, size.width), y: rng.range(0, size.height), width: d, height: d)
                context.fill(Path(ellipseIn: rect), with: .color(Color(hex6: 0x8A6E4B).opacity(rng.range(0.05, 0.14))))
            }
        }
        .drawingGroup()
    }
}

/// The painted band along the bottom of the wall: a deep añil cenefa under a cempasúchil
/// stripe, showing just above the tab bar, then a pale añil wash. The glass tab bar takes
/// on the color behind it, so under the bar the wall stays light and the tab names stay
/// readable.
struct Guardapolvo: View {
    /// How much of the band the tab bar covers.
    var underBar: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.ink).frame(height: 1.5)
            Rectangle().fill(Color(hex6: 0xF2A900)).frame(height: 4)
            Rectangle().fill(Color.ink).frame(height: 1.5)
            LinearGradient(colors: [Color(hex6: 0x2348A6), Color(hex6: 0x1A3580)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color(hex6: 0x1A3580).opacity(0.55)).frame(height: 1)
            LinearGradient(colors: [Color(hex6: 0xDCE4F4), Color(hex6: 0xE9EEF8)], startPoint: .top, endPoint: .bottom)
                .frame(height: underBar)
        }
    }
}

/// The oilcloth on the table: little flowers in rosa, cempasúchil and añil with nopal leaves,
/// on cream, faint enough that the cards and headings stay the thing you read.
struct Hule: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .light {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex6: 0xFFFBF2).opacity(0.75))
                .overlay(
                    Canvas { context, size in
                        let step: CGFloat = 58
                        let petals: [Color] = [Color(hex6: 0xE4007C), Color(hex6: 0xF29F05), Color(hex6: 0x2348A6)]
                        var row = 0
                        var y: CGFloat = step / 2
                        while y < size.height + step {
                            var x: CGFloat = row.isMultiple(of: 2) ? step / 2 : step
                            var col = 0
                            while x < size.width + step {
                                flower(at: CGPoint(x: x, y: y), color: petals[(row + col) % petals.count], in: &context)
                                x += step
                                col += 1
                            }
                            y += step * 0.88
                            row += 1
                        }
                    }
                    .opacity(0.17)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                )
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline, lineWidth: 1.5))
                .accessibilityHidden(true)
        } else {
            MantelDeOfrenda()
        }
    }

    private func flower(at c: CGPoint, color: Color, in context: inout GraphicsContext) {
        // Two nopal-green leaves, then five petals and a yellow heart.
        for angle in [CGFloat.pi * 0.2, CGFloat.pi * 1.2] {
            var leaf = context
            leaf.translateBy(x: c.x, y: c.y)
            leaf.rotate(by: .radians(angle))
            leaf.fill(Path(ellipseIn: CGRect(x: 6, y: -3.5, width: 15, height: 7)), with: .color(Color(hex6: 0x276B42)))
        }
        for i in 0..<5 {
            var petal = context
            petal.translateBy(x: c.x, y: c.y)
            petal.rotate(by: .radians(Double(i) * 2 * .pi / 5))
            petal.fill(Path(ellipseIn: CGRect(x: -4.5, y: -13, width: 9, height: 11)), with: .color(color))
        }
        context.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(Color(hex6: 0xF2C230)))
    }
}

extension RecipeStore {
    /// Big category headings (rótulos). By day, bright colors (Desayunos' cempasúchil gold,
    /// Masa's maíz, Panadería's pink) are deepened only enough for large text (3:1 on the
    /// wall) so they stay golden instead of going brown. At night they follow `headingColor`.
    func rotuloColor(forCategory id: String) -> Color {
        let hex = book.categories.first { $0.id == id }?.color ?? "#C8261E"
        let night = headingColor(forCategory: id)
        return Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark { return UIColor(night).resolvedColor(with: traits) }
            let base = UIColor(hexString: hex)
            return base.mixed(with: UIColor(hex: 0x2A1608), amount: base.relativeLuminance > 0.3 ? 0.34 : 0.24)
        })
    }
}

extension Color {
    /// A fixed color from 0xRRGGBB, the same in light and dark.
    init(hex6: UInt32) {
        self.init(uiColor: UIColor(hex: hex6))
    }

    /// A chip painted in a category's color. Off: a pastel of it (a deep shade at night);
    /// on: the color itself.
    static func chipFill(_ hexString: String, isOn: Bool) -> Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor(hexString: hexString)
            let dark = traits.userInterfaceStyle == .dark
            if isOn { return dark ? base.mixed(with: .white, amount: 0.12) : base }
            return dark ? base.mixed(with: UIColor(hex: 0x140F21), amount: 0.68) : base.mixed(with: .white, amount: 0.74)
        })
    }

    /// Text on a painted chip: comal ink on light paint, cream on dark.
    static func chipText(_ hexString: String, isOn: Bool) -> Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor(hexString: hexString)
            let dark = traits.userInterfaceStyle == .dark
            let fill: UIColor = isOn
                ? (dark ? base.mixed(with: .white, amount: 0.12) : base)
                : (dark ? base.mixed(with: UIColor(hex: 0x140F21), amount: 0.68) : base.mixed(with: .white, amount: 0.74))
            return fill.relativeLuminance > 0.33 ? UIColor(hex: 0x1D1A17) : UIColor(hex: 0xFFFAF1)
        })
    }
}
