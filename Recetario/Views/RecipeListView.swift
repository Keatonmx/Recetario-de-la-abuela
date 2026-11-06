import SwiftUI

/// The recetario as a deck of lotería cards, grouped under hand-painted category signs.
struct RecipeListView: View {
    @EnvironmentObject private var store: RecipeStore
    let savedOnly: Bool

    @State private var query = ""
    @State private var category: String? = UserDefaults.standard.string(forKey: "screenshotCategory")
    @State private var pressureOnly = false
    /// Pull to refresh sets the papel picado swaying.
    @State private var swing = 0
    /// El Tablero: four small cards across instead of two.
    @AppStorage("tablero") private var tablero = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        let across = typeSize.isAccessibilitySize ? (tablero ? 2 : 1) : (tablero ? 4 : 2)
        return Array(repeating: GridItem(.flexible(), spacing: tablero ? 8 : 14, alignment: .top), count: across)
    }

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || category != nil || pressureOnly
    }

    private var results: [Recipe] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return store.book.recipes.filter { recipe in
            if savedOnly && !store.isFavorite(recipe.id) { return false }
            if let category, recipe.category != category { return false }
            if pressureOnly && !recipe.hasPressureCooker { return false }
            if !trimmed.isEmpty {
                let index = store.searchIndex[recipe.id] ?? recipe.searchIndex
                if !trimmed.folded.split(separator: " ").allSatisfy({ index.contains($0) }) { return false }
            }
            return true
        }
    }

    var body: some View {
        let recipes = results
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                chips
                if savedOnly && store.book.recipes.allSatisfy({ !store.isFavorite($0.id) }) {
                    ContentUnavailableView {
                        Label {
                            Text(store.t("Todavía no hay milagros", "No milagros yet"))
                        } icon: {
                            Image("milagro").foregroundStyle(Color.chile)
                        }
                    } description: {
                        Text(store.t("Abre cualquier receta y toca el corazón para guardarla aquí.",
                                     "Open any recipe and tap the heart to save it here."))
                    }
                    .padding(.top, 24)
                } else if recipes.isEmpty {
                    Group {
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            ContentUnavailableView(store.t("No hay recetas aquí", "No recipes here"), systemImage: "line.3.horizontal.decrease",
                                                   description: Text(store.t("Nada coincide con estos filtros. Prueba con Todas.",
                                                                             "Nothing matches these filters. Try All.")))
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                    .padding(.top, 24)
                } else {
                    if isFiltering {
                        Text(store.t("\(recipes.count) \(recipes.count == 1 ? "receta" : "recetas")",
                                     "\(recipes.count) \(recipes.count == 1 ? "recipe" : "recipes")"))
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
                    // The deck is dealt on the kitchen table's hule.
                    .padding(.vertical, 16)
                    .background(Hule().padding(.horizontal, -8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(WallBackground())
        .refreshable {
            if !reduceMotion { swing += 1 }
            try? await Task.sleep(for: .milliseconds(600))
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(store.t("Buscar: pozole, guajillo, Yucatán…", "Search: pozole, guajillo, Yucatán…"))
        )
        .navigationTitle(savedOnly ? store.t("Guardadas", "Saved") : store.t("Recetas", "Recipes"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.snappy) { tablero.toggle() }
                } label: {
                    Image(systemName: tablero ? "square.grid.2x2" : "square.grid.3x3")
                }
                .accessibilityLabel(tablero
                    ? store.t("Ver cartas grandes", "Show big cards")
                    : store.t("El Tablero: ver todas las cartas chiquitas", "El Tablero: show small cards"))
            }
            ToolbarItem(placement: .topBarTrailing) { SettingsButtons() }
        }
    }

    private func section(_ cat: RecipeCategory, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: tablero ? 10 : 16) {
            RotuloHeader(title: cat.name(store.lang), color: store.headingColor(forCategory: cat.id))
            LazyVGrid(columns: columns, alignment: .leading, spacing: tablero ? 10 : 18) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    // Tapping a card picks it up and turns it over.
                    Button {
                        store.tableCard = recipe
                    } label: {
                        LoteriaCard(recipe: recipe, isFavorite: store.isFavorite(recipe.id), compact: tablero)
                    }
                    .buttonStyle(DealtCardStyle(index: index))
                    .accessibilityHint(store.t("Voltea la carta", "Turns the card over"))
                }
            }
        }
    }

    /// ¡Buenas! draws from what's on screen: the filtered cards, or the whole deck.
    private func shuffle() {
        let deck = results
        store.shuffleDeck = deck.count >= 2 ? deck : store.book.recipes
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            PapelPicado(swing: swing)
                .padding(.top, 4)
            if savedOnly {
                Text(store.t("Guardadas", "Saved"))
                    .font(.rotulo(44))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Color.mxRosa)
                    .shadow(color: Color.inkShadow, radius: 0, x: 3, y: 3)
                    .padding(.top, 10)
                Text(store.t("Tus milagros: las recetas que guardaste con el corazón, en este teléfono.",
                             "Your milagros: the recipes you've saved with the heart, kept on this phone."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if store.favorites.count >= 2 {
                    BuenasButton(action: shuffle)
                        .padding(.top, 6)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recetario")
                        .font(.rotulo(50))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.mxRosa)
                    Text("de la Abuela")
                        .font(.rotulo(31, relativeTo: .title))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.mxVerde)
                }
                .shadow(color: Color.inkShadow, radius: 0, x: 3, y: 3)
                .padding(.top, 10)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text(store.t("COCINA DE CASA · REGIÓN POR REGIÓN", "HOME COOKING · REGION BY REGION"))
                    .font(.slab(13, relativeTo: .caption))
                    .tracking(1.1)
                    .foregroundStyle(Color.chile)
                HoyHayCard()
                    .padding(.top, 6)
                BuenasButton(action: shuffle)
                    .padding(.top, 4)
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: store.t("Olla exprés", "Pressure cooker"), isOn: pressureOnly, paint: "#1F6B3F") { pressureOnly.toggle() }
                Chip(title: store.t("Todas", "All"), isOn: category == nil, paint: "#C70067") { category = nil }
                ForEach(store.book.categories) { cat in
                    Chip(title: cat.name(store.lang), isOn: category == cat.id, paint: cat.color) { category = cat.id }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}
