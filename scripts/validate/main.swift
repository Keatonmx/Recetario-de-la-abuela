import Foundation

// Decodes recipes.json with the app's own models and checks basic integrity.
// CI: swiftc Recetario/Models/Models.swift scripts/validate/main.swift -o validate && ./validate

let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Recetario/Resources/recipes.json"

do {
    let book = try RecipeBook.load(from: URL(fileURLWithPath: path))
    var problems: [String] = []
    let categoryIDs = Set(book.categories.map(\.id))

    for recipe in book.recipes {
        if !categoryIDs.contains(recipe.category) {
            problems.append("\(recipe.id): unknown category \(recipe.category)")
        }
        if recipe.ingredients.isEmpty || recipe.steps.isEmpty {
            problems.append("\(recipe.id): missing ingredients or steps")
        }
        if recipe.pressureCooker == nil && recipe.pressureNote == nil {
            problems.append("\(recipe.id): needs a pressure-cooker version or a note saying why not")
        }
        for variation in recipe.variations where variation.steps.isEmpty {
            problems.append("\(recipe.id) / \(variation.name): variation has no steps")
        }
    }
    let duplicates = Dictionary(grouping: book.recipes, by: \.id).filter { $0.value.count > 1 }.keys
    problems += duplicates.map { "duplicate recipe id \($0)" }

    if problems.isEmpty {
        let variations = book.recipes.reduce(0) { $0 + $1.variations.count }
        print("OK: \(book.recipes.count) recipes, \(variations) variations, \(book.categories.count) categories")
    } else {
        problems.forEach { print("ERROR: \($0)") }
        exit(1)
    }
} catch {
    print("ERROR: could not decode \(path): \(error)")
    exit(1)
}
