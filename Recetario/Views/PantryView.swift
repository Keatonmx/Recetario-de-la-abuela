import SwiftUI

struct PantryView: View {
    @EnvironmentObject private var store: RecipeStore

    private var howTo: [String] {
        store.lang == .es ? [
            "Compra chiles que se doblen sin romperse y que brillen un poco. Los quebradizos y empolvados son viejos.",
            "Límpialos con un trapo húmedo. Quítales el rabito, ábrelos y sacúdeles las semillas y las venas.",
            "Tuéstalos en un comal a fuego medio-alto 10–20 segundos por lado, aplanándolos, hasta que huelan rico y se ampollen un poco. Si echan humo, van a amargar.",
            "Remójalos en agua caliente (no hirviendo) 15–20 minutos, hasta que estén suaves.",
            "Muélelos con un poco de agua limpia o caldo en vez del agua del remojo si ésta sabe amarga.",
            "Cuélalos por un colador fino. Es el paso que casi todos se saltan, y el que la abuela nunca se salta."
        ] : [
            "Buy chiles that bend without cracking and look a little shiny. Brittle, dusty ones are old.",
            "Wipe them with a damp towel. Pull off the stems, slit them open and shake out the seeds and veins.",
            "Toast on a medium-hot comal 10–20 seconds per side, pressing flat, until they smell good and blister a little. If they smoke, they'll be bitter.",
            "Soak in hot (not boiling) water 15–20 minutes, until soft.",
            "Blend with a little fresh water or broth instead of the soaking water if it tastes bitter.",
            "Strain through a fine sieve. This is the step most people skip, and the one grandma never does."
        ]
    }

    static let chileColors: [String: Color] = [
        "Guajillo": Color(hexString: "#9E1B1B"), "Ancho": Color(hexString: "#5A2016"),
        "Pasilla": Color(hexString: "#3A231B"), "Mulato": Color(hexString: "#4A2A1F"),
        "Chipotle": Color(hexString: "#7A3A22"), "De árbol": Color(hexString: "#D7262E"),
        "Piquín · Chiltepín": Color(hexString: "#C21E2E"), "Poblano": Color(hexString: "#2E6B3A"),
        "Serrano": Color(hexString: "#3FA34D"), "Habanero": Color(hexString: "#F29F05")
    ]

    // Book titles stay as published.
    private let reading = [
        "Diana Kennedy, The Essential Cuisines of Mexico",
        "Diana Kennedy, Oaxaca al Gusto",
        "Patricia Quintana, The Taste of Mexico",
        "Alicia Gironella De'Angeli et al., Larousse de la Cocina Mexicana"
    ]

    enum Page: Hashable { case mandado, guide }
    // CI screenshots open the guide with -screenshotTab 3; the list starts empty there anyway.
    @State private var page: Page = .mandado

    var body: some View {
        VStack(spacing: 0) {
            Picker(store.t("Despensa", "Pantry"), selection: $page) {
                Text(store.t("Mandado", "Shopping list")).tag(Page.mandado)
                Text(store.t("Guía de chiles", "Chile guide")).tag(Page.guide)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            switch page {
            case .mandado: MandadoList()
            case .guide: guide
            }
        }
        .background(WallBackground())
        .navigationTitle(store.t("Despensa", "Pantry"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { SettingsButtons() }
            ToolbarItem(placement: .principal) {
                Text(store.t("Despensa", "Pantry")).font(.rotulo(22, relativeTo: .headline)).foregroundStyle(Color.mxRosa)
            }
            if page == .mandado && !store.mandado.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: store.mandadoShareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(store.t("Compartir el mandado", "Share the shopping list"))
                }
            }
        }
        .onAppear {
            if store.mandado.isEmpty && UserDefaults.standard.object(forKey: "screenshotTab") != nil { page = .guide }
        }
    }

    private var guide: some View {
        List {
            Section(store.t("Los chiles", "The chiles")) {
                ForEach(store.book.chiles) { chile in
                    let t = chile.text(store.lang)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Image("chile")
                                .foregroundStyle(Self.chileColors[chile.name] ?? Color.chile)
                                .accessibilityHidden(true)
                            Text(chile.name).font(.fonda(17, relativeTo: .headline))
                            Spacer()
                            HeatMeter(level: chile.heat)
                        }
                        Text(t.form)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(t.taste)
                            .font(.subheadline.weight(.semibold))
                        Text(t.uses)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section(store.t("Cómo preparar chiles secos", "How to prepare dried chiles")) {
                ForEach(Array(howTo.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Color.talavera)
                        Text(step)
                    }
                }
            }

            Section(store.t("Ingredientes de la abuela", "Grandma's ingredients")) {
                ForEach(store.book.glossary) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.term).font(.headline)
                        Text(entry.definition(store.lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section(store.t("Para leer más", "Further reading")) {
                ForEach(reading, id: \.self) { book in
                    Text(book).font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}
