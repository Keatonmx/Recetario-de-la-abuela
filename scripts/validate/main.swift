import Foundation

// Decodes recipes.json with the app's own models and checks basic integrity.
// It also checks the Swift scaler against the web scaler's output in scaling-fixtures.json.
// CI: swiftc Recetario/Models/Models.swift Recetario/Models/Scaling.swift Recetario/Models/Units.swift scripts/validate/main.swift -o validate && ./validate

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

    struct ScalingCase: Decodable { let kind: String; let input: String; let factor: Double; let output: String }
    let fixturesPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "scripts/validate/scaling-fixtures.json"
    let cases = try JSONDecoder().decode([ScalingCase].self, from: Data(contentsOf: URL(fileURLWithPath: fixturesPath)))
    var mismatches = 0
    for c in cases {
        let got: String
        switch c.kind {
        case "yield": got = Scaler.yieldText(c.input, factor: c.factor)
        case "metric": got = Units.metric(c.input)
        case "scaled-metric": got = Units.metric(Scaler.text(c.input, factor: c.factor))
        default: got = Scaler.text(c.input, factor: c.factor)
        }
        if got != c.output {
            mismatches += 1
            if mismatches <= 15 {
                problems.append("scaling ×\(c.factor) of \"\(c.input)\": web gives \"\(c.output)\", Swift gives \"\(got)\"")
            }
        }
    }
    if mismatches > 15 { problems.append("…and \(mismatches - 15) more scaling mismatches") }

    if problems.isEmpty {
        let variations = book.recipes.reduce(0) { $0 + $1.variations.count }
        print("OK: \(book.recipes.count) recipes, \(variations) variations, \(book.categories.count) categories, \(cases.count) scaling cases match")
    } else {
        problems.forEach { print("ERROR: \($0)") }
        exit(1)
    }
} catch {
    print("ERROR: could not decode \(path): \(error)")
    exit(1)
}
