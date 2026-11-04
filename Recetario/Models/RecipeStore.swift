import Foundation
import SwiftUI

/// Holds the bundled recipe book plus the viewer's saved recipes and checked-off
/// ingredients and steps, stored on the device in UserDefaults.
final class RecipeStore: ObservableObject {
    let book: RecipeBook
    @Published private(set) var favorites: Set<String>
    @Published private(set) var checks: Set<String>

    private let defaults: UserDefaults
    private static let favoritesKey = "favorites"
    private static let checksKey = "checks"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let url = Bundle.main.url(forResource: "recipes", withExtension: "json"),
           let book = try? RecipeBook.load(from: url) {
            self.book = book
        } else {
            assertionFailure("recipes.json is missing from the app bundle or failed to decode")
            self.book = .empty
        }
        favorites = Set(defaults.stringArray(forKey: Self.favoritesKey) ?? [])
        checks = Set(defaults.stringArray(forKey: Self.checksKey) ?? [])
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

    func resetChecks(prefix: String) {
        checks = checks.filter { !$0.hasPrefix(prefix) }
        defaults.set(Array(checks), forKey: Self.checksKey)
    }
}
