import SwiftUI

@main
struct RecetarioApp: App {
    @StateObject private var store = RecipeStore()

    init() {
        BundledFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: RecipeStore
    // CI screenshots can open a tab (-screenshotTab 1) or a recipe (-screenshotRecipe pozole-rojo).
    @State private var selection = UserDefaults.standard.integer(forKey: "screenshotTab")
    @State private var path: [Recipe] = []
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $path) { RecipeListView(savedOnly: false) }
                .tabItem { Label { Text(store.t("Recetas", "Recipes")) } icon: { Image("tab-recetas") } }
                .tag(0)
            NavigationStack { QueTengoView() }
                .tabItem { Label { Text(store.t("¿Qué tengo?", "What do I have?")) } icon: { Image("tab-quetengo") } }
                .tag(1)
            NavigationStack { RecipeListView(savedOnly: true) }
                .tabItem { Label { Text(store.t("Guardadas", "Saved")) } icon: { Image("milagro") } }
                .tag(2)
            NavigationStack { PantryView() }
                .tabItem { Label { Text(store.t("Despensa", "Pantry")) } icon: { Image("tab-despensa") } }
                .tag(3)
        }
        .onAppear {
            if path.isEmpty, let id = UserDefaults.standard.string(forKey: "screenshotRecipe"),
               let recipe = store.book.recipes.first(where: { $0.id == id }) {
                path = [recipe]
            }
        }
        .environment(\.locale, Locale(identifier: store.lang == .es ? "es_MX" : "en_US"))
        .tint(Color.mxRosa)
        .preferredColorScheme((Appearance(rawValue: appearance) ?? .system).colorScheme)
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastView(text: toast)
                    .padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: store.toast)
    }
}
