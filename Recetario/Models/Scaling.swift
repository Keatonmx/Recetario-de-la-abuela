import Foundation

/// Scales the amounts written in ingredient lines, for cooking for more or fewer people.
///
/// It multiplies the quantity that starts each clause ("2 lb pork", ", 3 garlic cloves",
/// " and 1 tbsp salt", " or 2 cans"), metric and packet amounts in parentheses ("(500 g)",
/// "(1 packet)"), and fixes singular/plural on the word after the number. Numbers such as
/// "3-inch", "350°F" or "(29 oz each)" are left alone.
///
/// This is a port of `SCALE` in web/recetario.html. CI checks both against
/// scripts/validate/scaling-fixtures.json, so keep them in step.
/// Foundation-only on purpose: scripts/validate compiles it on its own.
enum Scaler {
    private static let fractions: [Character: Double] = [
        "⅛": 1.0 / 8, "¼": 1.0 / 4, "⅓": 1.0 / 3, "⅜": 3.0 / 8, "½": 1.0 / 2,
        "⅝": 5.0 / 8, "⅔": 2.0 / 3, "¾": 3.0 / 4, "⅞": 7.0 / 8
    ]
    private static let num = "(?:\\d+(?:\\.\\d+)?[⅛¼⅓⅜½⅝⅔¾⅞]?|[⅛¼⅓⅜½⅝⅔¾⅞])"
    private static let clause = regex("(^|, | and | or | plus | with |— )(about )?(\(num))(?:–(\(num)))?(?= ?[A-Za-zÀ-ÿ(])", caseInsensitive: true)
    private static let paren = regex("\\((about )?(\(num)) ?(g|ml|kg|oz|packets?|tablets?)\\)", caseInsensitive: true)
    private static let sizeWordBefore = regex("\\b(cans?|tablets?|jars?|bags?)\\s*$", caseInsensitive: true)
    private static let packetUnit = regex("^(packet|tablet)s?$", caseInsensitive: true)
    private static let oneWord = regex("^ ?[A-Za-zÀ-ÿ'-]+")
    private static let twoWords = regex("^ ?[A-Za-zÀ-ÿ'-]+ [A-Za-zÀ-ÿ'-]+")
    private static let agreeWords = regex("^( ?)([A-Za-zÀ-ÿ'-]+)( ([A-Za-zÀ-ÿ'-]+))?")
    private static let baseRegex = regex("^(?:about )?(\(num))(?:–(\(num)))?", caseInsensitive: true)
    private static let yieldRegex = regex("^(about )?(\(num))(?:–(\(num)))?(.*)$", caseInsensitive: true)

    private static let plural: [String: String] = [
        "cup": "cups", "can": "cans", "tablet": "tablets", "stick": "sticks", "sprig": "sprigs", "slice": "slices",
        "strip": "strips", "quart": "quarts", "packet": "packets", "bunch": "bunches", "ear": "ears", "head": "heads",
        "clove": "cloves", "egg": "eggs", "lime": "limes", "orange": "oranges", "tortilla": "tortillas",
        "bolillo": "bolillos", "potato": "potatoes", "tomato": "tomatoes", "carrot": "carrots", "chayote": "chayotes",
        "jalapeño": "jalapeños", "serrano": "serranos", "habanero": "habaneros", "poblano": "poblanos",
        "plantain": "plantains", "pear": "pears", "peach": "peaches", "apple": "apples", "chile": "chiles",
        "leaf": "leaves", "yolk": "yolks", "onion": "onions", "chicken": "chickens", "bowl": "bowls", "plate": "plates",
        "roll": "rolls", "serving": "servings", "persona": "personas", "concha": "conchas", "tomatillo": "tomatillos",
        "xoconostle": "xoconostles", "piece": "pieces", "disc": "discs", "ball": "balls", "loaf": "loaves",
        "taco": "tacos", "tostada": "tostadas", "stalk": "stalks"
    ]
    private static let singular: [String: String] = Dictionary(plural.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
    private static let adjectives: Set<String> = [
        "roma", "white", "red", "large", "small", "medium", "whole", "ripe", "dried", "fresh", "garlic", "corn",
        "flour", "green", "day-old", "mexican", "bay", "avocado", "hoja", "thin", "stewing", "sour", "romaine"
    ]
    private static let steps: [(Double, String)] = [
        (0, ""), (1.0 / 8, "⅛"), (1.0 / 4, "¼"), (1.0 / 3, "⅓"), (1.0 / 2, "½"), (2.0 / 3, "⅔"), (3.0 / 4, "¾"), (1, "")
    ]

    // MARK: Public

    /// One ingredient line, scaled.
    static func text(_ s: String, factor: Double) -> String {
        if factor == 1 { return s }
        let ns = s as NSString
        var out = ""
        var last = 0
        var searchFrom = 0
        while searchFrom <= ns.length,
              let m = clause.firstMatch(in: s, options: [.withoutAnchoringBounds],
                                        range: NSRange(location: searchFrom, length: ns.length - searchFrom)) {
            let lead = group(m, 1, in: ns) ?? ""
            let about = group(m, 2, in: ns) ?? ""
            guard let a = group(m, 3, in: ns) else { break }
            let b = group(m, 4, in: ns)
            let va = parse(a)
            if va.isNaN {
                searchFrom = m.range.location + m.range.length
                continue
            }
            let na = va * factor
            let nb = b.map { parse($0) * factor }
            let qty = nb.map { "\(format(na))–\(format($0))" } ?? format(na)
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last)) + lead + about + qty
            last = m.range.location + m.range.length

            // One word, or two when the first is an adjective ("Roma tomatoes", "garlic cloves").
            let rest = ns.substring(from: last)
            var words = firstMatch(oneWord, in: rest)
            if let w = words, adjectives.contains(w.trimmingCharacters(in: .whitespaces).lowercased()) {
                words = firstMatch(twoWords, in: rest) ?? w
            }
            if let w = words {
                out += agree(w, value: nb ?? na)
                last += (w as NSString).length
            }
            searchFrom = last
        }
        out += ns.substring(from: last)
        return scaleParentheses(out, factor: factor)
    }

    private static let marked = regex("\\[\\[(.+?)\\]\\]")

    /// A step, scaled: only amounts marked [[like this]] change (batch amounts). Times,
    /// temperatures, pot sizes, trivet water and per-piece amounts are left unmarked on purpose.
    static func stepText(_ s: String, factor: Double) -> String {
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in marked.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            out += text(ns.substring(with: m.range(at: 1)), factor: factor)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    /// The yield, scaled: "10 bowls" ×½ → "5 bowls", "About 30" ×½ → "About 15".
    static func yieldText(_ y: String, factor: Double) -> String {
        let ns = y as NSString
        guard factor != 1,
              let m = yieldRegex.firstMatch(in: y, range: NSRange(location: 0, length: ns.length)),
              let aText = group(m, 2, in: ns) else { return y }
        let a = parse(aText) * factor
        let b = group(m, 3, in: ns).map { parse($0) * factor }
        let qty = b.map { "\(format(a))–\(format($0))" } ?? format(a)
        return (group(m, 1, in: ns) ?? "") + qty + agree(group(m, 4, in: ns) ?? "", value: b ?? a)
    }

    /// The number of servings a yield describes: "10 bowls" → 10, "4–6 plates" → 5.
    static func base(_ y: String) -> Double? {
        let ns = y as NSString
        guard let m = baseRegex.firstMatch(in: y, range: NSRange(location: 0, length: ns.length)),
              let aText = group(m, 1, in: ns) else { return nil }
        let a = parse(aText)
        if let bText = group(m, 2, in: ns) { return (a + parse(bText)) / 2 }
        return a
    }

    /// Kitchen-friendly numbers: 0.5 → "½", 1.25 → "1¼", 10.5 → "10½", 23.4 → "23".
    static func format(_ x: Double) -> String {
        if x >= 20 { return String(Int(x.rounded())) }
        if x >= 10 {
            let r = (x * 2).rounded() / 2
            return r == r.rounded(.down) ? String(Int(r)) : "\(Int(r))½"
        }
        var whole = Int(x.rounded(.down))
        let frac = x - Double(whole)
        let choices = whole >= 3 ? steps.filter { $0.0 != 1.0 / 8 && $0.0 != 1.0 / 3 && $0.0 != 2.0 / 3 } : steps
        var best = choices.reduce(choices[0]) { abs($1.0 - frac) < abs($0.0 - frac) ? $1 : $0 }
        if best.0 == 1 {
            whole += 1
            best = steps[0]
        }
        if whole == 0 && best.0 == 0 { return "⅛" }
        return (whole == 0 ? "" : String(whole)) + best.1
    }

    // MARK: Helpers

    private static func regex(_ pattern: String, caseInsensitive: Bool = false) -> NSRegularExpression {
        // The patterns are constants; a bad one is a programming error.
        try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
    }

    private static func group(_ m: NSTextCheckingResult, _ i: Int, in ns: NSString) -> String? {
        let r = m.range(at: i)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }

    private static func firstMatch(_ re: NSRegularExpression, in s: String) -> String? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range)
    }

    private static func parse(_ t: String) -> Double {
        var digits = t
        var value = 0.0
        if let last = digits.last, let f = fractions[last] {
            value += f
            digits.removeLast()
        }
        if digits.isEmpty { return value == 0 ? .nan : value }
        guard let n = Double(digits) else { return .nan }
        return n + value
    }

    /// Makes the word (or adjective + word) after a number agree with it: "1 cup" ⇄ "2 cups".
    private static func agree(_ rest: String, value: Double) -> String {
        let ns = rest as NSString
        guard let m = agreeWords.firstMatch(in: rest, range: NSRange(location: 0, length: ns.length)) else { return rest }
        let space = group(m, 1, in: ns) ?? ""
        guard let w1 = group(m, 2, in: ns) else { return rest }

        func fix(_ w: String) -> String? {
            let lower = w.lowercased()
            guard let replacement = value > 1 ? plural[lower] : singular[lower] else { return nil }
            guard let first = w.first else { return replacement }
            let isUpper = String(first).uppercased() == String(first)
            return isUpper ? replacement.prefix(1).uppercased() + replacement.dropFirst() : replacement
        }

        if let fixed = fix(w1) {
            let consumed = (space as NSString).length + (w1 as NSString).length
            return space + fixed + ns.substring(from: consumed)
        }
        if let w2 = group(m, 4, in: ns), adjectives.contains(w1.lowercased()), let fixed = fix(w2) {
            return space + w1 + " " + fixed + ns.substring(from: m.range.length)
        }
        return rest
    }

    private static func scaleParentheses(_ s: String, factor: Double) -> String {
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in paren.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            last = m.range.location + m.range.length
            let before = ns.substring(to: m.range.location)
            let original = ns.substring(with: m.range)
            if firstMatch(sizeWordBefore, in: before) != nil {
                out += original
                continue
            }
            let about = group(m, 1, in: ns) ?? ""
            let value = parse(group(m, 2, in: ns) ?? "") * factor
            var unit = group(m, 3, in: ns) ?? ""
            if packetUnit.firstMatch(in: unit, range: NSRange(location: 0, length: (unit as NSString).length)) != nil {
                if unit.lowercased().hasSuffix("s") { unit.removeLast() }
                if value > 1 { unit += "s" }
            }
            out += "(\(about)\(format(value)) \(unit))"
        }
        out += ns.substring(from: last)
        return out
    }
}
