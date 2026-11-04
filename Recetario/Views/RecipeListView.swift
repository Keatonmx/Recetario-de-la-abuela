import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject private var store: RecipeStore
    let savedOnly: Bool

    @State private var query = ""
    @State private var category: String? = nil
    @State private var pressureOnly = false

    private var results: [Recipe] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return store.book.recipes.filter { recipe in
            if savedOnly && !store.isFavorite(recipe.id) { return false }
            if let category, recipe.category != category { return false }
            if pressureOnly && recipe.pressureCooker == nil { return false }
            if !trimmed.isEmpty && !recipe.matches(trimmed) { return false }
            return true
        }
    }

    var body: some View {
        let recipes = results
        List {
            if !savedOnly {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
            }
            chips
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            if savedOnly && store.favorites.isEmpty {
                ContentUnavailableView(
                    "Nothing saved yet",
                    systemImage: "star",
                    description: Text("Open any recipe and tap the star to save it here.")
                )
                .listRowBackground(Color.clear)
            } else if recipes.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.book.categories) { cat in
                    let inCategory = recipes.filter { $0.category == cat.id }
                    if !inCategory.isEmpty {
                        Section {
                            ForEach(inCategory) { recipe in
                                NavigationLink(value: recipe) {
                                    RecipeRow(recipe: recipe)
                                }
                            }
                        } header: {
                            Text(cat.name)
                                .font(.display(.title3))
                                .foregroundStyle(Color.primary)
                                .textCase(nil)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar: pozole, guajillo, Yucatán…"
        )
        .navigationTitle(savedOnly ? "Guardadas" : "Recetas")
        .navigationBarTitleDisplayMode(savedOnly ? .large : .inline)
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PapelPicado()
            VStack(alignment: .leading, spacing: 0) {
                Text("Recetario")
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("de la ")
                    Text("Abuela").foregroundStyle(Color.chile)
                }
            }
            .font(.system(.largeTitle, design: .serif))
            .padding(.top, 6)
            Text("\(store.book.recipes.count) home-style recipes, region by region. \(store.pressureCookerCount) with a pressure-cooker version, plus \(store.variationCount) variations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Olla exprés", isOn: pressureOnly, onColor: .nopal) { pressureOnly.toggle() }
                Chip(title: "Todas", isOn: category == nil) { category = nil }
                ForEach(store.book.categories) { cat in
                    Chip(title: cat.name, isOn: category == cat.id) { category = cat.id }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

struct RecipeRow: View {
    @EnvironmentObject private var store: RecipeStore
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.name).font(.display(.title3))
                Spacer(minLength: 8)
                if store.isFavorite(recipe.id) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.maiz)
                        .accessibilityLabel("Saved")
                }
            }
            Text(recipe.en)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                Badge(text: recipe.region)
                Badge(text: recipe.time)
                if let pc = recipe.pressureCooker {
                    Badge(text: "Olla exprés · \(pc.total)", tint: .nopal, background: .nopalSoft, bold: true)
                }
                if !recipe.variations.isEmpty {
                    let n = recipe.variations.count
                    Badge(text: "+\(n) \(n == 1 ? "variante" : "variantes")", tint: .talavera, background: .talaveraSoft, bold: true)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}
