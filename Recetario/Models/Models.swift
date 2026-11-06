import Foundation

// Foundation-only on purpose: scripts/validate compiles this file on its own
// to check recipes.json in CI.

/// The two languages the recetario is written in.
enum Lang: String, Codable, CaseIterable {
    case es, en
}

struct RecipeBook: Codable {
    let categories: [RecipeCategory]
    let recipes: [Recipe]
    let chiles: [Chile]
    let glossary: [GlossaryEntry]
    /// Ingredient names and aliases for ¿Qué tengo?
    let lexicon: [LexEntry]

    static let empty = RecipeBook(categories: [], recipes: [], chiles: [], glossary: [], lexicon: [])

    static func load(from url: URL) throws -> RecipeBook {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RecipeBook.self, from: data)
    }
}

struct RecipeCategory: Codable, Identifiable, Hashable {
    let id: String
    /// Card color for the category, as "#RRGGBB".
    let color: String
    let es: String
    let en: String

    func name(_ lang: Lang) -> String { lang == .es ? es : en }
}

struct IngredientGroup: Codable, Hashable {
    let title: String
    let items: [String]
}

struct PressureCooker: Codable, Hashable {
    let time: String
    let total: String
    let steps: [String]
    let note: String?
}

struct Variation: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let subtitle: String
    let region: String?
    let note: String?
    let ingredients: [IngredientGroup]
    let steps: [String]
    let pressureNote: String?
}

/// Everything about a recipe that is written in words, in one language.
struct RecipeText: Codable, Hashable {
    let subtitle: String
    /// La cantada: the line the lotería caller sings for this card.
    let verso: String?
    let region: String
    let servings: String
    let story: String
    let ingredients: [IngredientGroup]
    let steps: [String]
    let pressureCooker: PressureCooker?
    let pressureNote: String?
    let tips: [String]
    let variations: [Variation]
}

struct Recipe: Codable, Hashable, Identifiable {
    let id: String
    /// Lotería card number, in recetario order.
    let number: Int
    /// The article the card is called with: "El", "La", "Los", "Las".
    let article: String?
    /// The dish's name, the same in both languages.
    let name: String
    let category: String
    let time: [String: String]
    /// What the recipe needs, for ¿Qué tengo?: each entry is a set of alternatives ("pork or chicken").
    let needs: [[String]]
    let es: RecipeText
    let en: RecipeText

    /// The recipe's text in a language. Both languages have the same lines in the same order.
    func text(_ lang: Lang) -> RecipeText { lang == .es ? es : en }

    func totalTime(_ lang: Lang) -> String { time[lang.rawValue] ?? time["en"] ?? "" }

    var hasPressureCooker: Bool { en.pressureCooker != nil }
    var variations: [Variation] { en.variations }
}

struct ChileText: Codable, Hashable {
    let form: String
    let taste: String
    let uses: String
}

struct Chile: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let heat: Int
    let es: ChileText
    let en: ChileText

    func text(_ lang: Lang) -> ChileText { lang == .es ? es : en }
}

struct GlossaryEntry: Codable, Hashable, Identifiable {
    var id: String { term }
    let term: String
    let es: String
    let en: String

    func definition(_ lang: Lang) -> String { lang == .es ? es : en }
}

extension String {
    /// Lowercased with accents removed, so "yucatan" finds "Yucatán".
    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}

extension Recipe {
    /// "El Pozole Rojo", the way the card is called out in la lotería.
    var cardName: String {
        if let article { return "\(article) \(name)" }
        return name
    }

    /// Search finds a recipe by its words in either language.
    var searchIndex: String {
        var parts = [name]
        for t in [es, en] {
            parts += [t.subtitle, t.region]
            parts += t.ingredients.flatMap { $0.items }
            parts += t.variations.flatMap { [$0.name, $0.subtitle] }
        }
        return parts.joined(separator: " ").folded
    }

    func matches(_ query: String) -> Bool {
        let index = searchIndex
        return query.folded.split(separator: " ").allSatisfy { index.contains($0) }
    }

    /// Plain-text version for the share sheet.
    func shareText(_ lang: Lang) -> String {
        let t = text(lang)
        var lines: [String] = ["\(name) (\(t.subtitle))", t.region, ""]
        for group in t.ingredients {
            if !group.title.isEmpty { lines.append(group.title.uppercased()) }
            lines += group.items.map { "• \($0)" }
            lines.append("")
        }
        lines.append(lang == .es ? "PREPARACIÓN" : "PREPARATION")
        for (i, step) in t.steps.enumerated() {
            lines.append("\(i + 1). \(Scaler.stepText(step, factor: 1, lang: lang))")
        }
        lines.append("")
        lines.append(lang == .es ? "Del Recetario de la Abuela" : "From Recetario de la Abuela")
        return lines.joined(separator: "\n")
    }
}
