import PowerCore
import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.45, blue: 0.05)
    static let energy = Color(red: 1.0, green: 0.82, blue: 0.1)
    static let outlineWidth: CGFloat = 2.5
    static let corner: CGFloat = 18

    static func display(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .rounded).weight(.black).italic()
    }
}

extension Stage {
    var auraColor: Color {
        switch self {
        case .rookie: Color(red: 0.55, green: 0.6, blue: 0.68)
        case .kindled: Color(red: 1.0, green: 0.5, blue: 0.1)
        case .awakened: Color(red: 1.0, green: 0.8, blue: 0.1)
        case .ascended: Color(red: 0.15, green: 0.75, blue: 0.95)
        case .stormforged: Color(red: 0.55, green: 0.4, blue: 1.0)
        case .limitBreaker: Color(red: 1.0, green: 0.2, blue: 0.35)
        case .mythic: Color(red: 0.2, green: 0.95, blue: 0.7)
        }
    }
}

/// Kaart met dikke outline en een harde, cel-shaded schaduw.
struct ComicCard: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Color.primary).offset(x: 3, y: 4)
                shape.fill(Color(.secondarySystemGroupedBackground))
                if let tint { shape.fill(tint.opacity(0.12)) }
                shape.strokeBorder(Color.primary, lineWidth: Theme.outlineWidth)
            }
            .padding(.trailing, 3)
            .padding(.bottom, 4)
    }
}

extension View {
    func comicCard(tint: Color? = nil) -> some View { modifier(ComicCard(tint: tint)) }
}

struct ComicButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                shape.fill(color)
                shape.strokeBorder(Color.primary, lineWidth: Theme.outlineWidth)
            }
            .offset(x: pressed ? 2 : 0, y: pressed ? 3 : 0)
            .background { shape.fill(Color.primary).offset(x: 2, y: 3) }
            .padding(.trailing, 2)
            .padding(.bottom, 3)
            .animation(.snappy(duration: 0.12), value: pressed)
    }
}

/// Getal met de naam van de eenheid eronder.
struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct EnergyBar: View {
    let fraction: Double
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
                Capsule().strokeBorder(Color.primary, lineWidth: 2)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}
