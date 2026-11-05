import Foundation

// Decodes recipes.json with the app's own models and checks basic integrity.
// It also checks the Swift scaler against the web scaler's output in scaling-fixtures.json.
// CI: swiftc Recetario/Models/*.swift scripts/validate/main.swift (except RecipeStore.swift, which needs SwiftUI) -o validate && ./validate

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

    /// Rankings match when the recipes are the same, in the same order, with scores within 0.002.
    /// (JavaScript's toFixed and Swift's %.3f can round an exact tie like 0.5625 differently.)
    func sameRanking(_ a: String, _ b: String) -> Bool {
        let x = a.split(separator: ","), y = b.split(separator: ",")
        guard x.count == y.count else { return false }
        for (p, q) in zip(x, y) {
            let pa = p.split(separator: ":"), qa = q.split(separator: ":")
            guard pa.count == 2, qa.count == 2, pa[0] == qa[0],
                  let sp = Double(pa[1]), let sq = Double(qa[1]), abs(sp - sq) < 0.002 else { return false }
        }
        return true
    }
    struct ScalingCase: Decodable { let kind: String; let input: String; let factor: Double; let output: String }
    let fixturesPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "scripts/validate/scaling-fixtures.json"
    let cases = try JSONDecoder().decode([ScalingCase].self, from: Data(contentsOf: URL(fileURLWithPath: fixturesPath)))
    var mismatches = 0
    let pantry = PantrySearch(lexicon: book.lexicon)
    for c in cases {
        let got: String
        switch c.kind {
        case "ids": got = pantry.ids(in: c.input).joined(separator: ",")
        case "parse":
            let p = pantry.parse(c.input)
            got = p.ids.joined(separator: ",") + "|" + p.unknown.joined(separator: ",")
        case "rank", "rank-nobasics":
            let have = c.input.split(separator: ",").map(String.init)
            got = pantry.rank(book.recipes, have: have, haveBasics: c.kind == "rank")
                .prefix(5).map { "\($0.recipe.id):\(String(format: "%.3f", $0.score))" }.joined(separator: ",")
        case "yield": got = Scaler.yieldText(c.input, factor: c.factor)
        case "metric": got = Units.metric(c.input)
        case "step": got = Scaler.stepText(c.input, factor: c.factor)
        case "step-metric": got = Units.metric(Scaler.stepText(c.input, factor: c.factor))
        case "scaled-metric": got = Units.metric(Scaler.text(c.input, factor: c.factor))
        default: got = Scaler.text(c.input, factor: c.factor)
        }
        if got != c.output && !(c.kind.hasPrefix("rank") && sameRanking(got, c.output)) {
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
