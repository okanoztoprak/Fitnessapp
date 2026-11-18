import SwiftUI
import UIKit

/// RIVO-huisstijl: diep bosgroen, warm wit en fris lime voor de belangrijkste actie. Zachte kaarten, grote ronde cijfers.
enum Theme {
    /// Accent voor vlakken (knoppen, ringen). Tekst erop is altijd `onAccent`.
    /// Fris lime #C5F264.
    static let accent = Color(red: 0.773, green: 0.949, blue: 0.392)
    /// Diep bosgroen #142522: donkere tekst op lime.
    static let onAccent = Color(red: 0.078, green: 0.145, blue: 0.133)
    /// Accent voor tekst en iconen; in lichte modus donkerder voor contrast.
    static let accentText = dynamic(dark: (0.773, 0.949, 0.392), light: (0.22, 0.40, 0.02))

    /// Donker: bosgroen (#0C1714, kaarten #142522). Licht: warm wit #F5F4EF met witte kaarten.
    static let background = dynamic(dark: (0.047, 0.090, 0.078), light: (0.961, 0.957, 0.937))
    static let card = dynamic(dark: (0.078, 0.145, 0.133), light: (1, 1, 1))
    /// Velden, chips en zachte knoppen; licht is het zachte grijs #DCE3DC. In donker lichter dan het glas,
    /// anders vallen ze weg in het groen.
    static let raised = dynamic(dark: (0.176, 0.282, 0.259), light: (0.863, 0.890, 0.863))

    /// Signaalkleuren voor tekst, iconen, ringen en balken. In lichte modus dieper,
    /// zodat tekst minstens 4,5:1 haalt op een witte kaart.
    static let good = dynamic(dark: (0.20, 0.80, 0.50), light: (0.04, 0.48, 0.26))
    static let warn = dynamic(dark: (1.0, 0.66, 0.15), light: (0.66, 0.36, 0.0))
    static let bad = dynamic(dark: (1.0, 0.36, 0.38), light: (0.76, 0.12, 0.16))
    /// Hemelsblauw #8BC9E8: water en herstel.
    static let cool = dynamic(dark: (0.545, 0.788, 0.910), light: (0.039, 0.416, 0.600))
    /// Koraal #F28B74: kleine accenten voor voeding.
    static let coral = dynamic(dark: (0.949, 0.545, 0.455), light: (0.710, 0.263, 0.169))
    static let violet = dynamic(dark: (0.62, 0.48, 1.0), light: (0.40, 0.24, 0.84))

    /// Felle vlakken met zwarte tekst erop (`onAccent`), in beide modi gelijk.
    enum Fill {
        static let good = Color(red: 0.20, green: 0.80, blue: 0.50)
        static let warn = Color(red: 1.0, green: 0.66, blue: 0.15)
        static let cool = Color(red: 0.545, green: 0.788, blue: 0.910)
        static let coral = Color(red: 0.949, green: 0.545, blue: 0.455)
        static let violet = Color(red: 0.62, green: 0.48, blue: 1.0)
    }

    /// Woordmerk: bosgroen op licht, warm wit op donker.
    static let ink = dynamic(dark: (0.961, 0.957, 0.937), light: (0.078, 0.145, 0.133))

    /// Wit symbool op een gekleurde icoontegel.
    static let onSignal = Color.white

    /// Deelkaarten worden als afbeelding gedeeld en zijn altijd donker, los van de modus van het toestel.
    enum Share {
        static let background = LinearGradient(colors: [Color(red: 0.106, green: 0.188, blue: 0.169),
                                                        Color(red: 0.047, green: 0.090, blue: 0.078)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
        static let text = Color.white
        static let muted = Color.white.opacity(0.6)
    }

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
            .glassSurface(fill: fill, cornerRadius: Theme.corner)
    }
}

private struct GlassSurface: ViewModifier {
    var fill: Color
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            // Liquid Glass zoals iOS het zelf gebruikt, licht getint met de kaartkleur zodat tekst leesbaar blijft.
            content.glassEffect(.regular.tint(fill.opacity(0.55)), in: shape)
        } else {
            content
                .background(fill.opacity(0.7), in: shape)
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

/// Zachte merkkleuren achter de inhoud; het glas van de kaarten breekt dit licht.
private struct BrandBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Theme.background
                Circle().fill(Theme.accent.opacity(0.22))
                    .frame(width: size.width * 0.9).blur(radius: 90)
                    .offset(x: -size.width * 0.35, y: -size.height * 0.32)
                Circle().fill(Theme.Fill.cool.opacity(0.18))
                    .frame(width: size.width * 0.8).blur(radius: 100)
                    .offset(x: size.width * 0.4, y: size.height * 0.05)
                Circle().fill(Theme.Fill.coral.opacity(0.12))
                    .frame(width: size.width * 0.7).blur(radius: 110)
                    .offset(x: -size.width * 0.2, y: size.height * 0.4)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Glazen ondergrond met afgeronde hoeken, voor kaarten en tegels.
    func glassSurface(fill: Color = Theme.card, cornerRadius: CGFloat = Theme.corner) -> some View {
        modifier(GlassSurface(fill: fill, cornerRadius: cornerRadius))
    }

    func card(padding: CGFloat = 18, fill: Color = Theme.card) -> some View {
        modifier(CardStyle(padding: padding, fill: fill))
    }

    /// Standaardachtergrond voor een scrollend scherm met kaarten.
    func screenBackground() -> some View {
        background(BrandBackdrop())
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
            .foregroundStyle(Theme.accentText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            // Lime waas en een dunne rand: leest als knop, ook op een groene glazen kaart.
            .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.accentText.opacity(0.35), lineWidth: 1))
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
