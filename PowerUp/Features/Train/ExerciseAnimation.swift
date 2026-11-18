import SwiftUI

/// Geanimeerd figuur dat een bewegingspatroon voordoet. Elk patroon is twee houdingen
/// (begin en eind); de view loopt er vloeiend tussen heen en weer.
struct ExerciseAnimation: View {
    let pattern: MovementPattern
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            // Zacht in en uit, net als een rustig uitgevoerde herhaling.
            let phase = reduceMotion ? 0.5 : (1 - cos(seconds * 2 * .pi / pattern.duration)) / 2
            Canvas { context, size in
                let pose = Pose.mix(pattern.start, pattern.end, phase)
                draw(pose, in: &context, size: size)
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("Animatie van de uitvoering"))
    }

    private func draw(_ pose: Pose, in context: inout GraphicsContext, size: CGSize) {
        // Tekencoördinaten lopen van 0 tot 200 breed en 140 hoog.
        let scale = min(size.width / 200, size.height / 140)
        let offset = CGPoint(x: (size.width - 200 * scale) / 2, y: (size.height - 140 * scale) / 2)
        func p(_ point: CGPoint) -> CGPoint { CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale) }
        let limb = StrokeStyle(lineWidth: 9 * scale, lineCap: .round, lineJoin: .round)
        let ink = GraphicsContext.Shading.color(Theme.ink)
        let faint = GraphicsContext.Shading.color(Theme.ink.opacity(0.35))

        // Vloer en eventueel een bank.
        var floor = Path()
        floor.move(to: p(CGPoint(x: 10, y: 132)))
        floor.addLine(to: p(CGPoint(x: 190, y: 132)))
        context.stroke(floor, with: faint, style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
        if let bench = pattern.bench {
            let rect = CGRect(x: bench.minX, y: bench.minY, width: bench.width, height: bench.height)
            context.fill(Path(roundedRect: CGRect(origin: p(rect.origin),
                                                  size: CGSize(width: rect.width * scale, height: rect.height * scale)),
                              cornerRadius: 3 * scale), with: faint)
            var leg = Path()
            leg.move(to: p(CGPoint(x: bench.midX, y: bench.maxY)))
            leg.addLine(to: p(CGPoint(x: bench.midX, y: 132)))
            context.stroke(leg, with: faint, style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
        }

        // Gewicht in lime: een schijf van opzij gezien, met de stang als stip. Achter het lichaam getekend.
        let anchor = pattern.weightAnchor(pose)
        let plate = CGRect(x: anchor.x - 13, y: anchor.y - 13, width: 26, height: 26)
        context.fill(Path(ellipseIn: CGRect(origin: p(plate.origin), size: CGSize(width: 26 * scale, height: 26 * scale))),
                     with: .color(Theme.accent))
        let bar = CGRect(x: anchor.x - 4, y: anchor.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: CGRect(origin: p(bar.origin), size: CGSize(width: 8 * scale, height: 8 * scale))),
                     with: .color(Theme.onAccent))

        // Lichaam: achterste ledematen iets lichter, zodat het figuur diepte krijgt.
        func chain(_ points: [CGPoint], _ shading: GraphicsContext.Shading) {
            var path = Path()
            path.move(to: p(points[0]))
            for point in points.dropFirst() { path.addLine(to: p(point)) }
            context.stroke(path, with: shading, style: limb)
        }
        chain([pose.hip, pose.knee, pose.ankle, pose.toe], ink)
        chain([pose.hip, pose.shoulder], ink)
        chain([pose.shoulder, pose.elbow, pose.hand], ink)
        let head = CGRect(x: pose.head.x - 9, y: pose.head.y - 9, width: 18, height: 18)
        context.fill(Path(ellipseIn: CGRect(origin: p(head.origin), size: CGSize(width: 18 * scale, height: 18 * scale))),
                     with: ink)

    }
}

/// Houding van het figuur, van opzij gezien (naar rechts kijkend).
struct Pose {
    var head, shoulder, elbow, hand, hip, knee, ankle, toe: CGPoint

    static func mix(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
        func m(_ x: CGPoint, _ y: CGPoint) -> CGPoint { CGPoint(x: x.x + (y.x - x.x) * t, y: x.y + (y.y - x.y) * t) }
        return Pose(head: m(a.head, b.head), shoulder: m(a.shoulder, b.shoulder), elbow: m(a.elbow, b.elbow),
                    hand: m(a.hand, b.hand), hip: m(a.hip, b.hip), knee: m(a.knee, b.knee),
                    ankle: m(a.ankle, b.ankle), toe: m(a.toe, b.toe))
    }
}

/// Bewegingspatronen; elke oefening valt onder één patroon.
enum MovementPattern {
    case squat, benchPress

    /// Seconden per volledige herhaling (heen en terug).
    var duration: Double { 2.6 }

    /// Waar het gewicht zit: bij de squat op de bovenrug achter de nek, anders in de handen.
    func weightAnchor(_ pose: Pose) -> CGPoint {
        switch self {
        case .squat: CGPoint(x: pose.shoulder.x - 7, y: pose.shoulder.y - 3)
        case .benchPress: pose.hand
        }
    }

    var bench: CGRect? {
        switch self {
        case .squat: nil
        case .benchPress: CGRect(x: 40, y: 98, width: 110, height: 8)
        }
    }

    var start: Pose {
        switch self {
        case .squat:
            Pose(head: CGPoint(x: 101, y: 22), shoulder: CGPoint(x: 99, y: 40), elbow: CGPoint(x: 88, y: 52),
                 hand: CGPoint(x: 96, y: 38), hip: CGPoint(x: 98, y: 82), knee: CGPoint(x: 101, y: 107),
                 ankle: CGPoint(x: 99, y: 130), toe: CGPoint(x: 113, y: 131))
        case .benchPress:
            Pose(head: CGPoint(x: 48, y: 88), shoulder: CGPoint(x: 64, y: 91), elbow: CGPoint(x: 66, y: 66),
                 hand: CGPoint(x: 67, y: 42), hip: CGPoint(x: 122, y: 92), knee: CGPoint(x: 150, y: 80),
                 ankle: CGPoint(x: 154, y: 130), toe: CGPoint(x: 166, y: 131))
        }
    }

    var end: Pose {
        switch self {
        case .squat:
            Pose(head: CGPoint(x: 112, y: 56), shoulder: CGPoint(x: 102, y: 71), elbow: CGPoint(x: 90, y: 82),
                 hand: CGPoint(x: 99, y: 69), hip: CGPoint(x: 76, y: 104), knee: CGPoint(x: 120, y: 106),
                 ankle: CGPoint(x: 99, y: 130), toe: CGPoint(x: 113, y: 131))
        case .benchPress:
            Pose(head: CGPoint(x: 48, y: 88), shoulder: CGPoint(x: 64, y: 91), elbow: CGPoint(x: 56, y: 92),
                 hand: CGPoint(x: 72, y: 76), hip: CGPoint(x: 122, y: 92), knee: CGPoint(x: 150, y: 80),
                 ankle: CGPoint(x: 154, y: 130), toe: CGPoint(x: 166, y: 131))
        }
    }

    static func pattern(for slug: String) -> MovementPattern? {
        switch slug {
        case "squat", "front-squat", "goblet-squat", "hack-squat", "bodyweight-squat": .squat
        case "bench-press", "incline-bench-press", "decline-bench-press", "close-grip-bench-press",
             "db-bench-press", "db-incline-press", "machine-chest-press": .benchPress
        default: nil
        }
    }
}
