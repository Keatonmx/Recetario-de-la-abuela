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
