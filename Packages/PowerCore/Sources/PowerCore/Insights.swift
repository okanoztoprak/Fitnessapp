import Foundation

// MARK: - Herstel per spiergroep

public enum MuscleRecovery {
    /// Uren tot volledig herstel: 48 uur als basis, langer na veel sets, hooguit 96 uur.
    public static func hoursToRecover(sets: Int) -> Double {
        min(96, 48 + Double(max(0, sets - 4)) * 6)
    }

    /// 0 = net getraind, 1 = volledig hersteld. Nooit getraind telt als hersteld.
    public static func fraction(hoursSinceTrained hours: Double?, sets: Int) -> Double {
        guard let hours else { return 1 }
        return min(1, max(0, hours / hoursToRecover(sets: sets)))
    }
}

// MARK: - Trainingsbelasting

public enum TrainingLoad {
    public enum Status: String, Sendable {
        /// Nog geen vier weken historie om mee te vergelijken.
        case building
        case low, steady, high
    }

    /// Sets van de laatste 7 dagen ten opzichte van het weekgemiddelde van de 28 dagen daarvoor.
    public static func ratio(last7Days: Double, previous28Days: Double) -> Double? {
        guard previous28Days > 0 else { return nil }
        return last7Days / (previous28Days / 4)
    }

    public static func status(ratio: Double?) -> Status {
        guard let ratio else { return .building }
        if ratio < 0.8 { return .low }
        return ratio > 1.3 ? .high : .steady
    }
}

// MARK: - Gereedheid

public struct Readiness: Sendable, Equatable {
    public enum Band: String, Sendable { case low, moderate, high }

    public var score: Int
    public var band: Band

    public init(score: Int) {
        self.score = min(100, max(0, score))
        self.band = self.score >= 67 ? .high : (self.score >= 34 ? .moderate : .low)
    }
}

public enum ReadinessCalculator {
    /// Eén dagscore uit het gemiddelde spierherstel, met aftrek als de belasting deze week
    /// duidelijk boven het eigen gemiddelde ligt en bij minder dan 7 uur slaap.
    /// Zonder trainingsdata telt alleen de slaap.
    public static func readiness(muscleRecovery: [Double], loadRatio: Double?,
                                 sleepHours: Double? = nil) -> Readiness {
        var score = 100.0
        if !muscleRecovery.isEmpty {
            score = muscleRecovery.reduce(0, +) / Double(muscleRecovery.count) * 100
        }
        if let loadRatio, loadRatio > 1.3 {
            score -= min(25, (loadRatio - 1.3) * 50)
        }
        score -= sleepPenalty(hours: sleepHours)
        return Readiness(score: Int(score.rounded()))
    }

    /// 6 punten aftrek per uur onder de 7 uur, hooguit 20.
    public static func sleepPenalty(hours: Double?) -> Double {
        guard let hours, hours > 0, hours < 7 else { return 0 }
        return min(20, (7 - hours) * 6)
    }
}

// MARK: - Weekreeks

public enum WeekStreak {
    /// Aantal opeenvolgende kalenderweken met minstens één training.
    /// Een lopende week zonder training breekt de reeks nog niet.
    public static func current(workoutDays: [Date], today: Date, calendar: Calendar = .current) -> Int {
        let weeks = Set(workoutDays.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return 0 }
        if !weeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var count = 0
        while weeks.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
