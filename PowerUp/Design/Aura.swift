import SwiftUI

/// Speed lines vanuit het midden, zoals in een actieframe.
struct SpeedLines: Shape {
    var count: Int = 28
    var innerRadius: CGFloat = 0.55

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = max(rect.width, rect.height) * 0.75
        let inner = min(rect.width, rect.height) / 2 * innerRadius
        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
            // Wisselende lengte en dikte geeft een getekend effect.
            let spread: CGFloat = index.isMultiple(of: 3) ? 0.035 : 0.018
            let start = inner * (index.isMultiple(of: 2) ? 1.0 : 1.25)
            path.move(to: point(center, start, angle))
            path.addLine(to: point(center, outer, angle - spread))
            path.addLine(to: point(center, outer, angle + spread))
            path.closeSubpath()
        }
        return path
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

/// Pulserende aura in de kleur van het huidige stadium.
struct AuraView: View {
    let color: Color
    var intensity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        ZStack {
            SpeedLines()
                .fill(color.opacity(0.28 * intensity))
                .rotationEffect(.degrees(pulsing ? 8 : 0))
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.9), color.opacity(0.35), .clear],
                                     center: .center, startRadius: 4, endRadius: 150))
                .scaleEffect(pulsing ? 1.08 : 0.94)
                .blur(radius: 14)
        }
        // Zachte uitloop naar de randen; een harde clip geeft een zichtbare rechthoek.
        .mask {
            EllipticalGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

/// "Scanner": telt omhoog naar de waarde.
struct ScannerNumber: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        Text(shown, format: .number.grouping(.never))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .accessibilityLabel(Text(value, format: .number))
            .task(id: value) { await run() }
    }

    private func run() async {
        guard !reduceMotion, shown != value else {
            shown = value
            return
        }
        let start = shown
        let steps = 28
        for step in 1...steps {
            // Ease-out: snel beginnen, rustig uitkomen.
            let t = 1 - pow(1 - Double(step) / Double(steps), 3)
            shown = start + Int((Double(value - start) * t).rounded())
            try? await Task.sleep(for: .milliseconds(35))
            if Task.isCancelled { return }
        }
        shown = value
    }
}

/// Full-screen aura-burst bij een nieuw record.
struct PRBurstView: View {
    let title: String
    let subtitle: String
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            SpeedLines(count: 40, innerRadius: 0.5)
                .fill(Theme.energy.opacity(0.7))
                .scaleEffect(appeared ? 1.3 : 0.4)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(Theme.energy)
                Text(title)
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .scaleEffect(appeared ? 1 : 0.5)
        }
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
