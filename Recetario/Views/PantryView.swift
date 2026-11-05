import SwiftUI

struct PantryView: View {
    @EnvironmentObject private var store: RecipeStore

    private let howTo = [
        "Buy chiles that bend without cracking and look a little shiny. Brittle, dusty ones are old.",
        "Wipe them with a damp towel. Pull off the stems, slit them open and shake out the seeds and veins.",
        "Toast on a medium-hot comal 10–20 seconds per side, pressing flat, until they smell good and blister a little. If they smoke, they'll be bitter.",
        "Soak in hot (not boiling) water 15–20 minutes, until soft.",
        "Blend with a little fresh water or broth instead of the soaking water if it tastes bitter.",
        "Strain through a fine sieve. This is the step most people skip, and the one abuela never does."
    ]

    static let chileColors: [String: Color] = [
        "Guajillo": Color(hexString: "#9E1B1B"), "Ancho": Color(hexString: "#5A2016"),
        "Pasilla": Color(hexString: "#3A231B"), "Mulato": Color(hexString: "#4A2A1F"),
        "Chipotle": Color(hexString: "#7A3A22"), "De árbol": Color(hexString: "#D7262E"),
        "Piquín · Chiltepín": Color(hexString: "#C21E2E"), "Poblano": Color(hexString: "#2E6B3A"),
        "Serrano": Color(hexString: "#3FA34D"), "Habanero": Color(hexString: "#F29F05")
    ]

    private let reading = [
        "Diana Kennedy, The Essential Cuisines of Mexico",
        "Diana Kennedy, Oaxaca al Gusto",
        "Patricia Quintana, The Taste of Mexico",
        "Alicia Gironella De'Angeli et al., Larousse de la Cocina Mexicana"
    ]

    var body: some View {
        List {
            Section {
                Text("The chiles and pantry staples these recipes depend on, and how to handle them.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Los chiles") {
                ForEach(store.book.chiles) { chile in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Image("chile")
                                .foregroundStyle(Self.chileColors[chile.name] ?? Color.chile)
                                .accessibilityHidden(true)
                            Text(chile.name).font(.slab(17, relativeTo: .headline))
                            Spacer()
                            HeatMeter(level: chile.heat)
                        }
                        Text(chile.form)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(chile.taste)
                            .font(.subheadline.weight(.semibold))
                        Text(chile.uses)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Cómo preparar chiles secos") {
                ForEach(Array(howTo.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Color.talavera)
                        Text(step)
                    }
                }
            }

            Section("Ingredientes de la abuela") {
                ForEach(store.book.glossary) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.term).font(.headline)
                        Text(entry.definition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Para leer más") {
                ForEach(reading, id: \.self) { book in
                    Text(book).font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle("Despensa")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Despensa").font(.rotulo(22, relativeTo: .headline)).foregroundStyle(Color.mxRosa)
            }
        }
    }
}
