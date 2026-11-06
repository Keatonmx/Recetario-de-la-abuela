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

// MARK: - Lotería cards

/// The drawing panel, the way it looks on a lotería card: the dish on a flat colored
/// field, sitting on a darker ground band, with the card number in the corner.
struct CardArt: View {
    let recipe: Recipe
    let field: Color
    let ground: Color
    var numberSize: CGFloat = 17

    var body: some View {
        Color.clear
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .background {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        field
                        Rectangle().fill(Color.ink).frame(height: 2)
                        ground.frame(height: geo.size.height * 0.28)
                    }
                }
            }
            .overlay {
                GeometryReader { geo in
                    let side = geo.size.width * 0.96
                    Image("art-\(recipe.id)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.88 - side / 2)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topLeading) {
                Text("\(recipe.number)")
                    .font(.system(size: numberSize, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .padding(.top, 4)
                    .padding(.leading, 7)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.ink, lineWidth: 2))
    }
}

/// Small round badge on cards that have a pressure-cooker version.
struct OllaBadge: View {
    var body: some View {
        Image("olla")
            .resizable()
            .frame(width: 15, height: 15)
            .foregroundStyle(Color.stampPaper)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.stampGreen))
            .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// One recipe as a lotería card: cream stock, a thin frame line inset from the edge,
/// the drawing in its own box and the name across the bottom.
struct LoteriaCard: View {
    @EnvironmentObject private var store: RecipeStore
    let recipe: Recipe
    var isFavorite = false
    var big = false
    /// El Tablero: a small thumbnail, four across.
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            CardArt(
                recipe: recipe,
                field: store.color(forCategory: recipe.category),
                ground: store.groundColor(forCategory: recipe.category),
                numberSize: big ? 24 : (compact ? 11 : 17)
            )
            .overlay(alignment: .bottomTrailing) {
                if recipe.hasPressureCooker && !big && !compact { OllaBadge().padding(4) }
            }
            .overlay(alignment: .topTrailing) {
                if isFavorite {
                    Image("milagro-fill")
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: compact ? 13 : 22, height: compact ? 13 : 22)
                        .padding(compact ? 2 : 4)
                }
            }
            Text(recipe.cardName.uppercased())
                .font(.slab(big ? 17 : (compact ? 8.5 : 13.5)))
                .tracking(compact ? 0 : 0.5)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: big ? 46 : (compact ? 22 : 36))
        }
        .padding(.horizontal, compact ? 5 : 9)
        .padding(.top, compact ? 5 : 9)
        .padding(.bottom, compact ? 3 : 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.stock))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.ink, lineWidth: 1.5).padding(4))
        .background(
            // Shadow on the card's shape only, so scrolling the deck stays smooth.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.stock)
                .shadow(color: Color(red: 0.12, green: 0.07, blue: 0.03).opacity(0.35), radius: 9, y: 7)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let t = recipe.text(store.lang)
        var text = "\(recipe.cardName), \(t.subtitle), \(t.region)"
        if recipe.hasPressureCooker { text += store.t(", con versión en olla exprés", ", pressure-cooker version") }
        if isFavorite { text += store.t(", guardada", ", saved") }
        return text
    }
}

/// Cards sit slightly askew, as if dealt onto the table, and press down when tapped.
struct DealtCardStyle: ButtonStyle {
    let index: Int

    private var tilt: Double {
        [-0.6, 0.5, 0.3, -0.4][index % 4]
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
        // Two rows of 12-pt tiles, like a band of azulejos set into the wall.
        Image("talavera-tile")
            .resizable(resizingMode: .tile)
            .frame(height: 24)
            .overlay(alignment: .top) { Rectangle().fill(Color.ink).frame(height: 2) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.ink).frame(height: 2) }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .accessibilityHidden(true)
    }
}

struct RotuloHeader: View {
    let title: String
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
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: Date())
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
    static func pick(from recipes: [Recipe], on date: Date = Date(), lang: Lang = .es) -> (id: String, title: String, why: String)? {
        guard !recipes.isEmpty else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        let md = (c.month ?? 1) * 100 + (c.day ?? 1)
        let day = cal.startOfDay(for: date)
        let easter = easterSunday(c.year ?? 2026)
        let ashWednesday = cal.date(byAdding: .day, value: -46, to: easter) ?? easter
        let es = lang == .es

        if (1020...1102).contains(md) {
            return ("conchas", es ? "Hoy hay pan de muerto" : "Today: pan de muerto", es ? "Para la ofrenda del Día de Muertos" : "For the Day of the Dead altar")
        }
        if (1212...1224).contains(md) {
            return ("tamales-rojos", es ? "Hoy hay tamalada" : "Today: a tamalada", es ? "Tamales para la Nochebuena" : "Tamales for Christmas Eve")
        }
        if (125...202).contains(md) {
            return ("tamales-rojos", es ? "Hoy hay tamales" : "Today: tamales", es ? "Día de la Candelaria, el 2 de febrero" : "Candlemas, February 2")
        }
        if (901...916).contains(md) {
            return ("pozole-rojo", es ? "Hoy hay pozole" : "Today: pozole", es ? "Para el 15 de septiembre" : "For Independence Day, September 15")
        }
        if day >= ashWednesday && day <= easter && c.weekday == 6 {
            return ("pescado-veracruzana", es ? "Hoy hay pescado" : "Today: fish", es ? "Viernes de Cuaresma" : "A Friday in Lent")
        }
        if day >= ashWednesday && day <= easter {
            return ("capirotada", es ? "Hoy hay capirotada" : "Today: capirotada", es ? "Es Cuaresma" : "It's Lent")
        }
        switch c.weekday {
        case 5: return ("pozole-rojo", es ? "Hoy hay pozole" : "Today: pozole", es ? "Jueves pozolero, como en Guerrero" : "Pozole Thursday, as in Guerrero")
        case 1: return ("barbacoa", es ? "Hoy hay barbacoa" : "Today: barbacoa", es ? "El almuerzo del domingo" : "The Sunday late breakfast")
        case 7: return ("menudo-rojo", es ? "Hoy hay menudo" : "Today: menudo", es ? "Para levantar a los muertos" : "To raise the dead (and cure the hangover)")
        default:
            let index = Int(date.timeIntervalSince1970 / 86_400) % recipes.count
            let r = recipes[index]
            return (r.id, es ? "La carta del día" : "Card of the day", r.cardName)
        }
    }

    /// Anonymous Gregorian algorithm.
    static func easterSunday(_ y: Int) -> Date {
        let a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31, day = (h + l - 7 * m + 114) % 31 + 1
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: month, day: day)) ?? Date()
    }
}

struct HoyHayCard: View {
    @EnvironmentObject private var store: RecipeStore

    var body: some View {
        if let today = Today.pick(from: store.book.recipes, lang: store.lang),
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
                            .foregroundStyle(Color.lifted(store.book.categories.first { $0.id == recipe.category }?.color ?? "#C8261E", deepen: 0.32))
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

/// The language switch and the light/dark switch, side by side in every screen's toolbar.
struct SettingsButtons: View {
    var body: some View {
        HStack(spacing: 14) {
            LanguageButton()
            AppearanceButton()
        }
    }
}

/// Español (México) or English.
struct LanguageButton: View {
    @EnvironmentObject private var store: RecipeStore

    var body: some View {
        Menu {
            Picker(store.t("Idioma", "Language"), selection: Binding(get: { store.lang }, set: { store.setLang($0) })) {
                Text("Español (México)").tag(Lang.es)
                Text("English").tag(Lang.en)
            }
        } label: {
            Text(store.lang == .es ? "ES" : "EN")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary, lineWidth: 1.5))
        }
        .accessibilityLabel(store.t("Idioma: español", "Language: English"))
    }
}

/// Light, dark, or follow the phone.
struct AppearanceButton: View {
    @EnvironmentObject private var store: RecipeStore
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

    var body: some View {
        Menu {
            Picker(store.t("Apariencia", "Appearance"), selection: $appearance) {
                Label(store.t("Como el teléfono", "Like the phone"), systemImage: "circle.lefthalf.filled").tag(Appearance.system.rawValue)
                Label(store.t("Claro", "Light"), systemImage: "sun.max").tag(Appearance.light.rawValue)
                Label(store.t("Oscuro", "Dark"), systemImage: "moon").tag(Appearance.dark.rawValue)
            }
        } label: {
            Image(systemName: icon)
        }
        .accessibilityLabel(store.t("Apariencia", "Appearance"))
    }

    private var icon: String {
        switch Appearance(rawValue: appearance) ?? .system {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
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

// MARK: - Stable keys

/// A short, stable key for a line of text (FNV-1a), so saved checkmarks stay on the
/// right line even if an update adds or reorders ingredients and steps.
enum StableKey {
    static func of(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 36)
    }
}
