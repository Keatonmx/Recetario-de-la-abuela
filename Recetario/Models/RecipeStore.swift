import Foundation
import SwiftUI

/// Holds the bundled recipe book plus the viewer's saved recipes and checked-off
/// ingredients and steps, stored on the device in UserDefaults.
final class RecipeStore: ObservableObject {
    let book: RecipeBook
    @Published private(set) var favorites: Set<String>
    @Published private(set) var checks: Set<String>
    /// How much each recipe is scaled by (missing means 1×, the original).
    @Published private(set) var factors: [String: Double]
    /// A short celebratory message, e.g. "¡Buen provecho!" when every step is done.
    @Published var toast: String?
    /// Show grams and liters instead of cups and pounds.
    @Published private(set) var metric: Bool
    /// ¿Qué tengo?: ingredient ids the cook has, and whether basics count as on hand.
    @Published private(set) var have: [String]
    @Published private(set) var haveBasics: Bool
    let pantry: PantrySearch
    /// Folded search text per recipe, built once.
    private(set) var searchIndex: [String: String] = [:]

    private let defaults: UserDefaults
    private static let favoritesKey = "favorites"
    private static let checksKey = "checks"
    private static let factorsKey = "servingFactors"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let url = Bundle.main.url(forResource: "recipes", withExtension: "json"),
           let book = try? RecipeBook.load(from: url) {
            self.book = book
        } else {
            assertionFailure("recipes.json is missing from the app bundle or failed to decode")
            self.book = .empty
        }
        pantry = PantrySearch(lexicon: book.lexicon)
        searchIndex = Dictionary(book.recipes.map { ($0.id, $0.searchIndex) }, uniquingKeysWith: { first, _ in first })
        favorites = Set(defaults.stringArray(forKey: Self.favoritesKey) ?? [])
        checks = Set(defaults.stringArray(forKey: Self.checksKey) ?? [])
        factors = (defaults.dictionary(forKey: Self.factorsKey) as? [String: Double]) ?? [:]
        metric = defaults.bool(forKey: "metric")
        have = defaults.stringArray(forKey: "have") ?? []
        haveBasics = defaults.object(forKey: "haveBasics") as? Bool ?? true
        if let ids = defaults.string(forKey: "screenshotHave") {
            have = ids.split(separator: ",").map(String.init)
        }

        // Launch arguments used by CI to set up screenshots, e.g. -screenshotFavorites "pozole-rojo,conchas".
        // They only exist when CI passes them; a later tap in that session would save them, which is fine for CI.
        if let ids = defaults.string(forKey: "screenshotFavorites") {
            favorites.formUnion(ids.split(separator: ",").map(String.init))
        }
        if let id = defaults.string(forKey: "screenshotRecipe") {
            let f = defaults.double(forKey: "screenshotFactor")
            if f > 0 { factors[id] = f }
        }
    }

    // MARK: Lookups

    func categoryName(_ id: String) -> String {
        book.categories.first { $0.id == id }?.name ?? ""
    }

    var pressureCookerCount: Int { book.recipes.filter { $0.pressureCooker != nil }.count }
    var variationCount: Int { book.recipes.reduce(0) { $0 + $1.variations.count } }

    // MARK: Favorites

    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        defaults.set(Array(favorites), forKey: Self.favoritesKey)
    }

    // MARK: Checklists

    func isChecked(_ key: String) -> Bool { checks.contains(key) }

    func toggleCheck(_ key: String) {
        if checks.contains(key) { checks.remove(key) } else { checks.insert(key) }
        defaults.set(Array(checks), forKey: Self.checksKey)
    }

    // MARK: Servings

    func factor(for id: String) -> Double { factors[id] ?? 1 }

    func setFactor(_ factor: Double, for id: String) {
        if abs(factor - 1) < 1e-9 { factors.removeValue(forKey: id) } else { factors[id] = factor }
        defaults.set(factors, forKey: Self.factorsKey)
    }

    /// Steps the servings up or down: by 1 for small yields, by a few for big batches (30 tamales).
    func stepServings(_ recipe: Recipe, by direction: Double) {
        guard let base = Scaler.base(recipe.servings) else { return }
        let step = base < 4 ? base / 2 : (base <= 12 ? 1 : (base / 12).rounded(.up))
        let next = min(base * 4, max(step, base * factor(for: recipe.id) + direction * step))
        setFactor(next / base, for: recipe.id)
    }

    func addHave(_ ids: [String]) {
        for id in ids where !have.contains(id) { have.append(id) }
        defaults.set(have, forKey: "have")
    }

    func toggleHave(_ id: String) {
        if have.contains(id) { have.removeAll { $0 == id } } else { have.append(id) }
        defaults.set(have, forKey: "have")
    }

    func clearHave() {
        have = []
        defaults.set(have, forKey: "have")
    }

    func setHaveBasics(_ on: Bool) {
        haveBasics = on
        defaults.set(on, forKey: "haveBasics")
    }

    func setMetric(_ on: Bool) {
        metric = on
        defaults.set(on, forKey: "metric")
    }

    /// Text as the cook should see it: metric when that's switched on.
    func shown(_ text: String) -> String { metric ? Units.metric(text) : text }

    func showToast(_ text: String) {
        toast = text
        AccessibilityNotification.Announcement(text).post()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            if self?.toast == text { self?.toast = nil }
        }
    }

    func resetChecks(prefix: String) {
        checks = checks.filter { !$0.hasPrefix(prefix) }
        defaults.set(Array(checks), forKey: Self.checksKey)
    }
}
