import SwiftUI
import UIKit

// The kitchen at night, on the night of the ofrenda (dark mode only): a deep violet night lit
// from below by candles, the edge of the ofrenda along the bottom of every screen (a bed of
// cempasúchil with lit veladoras standing in it), and a dark mantel with a camino de pétalos
// under the deck of cards. The cards themselves stay cream stock and black ink.
// Decor.swift calls these from the dark branches of `WallBackground` and `Hule`.

/// A small fixed-seed random generator, so the night's drawings come out the same every draw.
private struct NocheRandom {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(Double(state >> 11) / Double(1 << 53))
    }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

/// The night's fixed colors. These views only draw in dark mode, so none of them need a light value.
private enum Noche {
    static let skyTop = Color(hex6: 0x0F0B1B)
    static let skyMid = Color(hex6: 0x140F21)     // the same as Color.paper at night
    static let skyLow = Color(hex6: 0x1A1222)
    static let haze = Color(hex6: 0x5B2A86)        // morado
    static let candleGlow = Color(hex6: 0xFF9A3C)
    static let emberGlow = Color(hex6: 0xE0601A)
    static let rosaGlow = Color(hex6: 0xB4005C)

    static let marigold = Color(hex6: 0xF29F05)
    static let marigoldDeep = Color(hex6: 0xDE6A0A)
    static let marigoldLight = Color(hex6: 0xFFC233)
    static let marigoldShade = Color(hex6: 0x8A3A08)
    static let marigoldHeart = Color(hex6: 0xB8560A)
    static let leaf = Color(hex6: 0x2C5A33)
    static let leafLight = Color(hex6: 0x3D7040)
    static let rosa = Color(hex6: 0xE4007C)

    static let clothTop = Color(hex6: 0x2E1A48)
    static let clothBottom = Color(hex6: 0x1A1030)
    static let night = Color(hex6: 0x140F21)

    static let flameTip = Color(hex6: 0xFF8A1E)
    static let flame = Color(hex6: 0xFFC247)
    static let flameCore = Color(hex6: 0xFFF4D6)
    static let wick = Color(hex6: 0x3A2414)

    static let mantel = Color(hex6: 0x1F1533)
}

// MARK: - The night behind every screen

/// Every screen's background at night: a deep violet night, a little morado haze up top, and
/// the warm light of the ofrenda's candles rising from the bottom of the screen.
struct NocheDeVelas: View {
    var body: some View {
        Canvas { context, size in
            NocheDeVelas.draw(in: &context, size: size)
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }

    private static func draw(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        guard w > 0, h > 0 else { return }
        let full = Path(CGRect(origin: .zero, size: size))

        // Night, darkest up top, a shade warmer toward the floor.
        context.fill(full, with: .linearGradient(
            Gradient(colors: [Noche.skyTop, Noche.skyMid, Noche.skyLow]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: h)
        ))

        // A faint morado haze in the upper corner.
        let hazeR = w * 0.95
        let hazeCenter = CGPoint(x: w * 0.12, y: h * 0.1)
        context.fill(
            Path(ellipseIn: CGRect(x: hazeCenter.x - hazeR, y: hazeCenter.y - hazeR, width: hazeR * 2, height: hazeR * 2)),
            with: .radialGradient(
                Gradient(colors: [Noche.haze.opacity(0.14), Noche.haze.opacity(0.05), Noche.haze.opacity(0)]),
                center: hazeCenter, startRadius: 0, endRadius: hazeR
            )
        )

        // Candlelight from the ofrenda: a wide, low ellipse of warm light centered on the floor.
        let glowR = w * 1.15
        var glow = context
        glow.translateBy(x: w / 2, y: h)
        glow.scaleBy(x: 1, y: 0.7)
        let stops: [Gradient.Stop] = [
            Gradient.Stop(color: Noche.candleGlow.opacity(0.24), location: 0),
            Gradient.Stop(color: Noche.candleGlow.opacity(0.17), location: 0.14),
            Gradient.Stop(color: Noche.emberGlow.opacity(0.09), location: 0.38),
            Gradient.Stop(color: Noche.rosaGlow.opacity(0.035), location: 0.68),
            Gradient.Stop(color: Noche.rosaGlow.opacity(0), location: 1),
        ]
        glow.fill(
            Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(Gradient(stops: stops), center: CGPoint(x: 0, y: 0), startRadius: 0, endRadius: glowR)
        )

        // A fine grain, like the limewash's grit by day, in lavender.
        var rng = NocheRandom(state: 0x0F_DA_DE_17)
        let grains = Int(w * h / 1100)
        for _ in 0..<grains {
            let d = rng.range(0.6, 1.5)
            let rect = CGRect(x: rng.range(0, w), y: rng.range(0, h), width: d, height: d)
            context.fill(Path(ellipseIn: rect), with: .color(Color(hex6: 0xC9B6F0).opacity(Double(rng.range(0.025, 0.06)))))
        }

        // A few sparks drifting up from the candles.
        for _ in 0..<18 {
            let d = rng.range(1.0, 2.2)
            let y = h - rng.range(40, h * 0.3)
            let rect = CGRect(x: rng.range(0, w), y: y, width: d, height: d)
            context.fill(Path(ellipseIn: rect), with: .color(Noche.marigoldLight.opacity(Double(rng.range(0.12, 0.32)))))
        }
    }
}

// MARK: - The edge of the ofrenda

/// A veladora standing in the flowers: where it stands, where its glass begins, how wide it is,
/// and the colors of its glass from the lit top down.
private struct Vela {
    let x: CGFloat
    let top: CGFloat
    let width: CGFloat
    let glass: [Color]
}

/// One ring of petals in a cempasúchil head, in fractions of the head's radius.
private struct PetalRing {
    let count: Int
    let distance: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
}

private enum Ofrenda {
    /// The veladoras along the edge, laid out for a band this wide. `reach` is the band's top.
    static func velas(width: CGFloat, reach: CGFloat) -> [Vela] {
        let spots: [CGFloat] = [0.09, 0.36, 0.65, 0.92]
        let lifts: [CGFloat] = [1, -3, 2, -2]
        let cream: [Color] = [Color(hex6: 0xFFE6B0), Color(hex6: 0xF2B45A), Color(hex6: 0xB8692A)]
        let rosa: [Color] = [Color(hex6: 0xFFA3D0), Color(hex6: 0xE4007C), Color(hex6: 0x7A0042)]
        let morado: [Color] = [Color(hex6: 0xD8B8FF), Color(hex6: 0x8E4BC6), Color(hex6: 0x3E1D5A)]
        let glasses: [[Color]] = [cream, rosa, cream, morado]
        var result: [Vela] = []
        for i in 0..<spots.count {
            let x = (width * spots[i]).rounded()
            let w: CGFloat = i.isMultiple(of: 2) ? 15 : 17
            result.append(Vela(x: x, top: reach - 9 + lifts[i], width: w, glass: glasses[i]))
        }
        return result
    }

    /// Everything along the edge but the flames: the ofrenda's cloth, a back row of flowers,
    /// the veladoras' glass, leaves, and a front row of flowers.
    static func draw(in context: inout GraphicsContext, size: CGSize, reach: CGFloat) {
        let w = size.width
        let h = size.height
        guard w > 0, h > reach else { return }
        var rng = NocheRandom(state: 0xCE3_FA50)

        // The ofrenda's top tier, covered in a morado cloth with a rosa trim.
        let clothTop = reach + 10
        context.fill(
            Path(CGRect(x: 0, y: clothTop, width: w, height: h - clothTop)),
            with: .linearGradient(
                Gradient(colors: [Noche.clothTop, Noche.clothBottom]),
                startPoint: CGPoint(x: 0, y: clothTop),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        context.fill(Path(CGRect(x: 0, y: clothTop, width: w, height: 2)), with: .color(Noche.rosa.opacity(0.8)))

        // Loose petals on the cloth, below the flowers.
        for _ in 0..<Int(w / 16) {
            let p = CGPoint(x: rng.range(0, w), y: rng.range(reach + 30, h))
            petal(at: p, scale: rng.range(0.7, 1.1), angle: rng.range(0, .pi * 2), color: Noche.marigold.opacity(0.75), in: &context)
        }

        // Back row: smaller heads, a little in shadow.
        var x: CGFloat = -4
        while x < w + 12 {
            let r = rng.range(8.5, 10.5)
            let c = CGPoint(x: x + rng.range(-3, 3), y: reach + 8 + rng.range(-2.5, 2.5))
            marigold(at: c, radius: r, spin: rng.range(0, .pi * 2), in: &context)
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Noche.night.opacity(0.3)))
            x += 17
        }

        // The veladoras stand among the flowers.
        for vela in velas(width: w, reach: reach) {
            veladora(vela, bottom: h, in: &context)
        }

        // Leaves between the heads.
        x = 4
        while x < w + 10 {
            let lean = rng.range(-0.9, 0.9)
            let flip: CGFloat = rng.next() < 0.5 ? 0 : CGFloat.pi
            let shade: Color = rng.next() < 0.5 ? Noche.leaf : Noche.leafLight
            var leaf = context
            leaf.translateBy(x: x + rng.range(-4, 4), y: reach + 17 + rng.range(-2, 3))
            leaf.rotate(by: .radians(Double(lean + flip)))
            leaf.fill(Path(ellipseIn: CGRect(x: 2, y: -2.5, width: 14, height: 5)), with: .color(shade))
            x += 13
        }

        // Front row: the full heads, right along the edge.
        x = 4
        while x < w + 12 {
            let r = rng.range(10.5, 13)
            let c = CGPoint(x: x + rng.range(-3, 3), y: reach + 16 + rng.range(-2, 2.5))
            marigold(at: c, radius: r, spin: rng.range(0, .pi * 2), in: &context)
            x += 21
        }
    }

    /// A cempasúchil head: a dark ruff, three rings of ruffled petals, a deep heart.
    static func marigold(at c: CGPoint, radius r: CGFloat, spin: CGFloat, in context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.92, y: c.y - r * 0.92, width: r * 1.84, height: r * 1.84)), with: .color(Noche.marigoldShade))
        let rings: [PetalRing] = [
            PetalRing(count: 14, distance: 0.62, width: 0.36, height: 0.52, color: Noche.marigoldDeep),
            PetalRing(count: 11, distance: 0.40, width: 0.34, height: 0.46, color: Noche.marigold),
            PetalRing(count: 8, distance: 0.19, width: 0.30, height: 0.38, color: Noche.marigoldLight),
        ]
        for k in 0..<rings.count {
            let ring = rings[k]
            let pw = r * ring.width
            let ph = r * ring.height
            for i in 0..<ring.count {
                var p = context
                p.translateBy(x: c.x, y: c.y)
                let turn = Double(spin) + Double(k) * 0.4 + Double(i) * 2 * Double.pi / Double(ring.count)
                p.rotate(by: .radians(turn))
                p.fill(Path(ellipseIn: CGRect(x: -pw / 2, y: -r * ring.distance - ph / 2, width: pw, height: ph)), with: .color(ring.color))
            }
        }
        let heart = r * 0.13
        context.fill(Path(ellipseIn: CGRect(x: c.x - heart, y: c.y - heart, width: heart * 2, height: heart * 2)), with: .color(Noche.marigoldHeart))
    }

    /// A veladora's glass, lit from inside: about three times as tall as it is wide, standing
    /// on the cloth (cut off by the bottom of the band on short screens).
    static func veladora(_ v: Vela, bottom: CGFloat, in context: inout GraphicsContext) {
        let left = v.x - v.width / 2
        let tall = min(v.width * 3, max(bottom - v.top, 0))
        let body = CGRect(x: left, y: v.top, width: v.width, height: tall)
        // Its shadow on the cloth.
        context.fill(Path(ellipseIn: CGRect(x: left - 3, y: v.top + tall - 3, width: v.width + 6, height: 6)), with: .color(Color.black.opacity(0.35)))
        context.fill(
            Path(roundedRect: body, cornerRadius: 2.5),
            with: .linearGradient(
                Gradient(colors: v.glass),
                startPoint: CGPoint(x: v.x, y: v.top),
                endPoint: CGPoint(x: v.x, y: v.top + 34)
            )
        )
        // The rim, the lit pool of wax just under it, and a glint down the glass.
        context.fill(Path(ellipseIn: CGRect(x: left, y: v.top - 1.5, width: v.width, height: 3)), with: .color(Color.white.opacity(0.55)))
        context.fill(Path(ellipseIn: CGRect(x: v.x - v.width * 0.35, y: v.top + 0.5, width: v.width * 0.7, height: 4)), with: .color(Noche.flameCore.opacity(0.7)))
        context.fill(Path(CGRect(x: left + v.width * 0.2, y: v.top + 4, width: 1.2, height: 14)), with: .color(Color.white.opacity(0.3)))
    }

    /// A veladora's flame and the glow around it.
    static func flame(for v: Vela, in context: inout GraphicsContext) {
        let base = v.top - 1
        let tip = base - 13
        let mid = CGPoint(x: v.x, y: base - 6)
        let haloR: CGFloat = 21
        context.fill(
            Path(ellipseIn: CGRect(x: mid.x - haloR, y: mid.y - haloR, width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [Noche.candleGlow.opacity(0.55), Noche.candleGlow.opacity(0.18), Noche.candleGlow.opacity(0)]),
                center: mid, startRadius: 0, endRadius: haloR
            )
        )

        var outer = Path()
        outer.move(to: CGPoint(x: v.x, y: tip))
        outer.addCurve(to: CGPoint(x: v.x, y: base), control1: CGPoint(x: v.x + 5.5, y: tip + 7), control2: CGPoint(x: v.x + 4.5, y: base))
        outer.addCurve(to: CGPoint(x: v.x, y: tip), control1: CGPoint(x: v.x - 4.5, y: base), control2: CGPoint(x: v.x - 5.5, y: tip + 7))
        outer.closeSubpath()
        context.fill(outer, with: .linearGradient(
            Gradient(colors: [Noche.flameTip, Noche.flame, Noche.flameCore]),
            startPoint: CGPoint(x: v.x, y: tip),
            endPoint: CGPoint(x: v.x, y: base)
        ))

        var core = Path()
        core.move(to: CGPoint(x: v.x, y: tip + 5))
        core.addCurve(to: CGPoint(x: v.x, y: base - 0.5), control1: CGPoint(x: v.x + 2.6, y: tip + 9), control2: CGPoint(x: v.x + 2.2, y: base - 0.5))
        core.addCurve(to: CGPoint(x: v.x, y: tip + 5), control1: CGPoint(x: v.x - 2.2, y: base - 0.5), control2: CGPoint(x: v.x - 2.6, y: tip + 9))
        core.closeSubpath()
        context.fill(core, with: .color(Noche.flameCore))

        context.fill(Path(CGRect(x: v.x - 0.6, y: base - 2.5, width: 1.2, height: 3)), with: .color(Noche.wick))
    }

    /// One loose cempasúchil petal.
    static func petal(at p: CGPoint, scale s: CGFloat, angle: CGFloat, color: Color, in context: inout GraphicsContext) {
        var g = context
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        g.fill(Path(ellipseIn: CGRect(x: -2.1 * s, y: -3.8 * s, width: 4.2 * s, height: 7.6 * s)), with: .color(color))
    }
}

/// The flowers, cloth and candle glass: drawn once.
private struct OfrendaFlores: View {
    let reach: CGFloat

    var body: some View {
        Canvas { context, size in
            Ofrenda.draw(in: &context, size: size, reach: reach)
        }
        .drawingGroup()
    }
}

/// Every other veladora's flame (`even` picks which), so the two sets can flicker out of step.
private struct Llamas: View {
    let reach: CGFloat
    let even: Bool

    var body: some View {
        Canvas { context, size in
            let velas = Ofrenda.velas(width: size.width, reach: reach)
            for (i, vela) in velas.enumerated() where i.isMultiple(of: 2) == even {
                Ofrenda.flame(for: vela, in: &context)
            }
        }
        .drawingGroup()
        .blendMode(.screen)
    }
}

/// The edge of the ofrenda along the bottom of the screen, behind the tab bar: a bed of
/// cempasúchil with lit veladoras standing in it. It is given the band's height (the same rule
/// as the guardapolvo by day); the candles and their glow reach a little above it.
struct OfrendaEdge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far above the band the candles and their flames stand.
    private let reach: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                OfrendaFlores(reach: reach)
                flames(even: true)
                flames(even: false)
            }
            .frame(width: geo.size.width, height: geo.size.height + reach)
            .offset(y: -reach)
        }
        .accessibilityHidden(true)
    }

    /// A slow, gentle flicker; none at all with Reduce Motion.
    @ViewBuilder
    private func flames(even: Bool) -> some View {
        let phases: [Double] = even ? [1.0, 0.8, 0.95, 0.86] : [0.88, 1.0, 0.82, 0.97]
        let beat: Double = even ? 0.9 : 1.15
        if reduceMotion {
            Llamas(reach: reach, even: even)
        } else {
            Llamas(reach: reach, even: even)
                .phaseAnimator(phases) { content, phase in
                    content.opacity(phase)
                } animation: { _ in
                    Animation.easeInOut(duration: beat)
                }
        }
    }
}

// MARK: - The mantel under the deck

/// The dark mantel the cards are laid on at night, with a faint camino de pétalos wandering
/// down the middle, faint enough that the headings and cards stay the thing you read.
struct MantelDeOfrenda: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Noche.mantel.opacity(0.88))
            .overlay(
                // No drawingGroup here: the mantel is as tall as the whole deck.
                Canvas { context, size in
                    MantelDeOfrenda.camino(in: &context, size: size)
                }
                .opacity(0.22)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            )
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline, lineWidth: 1.5))
            .accessibilityHidden(true)
    }

    private static func camino(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        guard w > 0, h > 0 else { return }
        var rng = NocheRandom(state: 0xCA_3140)
        let colors: [Color] = [Noche.marigold, Noche.marigold, Noche.marigoldDeep, Noche.marigoldLight, Noche.marigold, Noche.rosa]

        // The path of petals that leads the dead home, wandering down the middle of the cloth.
        var y: CGFloat = 6
        while y < h {
            let along = w / 2 + sin(y / 240) * w * 0.2
            for _ in 0..<2 {
                let p = CGPoint(x: along + rng.range(-26, 26), y: y + rng.range(-6, 6))
                let color = colors[Int(rng.next() * CGFloat(colors.count)) % colors.count]
                Ofrenda.petal(at: p, scale: rng.range(0.7, 1.25), angle: rng.range(0, .pi * 2), color: color, in: &context)
            }
            y += 9
        }

        // A few petals that strayed from the path.
        let strays = Int(w * h / 9000)
        for _ in 0..<strays {
            let p = CGPoint(x: rng.range(0, w), y: rng.range(0, h))
            let color = colors[Int(rng.next() * CGFloat(colors.count)) % colors.count]
            Ofrenda.petal(at: p, scale: rng.range(0.6, 1.0), angle: rng.range(0, .pi * 2), color: color, in: &context)
        }
    }
}
