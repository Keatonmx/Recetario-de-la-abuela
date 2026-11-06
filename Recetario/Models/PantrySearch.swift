import Foundation

/// ¿Qué tengo? — what can I cook with what I have.
///
/// A port of `PANTRY` in web/recetario.html. The lexicon and each recipe's needs come
/// precomputed in recipes.json; this does the part that depends on what the cook types:
/// matching words (English or Spanish, plurals, typos) to ingredients, and ranking recipes.
/// CI checks it against the web engine with scripts/validate/scaling-fixtures.json.
/// Foundation-only on purpose.
struct LexEntry: Codable, Hashable, Identifiable {
    let id: String
    let es: String
    let en: String
    /// protein, main, aromatic, season, basic or ignore
    let kind: String
    let parent: String?
    let aliases: [String]
}

struct PantryMatch: Identifiable {
    var id: String { recipe.id }
    let recipe: Recipe
    /// How much of what the recipe needs you have, 0…1.
    let score: Double
    let matched: [[String]]
    let missing: [[String]]
}

final class PantrySearch {
    let entries: [String: LexEntry]
    private let order: [LexEntry]
    private let compiled: [(NSRegularExpression, String)]
    private let singleWords: [(String, String)]

    private static let weight: [String: Double] = ["protein": 3, "main": 1, "aromatic": 0.5, "season": 0.5, "basic": 0.25]
    private static let stopWords: Set<String> = [
        "i", "have", "some", "a", "an", "the", "and", "y", "de", "del", "la", "el", "los", "las", "con", "tengo", "hay",
        "un", "una", "unos", "unas", "of", "with", "my", "me", "fresh", "frescos", "fresco", "few", "little", "poco",
        "poquito", "bit", "lots", "lb", "kg", "g", "cup", "cups", "piece", "pieces", "can", "cans", "bag", "leftover",
        "sobras", "que", "what", "or", "o", "also", "tambien", "plus", "mas"
    ]

    init(lexicon: [LexEntry]) {
        order = lexicon
        entries = Dictionary(lexicon.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Every alias, longest first, so "chicken broth" wins over "chicken" and "garlic cloves" over "cloves".
        let aliases: [(String, String)] = lexicon.flatMap { e in e.aliases.map { (Self.fold($0), e.id) } }
            .sorted { a, b in
                let la = (a.0 as NSString).length, lb = (b.0 as NSString).length
                return la != lb ? la > lb : a.0 < b.0
            }
        compiled = aliases.map { alias, id in
            let pattern = "(^|[^a-z0-9'])\(NSRegularExpression.escapedPattern(for: alias))(?:es|s)?(?=[^a-z0-9']|$)"
            // The patterns come from bundled data; a bad one is a programming error.
            return (try! NSRegularExpression(pattern: pattern), id)
        }
        singleWords = aliases.filter { !$0.0.contains(" ") }
    }

    /// Lowercase, no accents, straight apostrophes.
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "`", with: "'")
    }

    // MARK: Matching

    /// Ingredient ids named in a piece of text, in order of first appearance.
    func ids(in text: String) -> [String] {
        let t = NSMutableString(string: " " + Self.fold(text) + " ")
        var found: [(Int, String)] = []
        for (re, id) in compiled {
            var from = 0
            while from <= t.length,
                  let m = re.firstMatch(in: t as String, options: [.withoutAnchoringBounds],
                                        range: NSRange(location: from, length: t.length - from)) {
                let pre = m.range(at: 1).length
                let start = m.range.location + pre
                let length = m.range.length - pre
                found.append((start, id))
                t.replaceCharacters(in: NSRange(location: start, length: length), with: String(repeating: " ", count: length))
                from = start + 1
            }
        }
        var seen = Set<String>()
        return found.sorted { $0.0 < $1.0 }
            .map(\.1)
            .filter { seen.insert($0).inserted }
            .filter { entries[$0]?.kind != "ignore" }
    }

    /// What someone typed, as ingredient ids, plus the words nothing matched.
    /// Misspellings within one letter (two for long words) still match.
    func parse(_ text: String) -> (ids: [String], unknown: [String]) {
        var ids = ids(in: text)
        var rest = " " + Self.fold(text) + " "
        for (re, _) in compiled {
            let ns = rest as NSString
            var out = ""
            var last = 0
            for m in re.matches(in: rest, range: NSRange(location: 0, length: ns.length)) {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let pre = m.range(at: 1)
                out += ns.substring(with: pre) + String(repeating: " ", count: m.range.length - pre.length)
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            rest = out
        }
        var unknown: [String] = []
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789ñ'-")
        let words = rest.components(separatedBy: allowed.inverted).filter { !$0.isEmpty }
        for w in words {
            if Self.stopWords.contains(w) || w.first.map({ $0.isNumber }) == true { continue }
            let len = (w as NSString).length
            if len >= 4 {
                let limit = len >= 8 ? 2 : 1
                var best: String? = nil
                var bestD = limit + 1
                for (alias, id) in singleWords {
                    let d = Self.distance(w, alias)
                    if d < bestD { best = id; bestD = d }
                }
                if let best {
                    if !ids.contains(best) { ids.append(best) }
                    continue
                }
            }
            unknown.append(w)
        }
        return (ids, unknown)
    }

    /// Typing suggestions: entries whose Spanish, English or alias starts with (then contains) the text.
    func suggest(_ text: String, excluding: [String] = []) -> [LexEntry] {
        let q = Self.fold(text).trimmingCharacters(in: .whitespaces)
        guard (q as NSString).length >= 2 else { return [] }
        func score(_ e: LexEntry) -> Int {
            let names = ([e.es, e.en] + e.aliases).map(Self.fold)
            if names.contains(where: { $0.hasPrefix(q) }) { return 0 }
            if names.contains(where: { $0.split(separator: " ").contains { $0.hasPrefix(q) } }) { return 1 }
            if names.contains(where: { $0.contains(q) }) { return 2 }
            return 9
        }
        var scored: [(Int, LexEntry)] = []
        for entry in order where entry.kind != "basic" && entry.kind != "ignore" && !excluding.contains(entry.id) {
            let s = score(entry)
            if s < 9 { scored.append((s, entry)) }
        }
        scored.sort { a, b in
            if a.0 != b.0 { return a.0 < b.0 }
            return a.1.es.localizedCompare(b.1.es) == .orderedAscending
        }
        return Array(scored.prefix(6)).map { $0.1 }
    }

    // MARK: Ranking

    func ancestors(_ id: String) -> [String] {
        var out: [String] = []
        var p = entries[id]?.parent
        while let parent = p {
            out.append(parent)
            p = entries[parent]?.parent
        }
        return out
    }

    func isUnder(_ id: String, _ root: String) -> Bool { id == root || ancestors(id).contains(root) }

    /// Ranks recipes by how much of what they need you have. Herbs and spices only count
    /// once you enter one; basics (salt, oil, lard, sugar, broth…) are assumed unless haveBasics is false.
    func rank(_ recipes: [Recipe], have haveIds: [String], haveBasics: Bool = true) -> [PantryMatch] {
        let have = Set(haveIds)
        let seasoningsEntered = haveIds.contains { entries[$0]?.kind == "season" }
        func covered(_ need: [String]) -> Bool {
            for id in need {
                if have.contains(id) { return true }
                if ancestors(id).contains(where: { have.contains($0) }) { return true }
                if haveIds.contains(where: { isUnder($0, id) }) { return true }
            }
            return false
        }
        let yours: [String] = haveIds.filter { id in
            guard let kind = entries[id]?.kind else { return false }
            return kind != "season" && kind != "basic"
        }

        var results: [(match: PantryMatch, rankScore: Double)] = []
        for r in recipes {
            var total = 0.0, got = 0.0, matchedReal = 0
            var matched: [[String]] = [], missing: [[String]] = []
            for need in r.needs {
                guard let first = need.first, let kind = entries[first]?.kind else { continue }
                if kind == "season" && !seasoningsEntered { continue }
                if kind == "basic" && haveBasics { continue }
                let w = Self.weight[kind] ?? 1
                total += w
                if covered(need) {
                    got += w
                    matched.append(need)
                    if kind == "protein" || kind == "main" { matchedReal += 1 }
                } else {
                    missing.append(need)
                }
            }
            guard total > 0, matchedReal > 0 else { continue }
            var usedCount = 0
            for h in yours {
                let usesIt = matched.contains { need in need.contains { id in id == h || isUnder(id, h) || isUnder(h, id) } }
                if usesIt { usedCount += 1 }
            }
            let used = yours.isEmpty ? 0 : Double(usedCount) / Double(yours.count)
            let score = got / total
            results.append((PantryMatch(recipe: r, score: score, matched: matched, missing: missing), score * 0.7 + used * 0.3))
        }
        results.sort { a, b in
            if a.rankScore != b.rankScore { return a.rankScore > b.rankScore }
            if a.match.missing.count != b.match.missing.count { return a.match.missing.count < b.match.missing.count }
            return a.match.recipe.name.localizedCompare(b.match.recipe.name) == .orderedAscending
        }
        return results.map { $0.match }
    }

    func label(_ id: String, lang: Lang = .es) -> String {
        guard let entry = entries[id] else { return id }
        return lang == .es ? entry.es : entry.en
    }

    // MARK: Damerau–Levenshtein (optimal string alignment): a swapped pair of letters is one typo.

    static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a.utf16), y = Array(b.utf16)
        if abs(x.count - y.count) > 2 { return 3 }
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var d = Array(repeating: Array(repeating: 0, count: y.count + 1), count: x.count + 1)
        for i in 0...x.count { d[i][0] = i }
        for j in 0...y.count { d[0][j] = j }
        for i in 1...x.count {
            for j in 1...y.count {
                var v = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
                if i > 1 && j > 1 && x[i - 1] == y[j - 2] && x[i - 2] == y[j - 1] { v = min(v, d[i - 2][j - 2] + 1) }
                d[i][j] = v
            }
        }
        return d[x.count][y.count]
    }
}
