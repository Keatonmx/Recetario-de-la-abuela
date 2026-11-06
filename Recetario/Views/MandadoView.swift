import SwiftUI

/// El mandado: the shopping list, grouped by where things are bought.
struct MandadoList: View {
    @EnvironmentObject private var store: RecipeStore

    var body: some View {
        if store.mandado.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(store.t("El mandado está vacío", "The shopping list is empty"))
                } icon: {
                    Image(systemName: "cart").foregroundStyle(Color.chile)
                }
            } description: {
                Text(store.t("En cualquier receta, toca el carrito junto a un ingrediente que te falte y aparece aquí, por pasillo.",
                             "In any recipe, tap the cart next to an ingredient you're missing and it shows up here, by aisle."))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.mandadoByAisle, id: \.aisle) { aisle, items in
                    Section(aisle.name(store.lang)) {
                        ForEach(items) { item in
                            row(item)
                        }
                        .onDelete { offsets in
                            store.removeMandado(Set(offsets.map { items[$0].id }))
                        }
                    }
                }
                Section {
                    if store.mandado.contains(where: \.bought) {
                        Button(store.t("Quitar lo que ya compré", "Remove what I've bought")) {
                            withAnimation { store.clearBought() }
                        }
                    }
                    Button(store.t("Borrar todo el mandado", "Clear the whole list"), role: .destructive) {
                        withAnimation { store.clearMandado() }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func row(_ item: MandadoItem) -> some View {
        let recipe = store.book.recipes.first { $0.id == item.recipeID }
        return Button {
            withAnimation(.snappy) { store.toggleBought(item.id) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: item.bought ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.bought ? Color.nopal : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.mandadoText(item) ?? "—")
                        .strikethrough(item.bought, color: .secondary)
                        .foregroundStyle(item.bought ? Color.secondary : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let recipe {
                        Text(recipe.cardName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(item.bought ? .isSelected : [])
    }
}
