import SwiftUI

/// The recetario as a deck of lotería cards, grouped under hand-painted category signs.
struct RecipeListView: View {
    @EnvironmentObject private var store: RecipeStore
    let savedOnly: Bool

    @State private var query = ""
    @State private var category: String? = UserDefaults.standard.string(forKey: "screenshotCategory")
    @State private var pressureOnly = false

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || category != nil || pressureOnly
    }

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                chips
                if savedOnly && store.favorites.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No milagros yet")
                        } icon: {
                            Image("milagro").foregroundStyle(Color.chile)
                        }
                    } description: {
                        Text("Open any recipe and tap the heart to save it here.")
                    }
                    .padding(.top, 24)
                } else if recipes.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 24)
                } else {
                    if isFiltering {
                        Text("\(recipes.count) \(recipes.count == 1 ? "receta" : "recetas")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    LazyVStack(alignment: .leading, spacing: 34) {
                        ForEach(store.book.categories) { cat in
                            let inCategory = recipes.filter { $0.category == cat.id }
                            if !inCategory.isEmpty {
                                section(cat, recipes: inCategory)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color.paper)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar: pozole, guajillo, Yucatán…"
        )
        .navigationTitle(savedOnly ? "Guardadas" : "Recetas")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { AppearanceButton() }
        }
    }

    private func section(_ cat: RecipeCategory, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            RotuloHeader(title: cat.name, count: recipes.count, color: store.headingColor(forCategory: cat.id))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    NavigationLink(value: recipe) {
                        LoteriaCard(recipe: recipe, isFavorite: store.isFavorite(recipe.id))
                    }
                    .buttonStyle(DealtCardStyle(index: index))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            PapelPicado()
                .padding(.top, 4)
            if savedOnly {
                Text("Guardadas")
                    .font(.rotulo(44))
                    .foregroundStyle(Color.mxRosa)
                    .shadow(color: Color.inkShadow, radius: 0, x: 3, y: 3)
                    .padding(.top, 10)
                Text("Your milagros: the recipes you've saved with the heart, kept on this phone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recetario")
                        .font(.rotulo(50))
                        .foregroundStyle(Color.mxRosa)
                    Text("de la Abuela")
                        .font(.rotulo(31, relativeTo: .title))
                        .foregroundStyle(Color.mxVerde)
                }
                .shadow(color: Color.inkShadow, radius: 0, x: 3, y: 3)
                .padding(.top, 10)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text("COCINA DE CASA · REGIÓN POR REGIÓN")
                    .font(.slab(13, relativeTo: .caption))
                    .tracking(1.1)
                    .foregroundStyle(Color.chile)
                HoyHayCard()
                    .padding(.top, 6)
            }
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
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}
