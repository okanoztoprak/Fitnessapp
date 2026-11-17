import Foundation

public enum MainLift: String, Sendable, CaseIterable {
    case squat, bench, deadlift, overheadPress, row

    /// e1RM / lichaamsgewicht dat als "elite" telt (man). Vrouwen: × 0,7.
    public var eliteRatio: Double {
        switch self {
        case .squat: 2.0
        case .bench: 1.5
        case .deadlift: 2.5
        case .overheadPress: 1.0
        case .row: 1.25
        }
    }
}

public enum StrengthLevel: Int, Sendable, CaseIterable, Comparable {
    case beginner, novice, intermediate, advanced, elite

    /// Ondergrens als fractie van de elite-standaard.
    public var threshold: Double {
        switch self {
        case .beginner: 0
        case .novice: 0.35
        case .intermediate: 0.5
        case .advanced: 0.7
        case .elite: 0.9
        }
    }

    public var next: StrengthLevel? { StrengthLevel(rawValue: rawValue + 1) }

    public static func < (lhs: StrengthLevel, rhs: StrengthLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Krachtniveau per lift: geschatte 1RM ten opzichte van lichaamsgewicht.
public enum StrengthStandards {
    public static func eliteE1RM(bodyWeightKg: Double, lift: MainLift, sex: Sex) -> Double {
        bodyWeightKg * lift.eliteRatio * (sex == .female ? 0.7 : 1.0)
    }

    /// 0 = niets, 1 = elite. Begrensd op 1,2.
    public static func fraction(e1rm: Double, bodyWeightKg: Double, lift: MainLift, sex: Sex) -> Double {
        guard e1rm > 0, bodyWeightKg > 0 else { return 0 }
        return min(e1rm / eliteE1RM(bodyWeightKg: bodyWeightKg, lift: lift, sex: sex), 1.2)
    }

    public static func level(fraction: Double) -> StrengthLevel {
        StrengthLevel.allCases.last { fraction >= $0.threshold } ?? .beginner
    }

    /// Voortgang binnen het huidige niveau, 0...1.
    public static func progressToNext(fraction: Double) -> Double {
        let current = level(fraction: fraction)
        guard let next = current.next else { return 1 }
        return min(1, max(0, (fraction - current.threshold) / (next.threshold - current.threshold)))
    }

    /// e1RM die nodig is voor het volgende niveau; `nil` op het hoogste niveau.
    public static func nextTarget(fraction: Double, bodyWeightKg: Double, lift: MainLift, sex: Sex) -> Double? {
        guard let next = level(fraction: fraction).next, bodyWeightKg > 0 else { return nil }
        return next.threshold * eliteE1RM(bodyWeightKg: bodyWeightKg, lift: lift, sex: sex)
    }
}
