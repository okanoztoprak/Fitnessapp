import SwiftUI

/// Voortgangsring die bij verschijnen naar zijn waarde toe loopt.
struct Ring: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var color: Color = Theme.accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(shown, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, new in animate(to: new) }
    }

    private func animate(to value: Double) {
        if reduceMotion {
            shown = value
        } else {
            withAnimation(.spring(duration: 0.9, bounce: 0.15)) { shown = value }
        }
    }
}

/// Getal dat bij verschijnen optelt naar zijn waarde.
struct CountUp: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        Text(shown, format: .number)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .accessibilityLabel(Text(value, format: .number))
            .onAppear { animate(to: value) }
            .onChange(of: value) { _, new in animate(to: new) }
    }

    private func animate(to target: Int) {
        if reduceMotion {
            shown = target
        } else {
            withAnimation(.snappy(duration: 0.7)) { shown = target }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Klein label in hoofdletters, bijvoorbeeld "AANBEVOLEN".
struct Tag: View {
    let text: String
    var color: Color = Theme.accent
    var filled = false
    var uppercase = true

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .textCase(uppercase ? .uppercase : nil)
            .tracking(uppercase ? 0.6 : 0)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(filled ? color : Theme.raised, in: Capsule())
            .foregroundStyle(filled ? Theme.onAccent : Color.primary)
    }
}

/// Getal met een label eronder.
struct StatTile: View {
    let value: String
    let label: String
    var symbol: String?
    var tint: Color = Theme.accentText

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(height: 22, alignment: .leading)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(Theme.number(.title2))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Kop boven een groep kaarten.
struct SectionTitle: View {
    let title: String
    var caption: String?

    init(_ title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Eenmalige confettiregen, bijvoorbeeld bij een nieuw record.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    private let duration = 2.2
    private let colors: [Color] = [Theme.accent, Theme.cool, Theme.violet, Theme.warn, .white]

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                Canvas { context, size in
                    guard elapsed < duration else { return }
                    for index in 0..<70 {
                        // Vaste pseudo-willekeur per deeltje, zodat het pad stabiel blijft tussen frames.
                        let seed = Double(index)
                        let x = (sin(seed * 12.9898) * 43_758.5453).truncatingRemainder(dividingBy: 1).magnitude
                        let speed = 0.55 + (cos(seed * 78.233) * 9_301.11).truncatingRemainder(dividingBy: 1).magnitude * 0.6
                        let drift = sin(elapsed * 3 + seed) * 18
                        let y = (elapsed * speed / duration) * (size.height + 40) - 20
                        let rect = CGRect(x: x * size.width + drift, y: y, width: 7, height: 11)
                        var piece = context
                        piece.opacity = max(0, 1 - elapsed / duration)
                        piece.translateBy(x: rect.midX, y: rect.midY)
                        piece.rotate(by: .radians(elapsed * 5 + seed))
                        piece.fill(Path(roundedRect: CGRect(x: -3.5, y: -5.5, width: 7, height: 11), cornerRadius: 2),
                                   with: .color(colors[index % colors.count]))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
        }
    }
}

/// Melding bovenin bij een nieuw record.
struct RecordToast: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(Theme.onAccent)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
