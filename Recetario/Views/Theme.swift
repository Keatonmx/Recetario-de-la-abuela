import SwiftUI
import UIKit

// Palette: talavera cobalt, chile red, maíz gold, nopal green and rosa,
// each with a light and a dark value.
extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static let talavera = Color(light: 0x1D4AA0, dark: 0x8BAAF2)
    static let talaveraSoft = Color(light: 0xE4EBFA, dark: 0x1B2747)
    static let chile = Color(light: 0xAE281D, dark: 0xF2846F)
    static let chileSoft = Color(light: 0xFAE9E6, dark: 0x35201E)
    static let maiz = Color(light: 0xD4951A, dark: 0xF0C35A)
    static let maizSoft = Color(light: 0xFBF1DC, dark: 0x30281A)
    static let nopal = Color(light: 0x2A7448, dark: 0x72C597)
    static let nopalSoft = Color(light: 0xE1F1E7, dark: 0x163024)
    static let rosa = Color(light: 0xC4336B, dark: 0xEE80A9)
    static let paper = Color(light: 0xF4F6FB, dark: 0x0D1322)
    static let card = Color(light: 0xFFFFFF, dark: 0x151D31)
    static let hairline = Color(light: 0xDAE0ED, dark: 0x27324C)

    // Lotería cards are physical objects: light card stock and black ink in both themes.
    static let stock = Color(light: 0xFFFEFA, dark: 0xF3F0E8)
    static let ink = Color(light: 0x1D1A17, dark: 0x141210)
    static let inkShadow = Color(light: 0x1D1A17, dark: 0x04060D)
    static let stockMuted = Color(light: 0x5E5A55, dark: 0x5E5A55)
    static let stampGreen = Color(light: 0x1F6B3F, dark: 0x1F6B3F)
    static let stampPaper = Color(light: 0xF7F5EE, dark: 0xF7F5EE)
    static let mxRosa = Color(light: 0xD6006F, dark: 0xFF5FAE)
    static let mxCobalt = Color(light: 0x1F4FB5, dark: 0x8BAAF2)

    /// A category color from "#RRGGBB".
    init(hexString: String) {
        self.init(uiColor: UIColor(hexString: hexString))
    }

    /// A category color for text on the page: as-is in light mode, lifted toward
    /// white in dark mode so it stays readable.
    static func lifted(_ hexString: String) -> Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor(hexString: hexString)
            return traits.userInterfaceStyle == .dark ? base.mixed(with: .white, amount: 0.38) : base
        })
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
        Color(hexString: book.categories.first { $0.id == id }?.color ?? "#C8261E")
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
