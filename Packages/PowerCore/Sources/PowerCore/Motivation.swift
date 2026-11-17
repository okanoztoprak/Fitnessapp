import Foundation

// MARK: - Weekoverzicht

/// De cijfers van één kalenderweek.
public struct WeekSummary: Sendable, Equatable {
    public var workouts: Int
    public var plannedWorkouts: Int
    public var hardSets: Int
    public var volumeKg: Double
    public var records: Int
    /// Dagen met gelogd eten.
    public var loggedFoodDays: Int
    /// Dagen binnen 10% van het caloriedoel.
    public var daysOnTarget: Int
    /// Dagen met minstens 90% van het eiwitdoel.
    public var proteinDays: Int
    public var weighIns: Int
    /// Verandering van het trendgewicht over de week.
    public var trendChangeKg: Double?

    public init(workouts: Int = 0, plannedWorkouts: Int = 3, hardSets: Int = 0, volumeKg: Double = 0, records: Int = 0,
                loggedFoodDays: Int = 0, daysOnTarget: Int = 0, proteinDays: Int = 0, weighIns: Int = 0,
                trendChangeKg: Double? = nil) {
        self.workouts = workouts
        self.plannedWorkouts = plannedWorkouts
        self.hardSets = hardSets
        self.volumeKg = volumeKg
        self.records = records
        self.loggedFoodDays = loggedFoodDays
        self.daysOnTarget = daysOnTarget
        self.proteinDays = proteinDays
        self.weighIns = weighIns
        self.trendChangeKg = trendChangeKg
    }

    public var isEmpty: Bool { workouts == 0 && loggedFoodDays == 0 && weighIns == 0 }
}

public enum Highlight: Sendable, Equatable {
    case planCompleted
    case moreVolume(percent: Int)
    case records(Int)
    case streak(weeks: Int)
    case proteinDays(Int)
}

public enum WeekFocus: Sendable, Equatable {
    case trainMore(missing: Int)
    case logFood
    case hitProtein
    case weighIn
    case keepGoing
}

public struct WeeklyReview: Sendable, Equatable {
    /// 0...100
    public var score: Int
    /// 0...1 per onderdeel.
    public var training: Double
    public var nutrition: Double?
    public var weighIns: Double
    public var highlights: [Highlight]
    public var focus: WeekFocus
    /// Verandering in volume ten opzichte van de week ervoor, als fractie.
    public var volumeChange: Double?
}

/// Eén weekscore die consistentie beloont, geen uitersten: meer trainen dan gepland telt niet extra.
public enum WeeklyReviewer {
    public static func review(current: WeekSummary, previous: WeekSummary?, streakWeeks: Int,
                              tracksNutrition: Bool) -> WeeklyReview {
        let training = current.plannedWorkouts > 0
            ? min(1, Double(current.workouts) / Double(current.plannedWorkouts)) : 0
        let weighIns = min(1, Double(current.weighIns) / 3)
        var nutrition: Double?
        var score: Double
        if tracksNutrition {
            let value = (Double(current.daysOnTarget) / 7 + Double(current.proteinDays) / 7) / 2
            nutrition = min(1, value)
            score = training * 0.5 + (nutrition ?? 0) * 0.3 + weighIns * 0.2
        } else {
            score = training * 0.7 + weighIns * 0.3
        }

        var change: Double?
        if let previous, previous.volumeKg > 0 { change = current.volumeKg / previous.volumeKg - 1 }

        var highlights: [Highlight] = []
        if current.plannedWorkouts > 0, current.workouts >= current.plannedWorkouts { highlights.append(.planCompleted) }
        if let change, change >= 0.05 { highlights.append(.moreVolume(percent: Int((change * 100).rounded()))) }
        if current.records > 0 { highlights.append(.records(current.records)) }
        if streakWeeks >= 2 { highlights.append(.streak(weeks: streakWeeks)) }
        if tracksNutrition, current.proteinDays >= 5 { highlights.append(.proteinDays(current.proteinDays)) }

        let focus: WeekFocus
        if current.workouts < current.plannedWorkouts {
            focus = .trainMore(missing: current.plannedWorkouts - current.workouts)
        } else if tracksNutrition, current.loggedFoodDays < 5 {
            focus = .logFood
        } else if tracksNutrition, current.proteinDays < 4 {
            focus = .hitProtein
        } else if current.weighIns < 2 {
            focus = .weighIn
        } else {
            focus = .keepGoing
        }
        return WeeklyReview(score: Int((score * 100).rounded()), training: training, nutrition: nutrition,
                            weighIns: weighIns, highlights: highlights, focus: focus, volumeChange: change)
    }
}

// MARK: - Uitdagingen

public enum ChallengeKind: String, Sendable, CaseIterable {
    case workouts, proteinDays, foodLogDays, weighIns, records, hardSets
}

public enum ChallengePeriod: String, Sendable {
    case week, month
}

public struct ChallengeDefinition: Sendable, Equatable, Identifiable {
    public var kind: ChallengeKind
    public var period: ChallengePeriod
    public var target: Int
    public var start: Date

    public init(kind: ChallengeKind, period: ChallengePeriod, target: Int, start: Date) {
        self.kind = kind
        self.period = period
        self.target = target
        self.start = start
    }

    /// Stabiel per soort en periode, zodat een voltooide uitdaging één keer telt.
    public var id: String { "\(period.rawValue)-\(kind.rawValue)-\(Int(start.timeIntervalSince1970))" }
}

/// Uitdagingen belonen wat je al van plan was: nooit meer trainingen dan je schema, en volume hooguit 10% erbij.
public enum ChallengeGenerator {
    public static func weekly(weekStart: Date, weekNumber: Int, plannedPerWeek: Int, tracksNutrition: Bool,
                              averageWeeklySets: Double?) -> [ChallengeDefinition] {
        var result = [ChallengeDefinition(kind: .workouts, period: .week, target: max(plannedPerWeek, 1), start: weekStart)]
        var pool: [ChallengeDefinition] = [
            ChallengeDefinition(kind: .weighIns, period: .week, target: 3, start: weekStart),
            ChallengeDefinition(kind: .records, period: .week, target: 1, start: weekStart),
        ]
        if tracksNutrition {
            pool.append(ChallengeDefinition(kind: .proteinDays, period: .week, target: 5, start: weekStart))
            pool.append(ChallengeDefinition(kind: .foodLogDays, period: .week, target: 6, start: weekStart))
        }
        if let averageWeeklySets, averageWeeklySets >= 10 {
            pool.append(ChallengeDefinition(kind: .hardSets, period: .week,
                                            target: Int((averageWeeklySets * 1.1).rounded()), start: weekStart))
        }
        // Elke week twee andere uit de pool, voorspelbaar per weeknummer.
        let offset = (weekNumber % pool.count + pool.count) % pool.count
        for index in 0..<min(2, pool.count) {
            result.append(pool[(offset + index) % pool.count])
        }
        return result
    }

    public static func monthly(monthStart: Date, plannedPerWeek: Int, daysInMonth: Int) -> ChallengeDefinition {
        let weeks = Double(daysInMonth) / 7
        return ChallengeDefinition(kind: .workouts, period: .month,
                                   target: max(1, Int((Double(plannedPerWeek) * weeks).rounded(.down))), start: monthStart)
    }

    public static func fraction(value: Double, target: Int) -> Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, value / Double(target)))
    }
}
