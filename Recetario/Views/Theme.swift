import SwiftUI
import UIKit

// Palette: masa cream by day, comal black by night, with rosa mexicano, chile,
// cempasúchil and nopal as accents. Each color has a light and a dark value.
// ("talavera" is the UI accent token; it is now rosa, not blue.)
extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static let talavera = Color(light: 0xB4005C, dark: 0xFF7DBE)
    static let talaveraSoft = Color(light: 0xF9E1EC, dark: 0x3B1A2B)
    static let chile = Color(light: 0xA8261B, dark: 0xF28A6E)
    static let chileSoft = Color(light: 0xF6E0D9, dark: 0x3A211B)
    static let maiz = Color(light: 0xB87A0E, dark: 0xF2C35C)
    static let maizSoft = Color(light: 0xF7E9C8, dark: 0x342816)
    static let nopal = Color(light: 0x276B42, dark: 0x7CC690)
    static let nopalSoft = Color(light: 0xE0EDDC, dark: 0x1B2E20)
    static let rosa = Color(light: 0xC4336B, dark: 0xEE80A9)
    static let paper = Color(light: 0xF5EDDF, dark: 0x15110E)
    static let card = Color(light: 0xFFFAF1, dark: 0x211B16)
    static let hairline = Color(light: 0xE2D5C1, dark: 0x3A3027)

    // Lotería cards are physical objects: light card stock and black ink in both themes.
    static let stock = Color(light: 0xFFFDF7, dark: 0xF5EDDF)
    static let ink = Color(light: 0x1D1A17, dark: 0x120F0C)
    static let inkShadow = Color(light: 0x1E1813, dark: 0x000000)
    static let stockMuted = Color(light: 0x5E5A55, dark: 0x5E5A55)
    static let stampGreen = Color(light: 0x1F6B3F, dark: 0x1F6B3F)
    static let stampPaper = Color(light: 0xF7F5EE, dark: 0xF7F5EE)
    static let mxRosa = Color(light: 0xD6006F, dark: 0xFF5FAE)
    static let mxVerde = Color(light: 0x1F6B3F, dark: 0x7CC690)

    /// A category color from "#RRGGBB".
    init(hexString: String) {
        self.init(uiColor: UIColor(hexString: hexString))
    }

    /// A category color for text on the page: deepened a little on cream, lifted
    /// toward white on black, so it stays readable in both.
    static func lifted(_ hexString: String) -> Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor(hexString: hexString)
            return traits.userInterfaceStyle == .dark
                ? base.mixed(with: .white, amount: 0.38)
                : base.mixed(with: UIColor(hex: 0x2A1608), amount: 0.24)
        })
    }

    /// The flat field behind a card's drawing: the category color, softened.
    static func cardField(_ hexString: String) -> Color {
        Color(uiColor: UIColor(hexString: hexString).mixed(with: .white, amount: 0.22))
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let digits = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        self.init(hex: UInt32(digits, radix: 16) ?? 0xC8261E)
    }

    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1
        )
    }
}

extension RecipeStore {
    func color(forCategory id: String) -> Color {
        Color.cardField(book.categories.first { $0.id == id }?.color ?? "#C8261E")
    }

    func headingColor(forCategory id: String) -> Color {
        Color.lifted(book.categories.first { $0.id == id }?.color ?? "#C8261E")
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// Serif display face for recipe names and section titles.
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif)
    }
}
