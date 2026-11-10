import SwiftUI

/// Turns between two faces around the vertical axis. It's Animatable so the face swaps at
/// the halfway point of the animation, the moment the card is edge-on.
struct FlipCard<Front: View, Back: View>: View, Animatable {
    /// 0 shows the front, 180 the back.
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

/// A recipe card picked up off the table and turned over: the back has the ingredients,
/// the steps and grandma's tips, and a way into the full recipe.
struct CardFlipView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let recipe: Recipe
    var onOpen: () -> Void
    var onClose: () -> Void

    @State private var angle: Double = 0
    @State private var lifted = false
    @State private var side: Side = .ingredients

    enum Side: Hashable { case ingredients, steps }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width - 40, 380)
            let height = min(geo.size.height - 90, width * 1.62)
            ZStack {
                Color.black.opacity(lifted ? 0.55 : 0)
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)
                    .accessibilityLabel(store.t("Cerrar", "Close"))
                    .accessibilityAddTraits(.isButton)

                FlipCard(angle: angle, front: front(width: width), back: back(width: width, height: height))
                    .frame(width: width, height: height)
                    .scaleEffect(lifted ? 1 : 0.7)
                    .opacity(lifted ? 1 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.3)) { lifted = true }
            if reduceMotion {
                angle = 180
            } else {
                withAnimation(.spring(duration: 0.75, bounce: 0.2).delay(0.2)) { angle = 180 }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: angle >= 90)
    }

    private func flip() {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.2)) { angle = angle < 90 ? 180 : 0 }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.2)) { lifted = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: onClose)
    }

    // MARK: Faces

    private func front(width: CGFloat) -> some View {
        Button(action: flip) {
            LoteriaCard(recipe: recipe, isFavorite: store.isFavorite(recipe.id), big: true)
                .frame(width: width * 0.86)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHint(store.t("Voltea la carta", "Turns the card over"))
    }

    private func back(width: CGFloat, height: CGFloat) -> some View {
        let text = recipe.text(store.lang)
        let factor = store.factor(for: recipe.id)
        return VStack(spacing: 0) {
            // Header: number and name, smaller than the front.
            HStack(alignment: .center, spacing: 10) {
                Text("\(recipe.number)")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(recipe.cardName.uppercased())
                        .font(.slab(15))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(store.servings(recipe))
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.stockMuted)
                }
                Spacer(minLength: 0)
                Button(action: flip) {
                    Image(systemName: "arrow.uturn.left.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.t("Voltear la carta", "Turn the card over"))
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.t("Cerrar", "Close"))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Picker(store.t("Ver", "Show"), selection: $side) {
                Text(store.t("Ingredientes", "Ingredients")).tag(Side.ingredients)
                Text(store.t("Preparación", "Preparation")).tag(Side.steps)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch side {
                    case .ingredients:
                        IngredientList(groups: text.ingredients, keyGroups: recipe.en.ingredients,
                                       scope: "\(recipe.id):t:i", factor: factor, cart: (recipe, nil))
                    case .steps:
                        StepList(steps: text.steps, keySteps: recipe.en.steps, scope: "\(recipe.id):t:s", factor: factor)
                    }
                    if !text.tips.isEmpty {
                        ConsejosBox(tips: text.tips.map(store.shown))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }

            Button(action: onOpen) {
                Text(store.t("Ver la receta completa", "Open the full recipe"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.onRosa)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.mxRosa))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.ink, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.stock))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ink, lineWidth: 1.5).padding(5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
        // Card stock is cream in both themes, so the back always reads as light.
        .environment(\.colorScheme, .light)
    }
}

/// Consejos de la abuela, on a scrap of parchment.
struct ConsejosBox: View {
    @EnvironmentObject private var store: RecipeStore
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t("Consejos de la Abuela", "Grandma's Tips"))
                .font(.display(.headline))
                .foregroundStyle(Color(hexString: "#7A3E1D"))
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("✿").foregroundStyle(Color(hexString: "#B5562A"))
                    Text(tip).fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .foregroundStyle(Color(hexString: "#3B2A1A"))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hexString: "#F6E7C1"), Color(hexString: "#EBD3A0")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hexString: "#C9A66B"), lineWidth: 1.5))
        .rotationEffect(.degrees(-0.6))
    }
}
