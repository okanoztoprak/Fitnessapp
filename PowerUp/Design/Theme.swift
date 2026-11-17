import SwiftUI
import UIKit

/// Designsysteem: donker als standaard, één felle accentkleur, zachte kaarten, grote ronde cijfers.
enum Theme {
    /// Accent voor vlakken (knoppen, ringen). Tekst erop is altijd `onAccent`.
    static let accent = Color(red: 0.80, green: 0.98, blue: 0.27)
    static let onAccent = Color.black
    /// Accent voor tekst en iconen; in lichte modus donkerder voor contrast.
    static let accentText = dynamic(dark: (0.80, 0.98, 0.27), light: (0.22, 0.40, 0.02))

    static let background = dynamic(dark: (0.035, 0.035, 0.045), light: (0.95, 0.95, 0.97))
    static let card = dynamic(dark: (0.105, 0.105, 0.125), light: (1, 1, 1))
    static let raised = dynamic(dark: (0.17, 0.17, 0.195), light: (0.92, 0.92, 0.945))

    static let good = Color(red: 0.20, green: 0.80, blue: 0.50)
    static let warn = Color(red: 1.0, green: 0.66, blue: 0.15)
    static let bad = Color(red: 1.0, green: 0.36, blue: 0.38)
    static let cool = Color(red: 0.32, green: 0.66, blue: 1.0)
    static let violet = Color(red: 0.62, green: 0.48, blue: 1.0)

    static let corner: CGFloat = 24

    static func number(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }

    private static func dynamic(dark: (Double, Double, Double), light: (Double, Double, Double)) -> Color {
        Color(UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}

private struct CardStyle: ViewModifier {
    var padding: CGFloat
    var fill: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 18, fill: Color = Theme.card) -> some View {
        modifier(CardStyle(padding: padding, fill: fill))
    }

    /// Standaardachtergrond voor een scrollend scherm met kaarten.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Laat een kaart licht indrukken bij aanraken.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
