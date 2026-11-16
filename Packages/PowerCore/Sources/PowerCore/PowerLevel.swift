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

public enum Experience: String, Sendable, CaseIterable {
    case beginner, intermediate, advanced

    var baseline: Int {
        switch self {
        case .beginner: 50
        case .intermediate: 150
        case .advanced: 300
        }
    }
}

public struct PowerLevelInput: Sendable, Equatable {
    public var bodyWeightKg: Double
    public var sex: Sex
    public var experience: Experience
    public var liftE1RMs: [MainLift: Double]
    public var sessionsLast28Days: Int
    public var plannedSessionsPerWeek: Int
    public var cardioMinutesPerWeek: Double

    public init(bodyWeightKg: Double, sex: Sex, experience: Experience,
                liftE1RMs: [MainLift: Double] = [:], sessionsLast28Days: Int = 0,
                plannedSessionsPerWeek: Int = 3, cardioMinutesPerWeek: Double = 0) {
        self.bodyWeightKg = bodyWeightKg
        self.sex = sex
        self.experience = experience
        self.liftE1RMs = liftE1RMs
        self.sessionsLast28Days = sessionsLast28Days
        self.plannedSessionsPerWeek = plannedSessionsPerWeek
        self.cardioMinutesPerWeek = cardioMinutesPerWeek
    }
}

public struct PowerLevelResult: Sendable, Equatable {
    public var strength: Int
    public var consistency: Int
    public var conditioning: Int
    public var baseline: Int
    public var total: Int { min(9999, strength + consistency + conditioning + baseline) }
    public var stage: Stage { Stage.stage(forPowerLevel: total) }
}

public enum Stage: String, Sendable, CaseIterable {
    case rookie, kindled, awakened, ascended, stormforged, limitBreaker, mythic

    public var threshold: Int {
        switch self {
        case .rookie: 0
        case .kindled: 500
        case .awakened: 1500
        case .ascended: 3000
        case .stormforged: 4500
        case .limitBreaker: 6500
        case .mythic: 8500
        }
    }

    public var next: Stage? {
        let all = Stage.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    public static func stage(forPowerLevel value: Int) -> Stage {
        allCases.last { value >= $0.threshold } ?? .rookie
    }
}

public enum PowerLevelCalculator {
    public static let formulaVersion = 1
    public static let maxStrength = 6000.0
    public static let maxConsistency = 2500.0
    public static let maxConditioning = 1200.0

    public static func calculate(_ input: PowerLevelInput) -> PowerLevelResult {
        var strength = 0.0
        if input.bodyWeightKg > 0 {
            let sexFactor = input.sex == .female ? 0.7 : 1.0
            let scores = MainLift.allCases.map { lift -> Double in
                guard let e1rm = input.liftE1RMs[lift], e1rm > 0 else { return 0 }
                let ratio = e1rm / input.bodyWeightKg
                return min(ratio / (lift.eliteRatio * sexFactor), 1)
            }
            strength = scores.reduce(0, +) / Double(scores.count) * maxStrength
        }
        let planned = Double(max(input.plannedSessionsPerWeek, 1) * 4)
        // Meer trainen dan gepland levert niets extra's op.
        let adherence = min(Double(max(input.sessionsLast28Days, 0)) / planned, 1)
        let cardio = min(max(input.cardioMinutesPerWeek, 0) / 150, 1)
        return PowerLevelResult(
            strength: Int(strength.rounded()),
            consistency: Int((adherence * maxConsistency).rounded()),
            conditioning: Int((cardio * maxConditioning).rounded()),
            baseline: input.experience.baseline
        )
    }
}
