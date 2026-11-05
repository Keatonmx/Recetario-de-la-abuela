import SwiftUI

/// ¿Qué tengo?: type or tap what's in the kitchen and see what you can cook.
struct QueTengoView: View {
    @EnvironmentObject private var store: RecipeStore
    @State private var text = ""
    @State private var unknown: [String] = []
    @FocusState private var focused: Bool

    private let picks: [(String, [String])] = [
        ("Carnes y huevo", ["puerco", "pollo", "res", "chivo", "chorizo", "panza", "machaca", "huevo"]),
        ("Verduras y fruta", ["jitomate", "tomatillo", "cebolla", "ajo", "papa", "zanahoria", "calabacita", "chayote", "elote", "aguacate", "limon", "naranja", "nopales", "platano"]),
        ("De la despensa", ["tortillas", "tortilla-harina", "masa", "arroz", "frijol", "fideo", "pan", "harina", "maiz-pozolero", "queso", "crema", "leche", "chocolate", "piloncillo", "cafe", "jamaica", "levadura", "hojas-maiz"]),
        ("Chiles", ["guajillo", "ancho", "pasilla", "chipotle", "arbol", "serrano", "jalapeno", "poblano", "habanero"])
    ]
    private let seasonings = ["oregano", "comino", "canela", "clavo", "laurel", "epazote", "cilantro", "hierbabuena", "achiote", "hoja-aguacate", "anis", "tomillo", "vinagre", "vainilla"]
    private let examples = ["puerco, chiles secos, maíz pozolero", "huevos, tortillas, tomate verde", "chicken, tomatoes, onion, chipotle", "harina, levadura, leche, huevo"]

    private var suggestions: [LexEntry] {
        let last = text.components(separatedBy: CharacterSet(charactersIn: ",;")).last ?? ""
        return store.pantry.suggest(last, excluding: store.have)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                inputRow
                if !suggestions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(suggestions) { entry in
                            Button { pickSuggestion(entry.id) } label: { IngredientChip(entry: entry, style: .suggestion) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                if !store.have.isEmpty { selected }
                if !unknown.isEmpty {
                    Text("I didn't recognize: \(unknown.joined(separator: ", ")).")
                        .font(.footnote)
                        .foregroundStyle(Color.chile)
                }
                Toggle(isOn: Binding(get: { store.haveBasics }, set: { store.setHaveBasics($0) })) {
                    Text("I have the basics: salt, oil, lard, sugar and broth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .tint(Color.nopal)
                results
                quickPicks
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper)
        .navigationTitle("¿Qué tengo?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AppearanceButton() } }
        .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            PapelPicado().padding(.top, 4)
            Text("¿Qué tengo?")
                .font(.rotulo(44))
                .foregroundStyle(Color.mxRosa)
                .shadow(color: Color.inkShadow, radius: 0, x: 3, y: 3)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
            Text("Write what's in your kitchen, in English or Spanish, and see what you can cook.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var inputRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image("tab-quetengo").foregroundStyle(.secondary).accessibilityHidden(true)
                    TextField("puerco, jitomate, tortillas…", text: $text)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { addText(text) }
                        .accessibilityLabel("Ingredients you have")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.card))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(focused ? Color.mxRosa : Color.hairline, lineWidth: focused ? 2 : 1))
                Button("Agregar") { addText(text) }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.mxRosa))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ink, lineWidth: 2))
                    .buttonStyle(.plain)
            }
            Text("Separate with commas. Typos are fine.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var selected: some View {
        FlowLayout(spacing: 6) {
            ForEach(store.have, id: \.self) { id in
                if let entry = store.pantry.entries[id] {
                    Button { store.toggleHave(id) } label: { IngredientChip(entry: entry, style: .selected) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(entry.en)")
                }
            }
            Button("Borrar todo") {
                store.clearHave()
                unknown = []
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.talavera)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var results: some View {
        if store.have.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("¿Qué hay en la cocina?").font(.display(.title3))
                Text("Add a few main ingredients, like a meat, a vegetable or two and what's in the pantry. Try one of these:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(examples, id: \.self) { example in
                        Button(example) { addText(example) }
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.card))
                            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1.5))
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        } else {
            let all = store.pantry.rank(store.book.recipes, have: store.have, haveBasics: store.haveBasics)
            let can = all.filter { $0.score >= 0.85 }
            let close = all.filter { $0.score < 0.85 && realMissing($0).count <= 2 }
            let more = Array(all.filter { $0.score < 0.85 && realMissing($0).count > 2 }.prefix(8))
            if all.isEmpty {
                Text("None of the recipes use those yet. Try adding a meat, a chile or something from the pantry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            resultSection("Puedes hacer", can, note: nil)
            resultSection("Te falta poquito", close, note: "One or two things from the tienda.")
            resultSection("Con más mandado", more, note: nil)
        }
    }

    @ViewBuilder
    private func resultSection(_ title: String, _ list: [PantryMatch], note: String?) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.rotulo(26, relativeTo: .title2))
                    .foregroundStyle(Color.primary)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)
                if let note {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(list) { match in
                    NavigationLink(value: match.recipe) { MatchRow(match: match) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickPicks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 8)
            ForEach(picks.indices, id: \.self) { i in
                Text(picks[i].0.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.chile)
                pickRow(picks[i].1)
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Only add these if you want them to count. Otherwise recipes aren't marked down for them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    pickRow(seasonings)
                }
                .padding(.top, 6)
            } label: {
                Text("Especias y hierbas ").font(.subheadline.weight(.bold)) + Text("(optional)").font(.subheadline).foregroundColor(.secondary)
            }
            .tint(Color.primary)
            .padding(.top, 6)
        }
    }

    private func pickRow(_ ids: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(ids, id: \.self) { id in
                if let entry = store.pantry.entries[id] {
                    Button { store.toggleHave(id); unknown = [] } label: {
                        IngredientChip(entry: entry, style: store.have.contains(id) ? .on : .off)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.have.contains(id) ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Actions

    private func realMissing(_ m: PantryMatch) -> [[String]] {
        m.missing.filter { need in
            guard let kind = need.first.flatMap({ store.pantry.entries[$0]?.kind }) else { return true }
            return kind != "season" && kind != "basic"
        }
    }

    private func addText(_ value: String) {
        let parsed = store.pantry.parse(value)
        store.addHave(parsed.ids)
        unknown = parsed.unknown
        text = ""
    }

    private func pickSuggestion(_ id: String) {
        var parts = text.components(separatedBy: ",")
        parts.removeLast()
        let earlier = parts.joined(separator: ",")
        store.addHave([id])
        if earlier.trimmingCharacters(in: .whitespaces).isEmpty {
            text = ""
            unknown = []
        } else {
            addText(earlier)
        }
        focused = true
    }
}

// MARK: - Chips and rows

struct IngredientChip: View {
    enum Style { case off, on, selected, suggestion }
    let entry: LexEntry
    let style: Style

    var body: some View {
        let showEnglish = PantrySearch.fold(entry.es) != PantrySearch.fold(entry.en)
        HStack(spacing: 6) {
            Text(entry.es).fontWeight(style == .selected ? .bold : .regular)
            if showEnglish {
                Text(entry.en.lowercased()).foregroundStyle(englishColor)
            }
            if style == .selected {
                Image(systemName: "xmark").font(.caption2.weight(.bold)).foregroundStyle(Color.stockMuted)
            }
        }
        .font(.subheadline)
        .foregroundStyle(style == .on ? Color(.systemBackground) : (style == .selected ? Color.ink : Color.primary))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(background))
        .overlay(Capsule().strokeBorder(border, style: StrokeStyle(lineWidth: style == .selected ? 2 : 1.5, dash: style == .suggestion ? [4, 3] : [])))
    }

    /// Selected chips are cream card stock in both themes, so their English stays dark.
    private var englishColor: Color {
        switch style {
        case .on: return Color(.systemBackground).opacity(0.75)
        case .selected: return .stockMuted
        default: return .secondary
        }
    }

    private var background: Color {
        switch style {
        case .on: return .primary
        case .selected: return .stock
        default: return .card
        }
    }

    private var border: Color {
        switch style {
        case .on: return .primary
        case .selected, .suggestion: return .ink
        case .off: return .hairline
        }
    }
}

struct MatchRow: View {
    @EnvironmentObject private var store: RecipeStore
    let match: PantryMatch

    var body: some View {
        let recipe = match.recipe
        let have = match.matched.count
        let need = match.matched.count + match.missing.count
        HStack(spacing: 12) {
            Image("art-\(recipe.id)")
                .resizable()
                .scaledToFit()
                .padding(5)
                .frame(width: 64, height: 76)
                .background(store.color(forCategory: recipe.category))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ink, lineWidth: 2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.cardName.uppercased())
                    .font(.slab(14))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline)
                        Capsule().fill(Color.nopal).frame(width: geo.size.width * match.score)
                    }
                }
                .frame(height: 6)
                Text("Tienes \(have) de \(need)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                if match.missing.isEmpty {
                    Text("¡Tienes todo!").font(.subheadline.weight(.bold)).foregroundStyle(Color.nopal)
                } else {
                    Text("Te falta: " + match.missing.map { $0.map(store.pantry.label).joined(separator: " o ") }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .padding(.trailing, 4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}
