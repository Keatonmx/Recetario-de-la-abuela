import SwiftUI
import UIKit

// MARK: - Papel picado

/// One cut-paper flag, drawn in a 60 × 68 box with an even-odd fill so the
/// circle and diamonds come out as holes.
struct FlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 60
        let sy = rect.height / 68
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(0, 0))
        path.addLine(to: p(60, 0))
        path.addLine(to: p(60, 60))
        let zigzag: [(CGFloat, CGFloat)] = [
            (52.5, 68), (45, 60), (37.5, 68), (30, 60), (22.5, 68), (15, 60), (7.5, 68), (0, 60)
        ]
        for (x, y) in zigzag { path.addLine(to: p(x, y)) }
        path.closeSubpath()

        path.addEllipse(in: CGRect(origin: p(21, 18), size: CGSize(width: 18 * sx, height: 18 * sy)))

        // Diamonds: center x, center y, half width, half height.
        let diamonds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (12, 14, 5, 6), (48, 14, 5, 6), (12, 40, 5, 6), (48, 40, 5, 6),
            (30, 46.5, 4, 4.5), (30, 8.5, 3, 3.5)
        ]
        for (cx, cy, hw, hh) in diamonds {
            path.move(to: p(cx, cy - hh))
            path.addLine(to: p(cx + hw, cy))
            path.addLine(to: p(cx, cy + hh))
            path.addLine(to: p(cx - hw, cy))
            path.closeSubpath()
        }
        return path
    }
}

struct PapelPicado: View {
    var count = 10
    private let colors: [Color] = [.chile, .maiz, .talavera, .rosa, .nopal]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary)
                .frame(height: 2)
            HStack(alignment: .top, spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    FlagShape()
                        .fill(colors[i % colors.count], style: FillStyle(eoFill: true))
                        .aspectRatio(60.0 / 68.0, contentMode: .fit)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Small pieces

struct Chip: View {
    let title: String
    let isOn: Bool
    var onColor: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Color(.systemBackground) : Color.primary)
                .background(Capsule().fill(isOn ? onColor : Color.card))
                .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: isOn ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct HeatMeter: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Capsule()
                    .fill(i <= level ? Color.chile : Color(.tertiarySystemFill))
                    .frame(width: 7, height: 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heat \(level) of 5")
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.display(.title2))
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct InfoBox<Content: View>: View {
    let label: String
    let background: Color
    let content: Content

    init(label: String, background: Color, @ViewBuilder content: () -> Content) {
        self.label = label
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(background))
    }
}

struct NoteBox: View {
    let text: String

    var body: some View {
        Text(text)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.maizSoft))
    }
}
