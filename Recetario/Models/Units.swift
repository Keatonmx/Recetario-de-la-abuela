import Foundation

/// Converts US measures in ingredient lines and steps to metric (applied after scaling):
/// lb/oz → g/kg, quarts/cups → ml/l, "8-qt" pots → liters, inches → cm, °F → °C.
/// A volume followed by its weight in parentheses ("4 cups (500 g) flour") becomes the weight.
///
/// This is a port of `UNITS` in web/recetario.html. CI checks both against
/// scripts/validate/scaling-fixtures.json. Foundation-only on purpose.
enum Units {
    private static let fractions: [Character: Double] = [
        "⅛": 1.0 / 8, "¼": 1.0 / 4, "⅓": 1.0 / 3, "⅜": 3.0 / 8, "½": 1.0 / 2,
        "⅝": 5.0 / 8, "⅔": 2.0 / 3, "¾": 3.0 / 4, "⅞": 7.0 / 8
    ]
    private static let num = "(?:\\d+(?:\\.\\d+)?[⅛¼⅓⅜½⅝⅔¾⅞]?|[⅛¼⅓⅜½⅝⅔¾⅞])"
    private static var qty: String { "(\(num))(?:–(\(num)))?" }

    private typealias Rule = (NSRegularExpression, ([String?]) -> String)

    private static let rules: [Rule] = [
        // volume with its weight in parentheses → the weight
        (regex("\(qty) (?:cups?|tbsp|tsp) \\((about )?(\(num)) ?(g|oz|ml)\\)"), { g in
            let about = g[3] ?? ""
            let w = parse(g[4] ?? "")
            let unit = g[5] ?? "g"
            return about + (unit == "ml" ? mls(w) : grams(w * (unit == "oz" ? 28.35 : 1)))
        }),
        (regex("\(qty) ?(?:lb|lbs)\\b"), { g in range(values(g, times: 453.6), grams) }),
        (regex("\(qty) ?oz\\b"), { g in range(values(g, times: 28.35), grams) }),
        (regex("\(qty) quarts?\\b"), { g in range(values(g, times: 946), mls) }),
        (regex("\(qty) cups?\\b"), { g in range(values(g, times: 240), mls) }),
        (regex("\\b(an? )?(\\d+)-qt\\b"), { g in
            "\(g[1] != nil ? "a " : "")\(dec((Double(g[2] ?? "") ?? 0) * 0.946, 1))-liter"
        }),
        (regex("\\b(an? )?(\\d+)- or (\\d+)-inch\\b"), { g in
            let a = Double(g[2] ?? "") ?? 0, b = Double(g[3] ?? "") ?? 0
            return "\(g[1] != nil ? "a " : "")\(Int((a * 2.54).rounded())) or \(Int((b * 2.54).rounded())) cm"
        }),
        (regex("(\(num))-inch\\b"), { g in "\(cm(parse(g[1] ?? ""))) cm" }),
        (regex("(\(num)) inch(?:es)?\\b"), { g in "\(cm(parse(g[1] ?? ""))) cm" }),
        (regex("(\\d+)°F"), { g in
            let f = Double(g[1] ?? "") ?? 0
            return "\(Int(((f - 32) * 5 / 9 / 10).rounded()) * 10)°C"
        })
    ]

    /// The line with US measures converted to metric.
    static func metric(_ s: String) -> String {
        rules.reduce(s) { text, rule in replace(rule.0, in: text, with: rule.1) }
    }

    // MARK: Helpers

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants; a bad one is a programming error.
        try! NSRegularExpression(pattern: pattern)
    }

    private static func replace(_ re: NSRegularExpression, in s: String, with f: ([String?]) -> String) -> String {
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let groups: [String?] = (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            out += f(groups)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    private static func parse(_ t: String) -> Double {
        var digits = t
        var value = 0.0
        if let last = digits.last, let f = fractions[last] {
            value += f
            digits.removeLast()
        }
        return (Double(digits) ?? 0) + value
    }

    private static func values(_ g: [String?], times k: Double) -> [Double] {
        var out = [parse(g[1] ?? "") * k]
        if let b = g[2] { out.append(parse(b) * k) }
        return out
    }

    /// Like JavaScript's String(Number(x.toFixed(places))): "4.7", "2", "1.3".
    private static func dec(_ x: Double, _ places: Int) -> String {
        let p = pow(10.0, Double(places))
        let r = (x * p).rounded() / p
        if r == r.rounded(.down) { return String(Int(r)) }
        return String(r)
    }

    private static func round(_ x: Double, _ step: Double) -> Int {
        Int(max(step, (x / step).rounded() * step))
    }

    private static func grams(_ g: Double) -> String {
        if g >= 1000 { return "\(dec(g / 1000, 1)) kg" }
        if g < 10 { return "\(dec(g, 0)) g" }
        return "\(g < 100 ? round(g, 5) : round(g, 10)) g"
    }

    private static func mls(_ ml: Double) -> String {
        if ml >= 1000 { return "\(dec(ml / 1000, 1)) l" }
        return "\(ml < 100 ? round(ml, 5) : round(ml, 10)) ml"
    }

    private static func cm(_ inches: Double) -> String {
        let x = inches * 2.54
        return x < 3 ? dec(x, 1) : dec(x, 0)
    }

    /// "240–480 ml": a range keeps one unit, written after the second number.
    private static func range(_ vals: [Double], _ fmt: (Double) -> String) -> String {
        guard vals.count == 2 else { return fmt(vals[0]) }
        let x = fmt(vals[0]), y = fmt(vals[1])
        let xs = x.split(separator: " "), ys = y.split(separator: " ")
        if xs.count > 1, ys.count > 1, xs[1] == ys[1] { return "\(xs[0])–\(y)" }
        return "\(x)–\(y)"
    }
}
