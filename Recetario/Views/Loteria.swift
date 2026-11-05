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
            .background(color)
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
        recipe.time
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
            .frame(height: 12)
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
            Text(title)
                .font(.rotulo(32, relativeTo: .title))
                .foregroundStyle(color)
                .shadow(color: Color.inkShadow, radius: 0, x: 2, y: 2)
            TileStrip()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Seasonal papel picado

enum Season {
    /// Papel picado colors for the time of year, or nil for the everyday mix.
    static var picadoColors: [Color]? {
        let c = Calendar.current.dateComponents([.month, .day], from: Date())
        let md = (c.month ?? 1) * 100 + (c.day ?? 1)
        if (1020...1105).contains(md) { return [Color(hexString: "#7B3FA0"), Color(hexString: "#F29F05"), Color(hexString: "#E4007C")] }  // Día de Muertos
        if (901...930).contains(md) { return [Color(hexString: "#1F6B3F"), Color(hexString: "#F7F3EA"), Color(hexString: "#C8261E")] }   // Fiestas patrias
        if md >= 1201 || md <= 106 { return [Color(hexString: "#C8261E"), Color(hexString: "#1F6B3F"), Color(hexString: "#F2C230")] }   // Posadas y Navidad
        return nil
    }
}

// MARK: - Hoy hay…

/// What's cooking today, by the calendar: jueves pozolero, Sunday barbacoa,
/// tamales on la Candelaria, pan de muerto for the ofrenda.
enum Today {
    static func pick(from recipes: [Recipe], on date: Date = Date()) -> (id: String, title: String, why: String)? {
        guard !recipes.isEmpty else { return nil }
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        let md = (c.month ?? 1) * 100 + (c.day ?? 1)
        let day = cal.startOfDay(for: date)
        let easter = easterSunday(c.year ?? 2026)
        let ashWednesday = cal.date(byAdding: .day, value: -46, to: easter) ?? easter

        if (1020...1102).contains(md) { return ("conchas", "Hoy hay pan de muerto", "Para la ofrenda del Día de Muertos") }
        if (1212...1224).contains(md) { return ("tamales-rojos", "Hoy hay tamalada", "Tamales para la Nochebuena") }
        if (125...202).contains(md) { return ("tamales-rojos", "Hoy hay tamales", "Día de la Candelaria, el 2 de febrero") }
        if (901...916).contains(md) { return ("pozole-rojo", "Hoy hay pozole", "Para el 15 de septiembre") }
        if day >= ashWednesday && day <= easter { return ("capirotada", "Hoy hay capirotada", "Es Cuaresma") }
        switch c.weekday {
        case 5: return ("pozole-rojo", "Hoy hay pozole", "Jueves pozolero, como en Guerrero")
        case 1: return ("barbacoa", "Hoy hay barbacoa", "El almuerzo del domingo")
        case 7: return ("menudo-rojo", "Hoy hay menudo", "Para levantar a los muertos")
        default:
            let index = Int(date.timeIntervalSince1970 / 86_400) % recipes.count
            let r = recipes[index]
            return (r.id, "La carta del día", r.cardName)
        }
    }

    /// Anonymous Gregorian algorithm.
    static func easterSunday(_ y: Int) -> Date {
        let a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31, day = (h + l - 7 * m + 114) % 31 + 1
        return Calendar.current.date(from: DateComponents(year: y, month: month, day: day)) ?? Date()
    }
}

struct HoyHayCard: View {
    @EnvironmentObject private var store: RecipeStore

    var body: some View {
        if let today = Today.pick(from: store.book.recipes),
           let recipe = store.book.recipes.first(where: { $0.id == today.id }) {
            NavigationLink(value: recipe) {
                HStack(spacing: 12) {
                    Image("art-\(recipe.id)")
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                        .frame(width: 64, height: 64)
                        .background(store.color(forCategory: recipe.category))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ink, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(today.title)
                            .font(.rotulo(22, relativeTo: .title3))
                            .foregroundStyle(Color.lifted(store.book.categories.first { $0.id == recipe.category }?.color ?? "#C8261E"))
                            .environment(\.colorScheme, .light)
                        Text(today.why)
                            .font(.footnote)
                            .foregroundStyle(Color.stockMuted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.stockMuted)
                }
                .padding(8)
                .padding(.trailing, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.stock))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ink, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.inkShadow).offset(x: 3, y: 3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(today.title). \(today.why)")
        }
    }
}

// MARK: - Light / dark switch

enum Appearance: String {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppearanceButton: View {
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            appearance = (scheme == .dark ? Appearance.light : Appearance.dark).rawValue
        } label: {
            Image(systemName: scheme == .dark ? "sun.max" : "moon")
        }
        .accessibilityLabel(scheme == .dark ? "Switch to light mode" : "Switch to dark mode")
    }
}

// MARK: - ¡Buen provecho!

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.rotulo(22, relativeTo: .title3))
            .foregroundStyle(Color.paper)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.primary))
            .background(Capsule().fill(Color.mxRosa).offset(x: 3, y: 3))
            .accessibilityAddTraits(.isStaticText)
    }
}
