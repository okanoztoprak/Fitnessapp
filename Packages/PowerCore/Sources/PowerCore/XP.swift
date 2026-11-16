import Foundation

public enum XPSource: String, Sendable, CaseIterable {
    case workout, personalRecord, weighIn, proteinGoal, sleep, quest
}

/// XP beloont consistentie, geen extreem gedrag: elke bron heeft een daglimiet
/// en er is een dagplafond. Een tweede training op dezelfde dag levert niets op.
public enum XPRules {
    public static let dailyCap = 400

    public static func baseAmount(_ source: XPSource) -> Int {
        switch source {
        case .workout: 100
        case .personalRecord: 50
        case .weighIn: 20
        case .proteinGoal: 40
        case .sleep: 30
        case .quest: 50
        }
    }

    public static func dailyLimit(_ source: XPSource) -> Int {
        switch source {
        case .workout: 1
        case .personalRecord: 3
        case .weighIn: 1
        case .proteinGoal: 1
        case .sleep: 1
        case .quest: 3
        }
    }

    /// Hoeveel XP een gebeurtenis oplevert, gegeven wat er vandaag al verdiend is.
    public static func award(_ source: XPSource, countTodayForSource: Int, totalToday: Int) -> Int {
        guard countTodayForSource < dailyLimit(source) else { return 0 }
        return max(0, min(baseAmount(source), dailyCap - totalToday))
    }
}

public struct LevelProgress: Sendable, Equatable {
    public var level: Int
    public var xpIntoLevel: Int
    public var xpForNextLevel: Int
    public var fraction: Double { Double(xpIntoLevel) / Double(xpForNextLevel) }
}

public enum LevelCurve {
    /// XP nodig om van `level` naar `level + 1` te gaan.
    public static func xpNeeded(from level: Int) -> Int { 100 + 50 * (max(level, 1) - 1) }

    /// Totaal XP nodig om `level` te bereiken (level 1 = 0).
    public static func totalXP(toReach level: Int) -> Int {
        let n = max(level, 1) - 1
        return 100 * n + 25 * n * (n - 1)
    }

    public static func progress(totalXP: Int) -> LevelProgress {
        var level = 1
        var remaining = max(totalXP, 0)
        while remaining >= xpNeeded(from: level) {
            remaining -= xpNeeded(from: level)
            level += 1
        }
        return LevelProgress(level: level, xpIntoLevel: remaining, xpForNextLevel: xpNeeded(from: level))
    }
}
