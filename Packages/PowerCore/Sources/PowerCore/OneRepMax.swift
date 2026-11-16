import Foundation

public enum OneRepMax {
    public enum Formula: String, Sendable, CaseIterable {
        case epley, brzycki
    }

    /// Boven dit aantal reps is een 1RM-schatting te onbetrouwbaar.
    public static let maxReps = 10

    /// Geschatte 1RM, of `nil` als de set niet bruikbaar is voor een schatting.
    public static func estimate(weight: Double, reps: Int, formula: Formula = .epley) -> Double? {
        guard weight > 0, reps >= 1, reps <= maxReps else { return nil }
        if reps == 1 { return weight }
        switch formula {
        case .epley: return weight * (1 + Double(reps) / 30)
        case .brzycki: return weight * 36 / (37 - Double(reps))
        }
    }
}
