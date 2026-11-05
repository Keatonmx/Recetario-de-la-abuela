import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    let recipe: Recipe

    @State private var tab: DetailTab = DetailTab(rawValue: UserDefaults.standard.string(forKey: "screenshotDetailTab") ?? "") ?? .traditional
    @State private var cookMode = false
    @State private var openVariations: Set<String> = []

    enum DetailTab: String, CaseIterable, Identifiable {
        case traditional = "Tradicional"
        case pressure = "Olla exprés"
        case variations = "Variantes"
        var id: String { rawValue }
    }

    private var tabs: [DetailTab] {
        recipe.variations.isEmpty ? [.traditional, .pressure] : DetailTab.allCases
    }

    static let pressureDisclaimer = "Times are for an electric pressure cooker at high pressure (about 10–12 psi). A stovetop olla exprés runs hotter (15 psi), so take off about 20% and start timing when the valve begins to rock."

    private var factor: Double { store.factor(for: recipe.id) }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ServingsCard(recipe: recipe)
                    .id("servings")
                Picker("Version", selection: $tab) {
                    ForEach(tabs) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .id("tabs")

                switch tab {
                case .traditional: traditional
                case .pressure: pressure
                case .variations: variations
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            // CI screenshots: -screenshotScrollTo servings|tabs
            if let target = UserDefaults.standard.string(forKey: "screenshotScrollTo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo(target, anchor: .top) }
            }
        }
        }
        .background(Color.paper)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    cookMode.toggle()
                } label: {
                    Image("olla")
                        .foregroundStyle(cookMode ? Color.talavera : Color.primary)
                }
                .accessibilityLabel(cookMode ? "Turn off cook mode" : "Cook mode: bigger text, screen stays on")

                Button {
                    store.toggleFavorite(recipe.id)
                } label: {
                    if store.isFavorite(recipe.id) {
                        Image("milagro-fill").renderingMode(.original)
                    } else {
                        Image("milagro")
                    }
                }
                .accessibilityLabel(store.isFavorite(recipe.id) ? "Remove from saved" : "Save recipe")

                ShareLink(item: recipe.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .environment(\.dynamicTypeSize, cookMode ? max(systemTypeSize, .xxLarge) : systemTypeSize)
        .onChange(of: cookMode) { _, isOn in
            UIApplication.shared.isIdleTimerDisabled = isOn
        }
        .onAppear {
            if openVariations.isEmpty, let first = recipe.variations.first {
                openVariations = [first.name]
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sensoryFeedback(.selection, trigger: store.checks)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cookMode {
                Label {
                    Text("Cook mode on: bigger text, and the screen stays awake.")
                } icon: {
                    Image("olla")
                }
                .font(.footnote)
                .foregroundStyle(Color.talavera)
            }
            CardArt(
                recipe: recipe,
                color: store.color(forCategory: recipe.category),
                aspect: 2,
                cornerRadius: 12,
                numberSize: 17,
                artPadding: 16
            )
            .frame(maxHeight: 220)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.inkShadow).offset(x: 4, y: 5))
            .padding(.bottom, 10)
            Text("\(recipe.region) · \(store.categoryName(recipe.category))".uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.chile)
            VStack(alignment: .leading, spacing: 2) {
                if let article = recipe.article {
                    Text(article.uppercased())
                        .font(.slab(13, relativeTo: .caption))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)
                }
                Text(recipe.name)
                    .font(.rotulo(38, relativeTo: .largeTitle))
                    .foregroundStyle(store.headingColor(forCategory: recipe.category))
                    .shadow(color: Color.inkShadow, radius: 0, x: 2, y: 2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text(recipe.en)
                .font(.body.italic())
                .foregroundStyle(.secondary)
            Text(recipe.story)
                .padding(.top, 4)
            MetaGrid(items: [
                ("Tiempo", recipe.time),
                ("Rinde", Scaler.yieldText(recipe.servings, factor: factor)),
                ("Olla exprés", recipe.pressureCooker?.total ?? "—")
            ])
            .padding(.top, 8)
        }
        .padding(.top, 12)
    }

    // MARK: Tabs

    private var resetButton: some View {
        Button("Uncheck all") {
            store.resetChecks(prefix: "\(recipe.id):")
        }
        .font(.subheadline.weight(.semibold))
    }

    private var traditional: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Ingredientes") { resetButton }
                IngredientList(groups: recipe.ingredients, scope: "\(recipe.id):t:i", factor: factor)
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Preparación")
                StepList(steps: recipe.steps, scope: "\(recipe.id):t:s")
                Text("Tap a step when it's done.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !recipe.tips.isEmpty {
                TipsBox(tips: recipe.tips)
            }
        }
    }

    @ViewBuilder
    private var pressure: some View {
        if let pc = recipe.pressureCooker {
            VStack(alignment: .leading, spacing: 24) {
                InfoBox(label: "Olla exprés · Instant Pot", background: .nopalSoft) {
                    Text(pc.time)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(Color.nopal)
                    Text("Total about \(pc.total). Use the ingredients from the Tradicional tab.")
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Ingredientes") { resetButton }
                    IngredientList(groups: recipe.ingredients, scope: "\(recipe.id):t:i", factor: factor)
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Preparación")
                    StepList(steps: pc.steps, scope: "\(recipe.id):p:s")
                }
                if factor > 1 {
                    NoteBox(text: "Scaling up? Pressure times stay the same, but never fill the pot past the max-fill line. Cook in two batches if it won't fit.")
                }
                if let note = pc.note {
                    NoteBox(text: note)
                }
                NoteBox(text: Self.pressureDisclaimer)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                InfoBox(label: "Olla exprés", background: .nopalSoft) {
                    Text(recipe.pressureNote ?? "No pressure-cooker version for this one.")
                }
                if recipe.variations.contains(where: { $0.pressureNote != nil }) {
                    NoteBox(text: "Some of the variations have pressure-cooker notes. Look under Variantes.")
                }
            }
        }
    }

    private var variations: some View {
        VStack(spacing: 12) {
            ForEach(Array(recipe.variations.enumerated()), id: \.element.id) { index, variation in
                VariationCard(
                    recipe: recipe,
                    variation: variation,
                    index: index,
                    factor: factor,
                    isOpen: Binding(
                        get: { openVariations.contains(variation.name) },
                        set: { isOpen in
                            if isOpen { openVariations.insert(variation.name) } else { openVariations.remove(variation.name) }
                        }
                    )
                )
            }
        }
    }
}

// MARK: - Pieces

struct MetaGrid: View {
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(item.1)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(index == 2 ? Color.nopal : Color.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .background(Color.card)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.hairline)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline))
    }
}

struct IngredientList: View {
    @EnvironmentObject private var store: RecipeStore
    let groups: [IngredientGroup]
    let scope: String
    var factor: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, group in
                if !group.title.isEmpty {
                    Text(group.title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(Color.chile)
                        .padding(.top, groupIndex == 0 ? 0 : 16)
                        .padding(.bottom, 4)
                }
                ForEach(Array(group.items.enumerated()), id: \.offset) { itemIndex, item in
                    IngredientRow(text: Scaler.text(item, factor: factor), key: "\(scope):\(groupIndex):\(itemIndex)")
                    Divider()
                }
            }
        }
    }
}

struct IngredientRow: View {
    @EnvironmentObject private var store: RecipeStore
    let text: String
    let key: String

    var body: some View {
        let isOn = store.isChecked(key)
        Button {
            store.toggleCheck(key)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.nopal : Color.secondary)
                Text(text)
                    .strikethrough(isOn, color: .secondary)
                    .foregroundStyle(isOn ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct StepList: View {
    let steps: [String]
    let scope: String

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StepRow(number: index + 1, text: step, key: "\(scope):\(index)")
            }
        }
    }
}

struct StepRow: View {
    @EnvironmentObject private var store: RecipeStore
    let number: Int
    let text: String
    let key: String

    var body: some View {
        let isOn = store.isChecked(key)
        Button {
            store.toggleCheck(key)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(isOn ? Color.nopal : Color.talaveraSoft)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(.systemBackground))
                    } else {
                        Text("\(number)")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Color.talavera)
                    }
                }
                .frame(width: 30, height: 30)
                Text(text)
                    .foregroundStyle(isOn ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(isOn ? Color.clear : Color.card))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(number): \(text)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct TipsBox: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Secretos de la abuela")
                .font(.display(.title3))
                .foregroundStyle(Color.chile)
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(tip).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.chileSoft))
    }
}

struct VariationCard: View {
    let recipe: Recipe
    let variation: Variation
    let index: Int
    var factor: Double = 1
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isOpen.toggle() }
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((variation.region ?? recipe.region).uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(Color.chile)
                        Text(variation.name)
                            .font(.display(.title3))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.leading)
                        Text(variation.en)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? .isSelected : [])

            if isOpen {
                VStack(alignment: .leading, spacing: 20) {
                    if let note = variation.note {
                        Text(note)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Ingredientes")
                        IngredientList(groups: variation.ingredients, scope: "\(recipe.id):v\(index):i", factor: factor)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Preparación")
                        StepList(steps: variation.steps, scope: "\(recipe.id):v\(index):s")
                    }
                    if let pressureNote = variation.pressureNote {
                        InfoBox(label: "Olla exprés", background: .nopalSoft) {
                            Text(pressureNote)
                        }
                    }
                }
                .padding([.horizontal, .bottom], 16)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.hairline))
    }
}

/// ¿Para cuántos? Step the servings up or down, or jump to half, original or double.
struct ServingsCard: View {
    @EnvironmentObject private var store: RecipeStore
    let recipe: Recipe

    private let quick: [(Double, String)] = [(0.5, "Mitad"), (1, "Original"), (2, "Doble")]

    var body: some View {
        let factor = store.factor(for: recipe.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("¿PARA CUÁNTOS?")
                    .font(.slab(15, relativeTo: .headline))
                Spacer(minLength: 8)
                if Scaler.base(recipe.servings) != nil {
                    HStack(spacing: 8) {
                        stepButton("minus", label: "Fewer servings", direction: -1)
                        Text(Scaler.yieldText(recipe.servings, factor: factor))
                            .font(.system(.subheadline, design: .monospaced))
                            .monospacedDigit()
                            .frame(minWidth: 92)
                            .contentTransition(.numericText())
                            .accessibilityLabel("Makes \(Scaler.yieldText(recipe.servings, factor: factor))")
                        stepButton("plus", label: "More servings", direction: 1)
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(quick.indices, id: \.self) { i in
                    let value = quick[i].0
                    let title = quick[i].1
                    let isOn = abs(factor - value) < 1e-9
                    Button {
                        withAnimation(.snappy) { store.setFactor(value, for: recipe.id) }
                    } label: {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(isOn ? Color(.systemBackground) : Color.primary)
                            .background(Capsule().fill(isOn ? Color.primary : Color.paper))
                            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: isOn ? 0 : 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            if factor != 1 {
                Text("Ingredient amounts are adjusted for you. Amounts written inside the steps, and cooking times, are for the original recipe.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.inkShadow).offset(x: 3, y: 3))
    }

    private func stepButton(_ symbol: String, label: String, direction: Double) -> some View {
        Button {
            withAnimation(.snappy) { store.stepServings(recipe, by: direction) }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.mxRosa))
                .overlay(Circle().strokeBorder(Color.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
