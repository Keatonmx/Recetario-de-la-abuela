import SwiftUI

/// ¡Buenas!: the deck button that answers "what do I cook today?"
struct BuenasButton: View {
    @EnvironmentObject private var store: RecipeStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // A little deck of three cards.
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.stock)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ink, lineWidth: 1.5))
                            .overlay(RoundedRectangle(cornerRadius: 2).fill([Color.mxRosa, Color.maiz, Color.talavera][i]).padding(5))
                            .frame(width: 30, height: 40)
                            .rotationEffect(.degrees(Double(i - 1) * 9))
                            .offset(x: Double(i - 1) * 5)
                    }
                }
                .frame(width: 50, height: 48)
                VStack(alignment: .leading, spacing: 1) {
                    Text("¡Buenas!")
                        .font(.rotulo(24, relativeTo: .title3))
                        .foregroundStyle(Color.mxRosa)
                    Text(store.t("Baraja y saca: ¿qué cocino hoy?", "Shuffle and draw: what should I cook today?"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "shuffle")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.card))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ink, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.inkShadow).offset(x: 3, y: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.t("¡Buenas! Saca una receta al azar", "¡Buenas! Draw a random recipe"))
    }
}

/// The shuffle: a handful of cards scatter and gather a few times, then one is drawn.
struct BuenasShuffle: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let deck: [Recipe]
    var onDraw: (Recipe) -> Void

    private struct Spot: Equatable {
        var x: Double = 0
        var y: Double = 0
        var angle: Double = 0
    }

    @State private var cards: [Recipe] = []
    @State private var spots: [Spot] = []
    @State private var drawn: Recipe?
    @State private var shuffles = 0
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(shown ? 0.55 : 0).ignoresSafeArea()
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, recipe in
                    let spot = spots.indices.contains(i) ? spots[i] : Spot()
                    let isDrawn = drawn?.id == recipe.id
                    LoteriaCard(recipe: recipe, big: isDrawn)
                        .frame(width: isDrawn ? min(geo.size.width * 0.7, 300) : 130)
                        .rotationEffect(.degrees(isDrawn ? 0 : spot.angle))
                        .offset(x: isDrawn ? 0 : spot.x, y: isDrawn ? 0 : spot.y)
                        .opacity(drawn == nil || isDrawn ? 1 : 0)
                        .zIndex(isDrawn ? 100 : Double(i))
                }
                if drawn != nil {
                    Text("¡Buenas!")
                        .font(.rotulo(54))
                        .foregroundStyle(Color.mxRosa)
                        .shadow(color: Color.ink, radius: 0, x: 3, y: 3)
                        .rotationEffect(.degrees(-6))
                        .offset(y: -min(geo.size.height * 0.36, 300))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .zIndex(200)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task { await run(in: geo.size) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: shuffles)
        .sensoryFeedback(.success, trigger: drawn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.t("Barajando las cartas", "Shuffling the cards"))
    }

    private func scatter(_ size: CGSize) {
        let w = Double(size.width) * 0.32, h = Double(size.height) * 0.28
        spots = cards.map { _ in Spot(x: .random(in: -w...w), y: .random(in: -h...h), angle: .random(in: -28...28)) }
    }

    private func run(in size: CGSize) async {
        guard let pick = deck.randomElement() else { return }
        // The drawn card plus a few others, all in the shuffle.
        cards = ([pick] + deck.filter { $0.id != pick.id }.shuffled().prefix(6)).shuffled()
        spots = cards.map { _ in Spot() }
        withAnimation(.easeOut(duration: 0.2)) { shown = true }
        if !reduceMotion {
            for round in 0..<7 {
                withAnimation(.snappy(duration: 0.16)) {
                    if round.isMultiple(of: 3) {
                        spots = cards.map { _ in Spot(angle: .random(in: -6...6)) }
                    } else {
                        scatter(size)
                    }
                }
                shuffles += 1
                try? await Task.sleep(for: .milliseconds(190))
            }
        }
        withAnimation(.spring(duration: 0.45, bounce: 0.35)) { drawn = pick }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 500 : 900))
        onDraw(pick)
    }
}
