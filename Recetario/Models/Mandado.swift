import Foundation

/// El mandado: the shopping list. Each item points at one ingredient line of a recipe (or of
/// one of its variations), so it shows in whichever language the cook has on, scaled the way
/// the recipe was when it was added.
struct MandadoItem: Codable, Hashable, Identifiable {
    let recipeID: String
    /// nil for the recipe itself, or the variation's index.
    let variation: Int?
    let group: Int
    let item: Int
    let factor: Double
    var bought: Bool = false

    var id: String { Self.key(recipeID, variation, group, item) }

    static func key(_ recipeID: String, _ variation: Int?, _ group: Int, _ item: Int) -> String {
        "\(recipeID):\(variation.map(String.init) ?? "-"):\(group):\(item)"
    }

    /// The ingredient groups this item's line comes from, in a language.
    func groups(in recipe: Recipe, _ lang: Lang) -> [IngredientGroup] {
        let t = recipe.text(lang)
        guard let v = variation else { return t.ingredients }
        return t.variations.indices.contains(v) ? t.variations[v].ingredients : []
    }

    func line(in recipe: Recipe, _ lang: Lang) -> String? {
        let g = groups(in: recipe, lang)
        guard g.indices.contains(group), g[group].items.indices.contains(item) else { return nil }
        return g[group].items[item]
    }
}

/// The aisles of a Mexican market, in the order you walk them.
enum Aisle: String, CaseIterable, Identifiable {
    case carniceria, pescaderia, verduras, chiles, lacteos, tortilleria, abarrotes
    var id: String { rawValue }

    func name(_ lang: Lang) -> String {
        switch self {
        case .carniceria: return lang == .es ? "Carnicería" : "Butcher"
        case .pescaderia: return lang == .es ? "Pescadería" : "Seafood"
        case .verduras: return lang == .es ? "Frutas y verduras" : "Produce"
        case .chiles: return lang == .es ? "Chiles secos y especias" : "Dried chiles and spices"
        case .lacteos: return lang == .es ? "Lácteos y huevo" : "Dairy and eggs"
        case .tortilleria: return lang == .es ? "Tortillería y panadería" : "Tortillas and bread"
        case .abarrotes: return lang == .es ? "Abarrotes" : "Pantry"
        }
    }

    /// Where each ¿Qué tengo? ingredient is bought. Anything not listed (and its children, by
    /// parent) is abarrotes.
    private static let byIngredient: [String: Aisle] = {
        var map: [String: Aisle] = [:]
        let lists: [(Aisle, [String])] = [
            (.carniceria, ["puerco", "pollo", "guajolote", "res", "chivo", "panza", "machaca", "chorizo", "jamon", "tocino", "chicharron"]),
            (.pescaderia, ["camaron", "camaron-seco", "pescado", "pulpo", "jaiba", "almejas", "ostiones"]),
            (.verduras, ["pepino", "jitomate", "tomatillo", "cebolla", "ajo", "papa", "zanahoria", "calabacita", "chayote", "repollo",
                         "lechuga", "rabano", "aguacate", "limon", "naranja", "platano", "nopales", "verdolagas", "ejotes", "chicharos",
                         "apio", "xoconostle", "fruta", "elote", "chile-fresco", "cilantro", "epazote", "hierbabuena", "perejil",
                         "hoja-santa", "jengibre"]),
            (.chiles, ["chile-seco", "chile", "oregano", "comino", "canela", "clavo", "laurel", "pimienta-gorda", "anis", "tomillo",
                       "mejorana", "coriandro", "hoja-aguacate", "achiote", "vainilla", "azahar", "cascara", "jamaica", "pimienta"]),
            (.lacteos, ["huevo", "queso", "crema", "leche", "mantequilla"]),
            (.tortilleria, ["tortillas", "tortilla-harina", "masa", "pan", "hojas-maiz", "hoja-platano"])
        ]
        for (aisle, ids) in lists { for id in ids { map[id] = aisle } }
        return map
    }()

    /// The aisle for an ingredient line, from the first real ingredient named in it
    /// (salt, water and the like only count when nothing else is named).
    static func of(_ englishLine: String, pantry: PantrySearch) -> Aisle {
        let ids = pantry.ids(in: englishLine)
        let real = ids.filter { pantry.entries[$0]?.kind != "basic" }
        guard let id = (real.isEmpty ? ids : real).first else { return .abarrotes }
        for candidate in [id] + pantry.ancestors(id) {
            if let aisle = byIngredient[candidate] { return aisle }
        }
        return .abarrotes
    }
}
