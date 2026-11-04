import SwiftUI

@main
struct RecetarioApp: App {
    @StateObject private var store = RecipeStore()

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
                .tabItem { Label("Recetas", systemImage: "book.closed") }
            NavigationStack { RecipeListView(savedOnly: true) }
                .tabItem { Label("Guardadas", systemImage: "star") }
            NavigationStack { PantryView() }
                .tabItem { Label("Despensa", systemImage: "leaf") }
        }
        .tint(Color.chile)
    }
}
