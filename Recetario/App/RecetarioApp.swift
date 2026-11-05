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
    var body: some View {
        TabView {
            NavigationStack { RecipeListView(savedOnly: false) }
                .tabItem { Label { Text("Recetas") } icon: { Image("tab-recetas") } }
            NavigationStack { RecipeListView(savedOnly: true) }
                .tabItem { Label { Text("Guardadas") } icon: { Image("milagro") } }
            NavigationStack { PantryView() }
                .tabItem { Label { Text("Despensa") } icon: { Image("tab-despensa") } }
        }
        .tint(Color.mxRosa)
    }
}
