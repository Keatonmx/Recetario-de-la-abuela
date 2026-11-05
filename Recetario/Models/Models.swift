import Foundation

// Foundation-only on purpose: scripts/validate compiles this file on its own
// to check recipes.json in CI.

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
    let name: String
    /// Card color for the category, as "#RRGGBB".
    let color: String
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
    let en: String
    let region: String?
    let note: String?
    let ingredients: [IngredientGroup]
    let steps: [String]
    let pressureNote: String?
}

struct Recipe: Codable, Hashable, Identifiable {
    let id: String
    /// Lotería card number, in recetario order.
    let number: Int
    /// The article the card is called with: "El", "La", "Los", "Las".
    let article: String?
    /// La cantada: the line the lotería caller sings for this card.
    let verso: String?
    let name: String
    let en: String
    let category: String
    let region: String
    let time: String
    let servings: String
    let story: String
    let ingredients: [IngredientGroup]
    let steps: [String]
    let pressureCooker: PressureCooker?
    let pressureNote: String?
    let tips: [String]
    /// What the recipe needs, for ¿Qué tengo?: each entry is a set of alternatives ("pork or chicken").
    let needs: [[String]]
    let variations: [Variation]
}

struct Chile: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let form: String
    let heat: Int
    let taste: String
    let uses: String
}

struct GlossaryEntry: Codable, Hashable, Identifiable {
    var id: String { term }
    let term: String
    let definition: String
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

    var searchIndex: String {
        var parts = [name, en, region]
        parts += ingredients.flatMap { $0.items }
        parts += variations.flatMap { [$0.name, $0.en] }
        return parts.joined(separator: " ").folded
    }

    func matches(_ query: String) -> Bool {
        let index = searchIndex
        return query.folded.split(separator: " ").allSatisfy { index.contains($0) }
    }

    /// Plain-text version for the share sheet.
    var shareText: String {
        var lines: [String] = ["\(name) (\(en))", region, ""]
        for group in ingredients {
            if !group.title.isEmpty { lines.append(group.title.uppercased()) }
            lines += group.items.map { "• \($0)" }
            lines.append("")
        }
        lines.append("PREPARACIÓN")
        for (i, step) in steps.enumerated() {
            lines.append("\(i + 1). \(step)")
        }
        lines.append("")
        lines.append("From Recetario de la Abuela")
        return lines.joined(separator: "\n")
    }
}
