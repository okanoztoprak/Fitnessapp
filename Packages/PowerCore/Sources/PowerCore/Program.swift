import Foundation

// MARK: - Mesocyclus

public enum ProgramGoal: String, Sendable, CaseIterable {
    case hypertrophy, strength
}

/// Wat een week in een blok vraagt.
public struct WeekPlan: Sendable, Equatable {
    /// 1-gebaseerd.
    public var week: Int
    public var totalWeeks: Int
    public var isDeload: Bool
    /// Herhalingen die je in de tank houdt aan het eind van een set.
    public var targetRIR: Int
    /// Extra sets per oefening bovenop de basis.
    public var extraSets: Int
    /// Factor op het gewicht; 0,9 in de deloadweek.
    public var loadFactor: Double

    public init(week: Int, totalWeeks: Int, isDeload: Bool, targetRIR: Int, extraSets: Int, loadFactor: Double) {
        self.week = week
        self.totalWeeks = totalWeeks
        self.isDeload = isDeload
        self.targetRIR = targetRIR
        self.extraSets = extraSets
        self.loadFactor = loadFactor
    }
}

public struct ProgramPosition: Sendable, Equatable {
    public var week: Int
    /// Hoeveelste training binnen de week, 0-gebaseerd.
    public var sessionInWeek: Int
    /// Welke schemadag aan de beurt is, 0-gebaseerd.
    public var dayIndex: Int
    public var isFinished: Bool
}

/// Een blok: elke week iets dichter bij falen en (voor spiermassa) iets meer sets, en als laatste week een deload.
public enum Mesocycle {
    public static let lengths = [4, 5, 6]
    public static let baseSets = 3

    public static func plan(week: Int, totalWeeks: Int, goal: ProgramGoal) -> WeekPlan {
        let total = max(totalWeeks, 2)
        let current = min(max(week, 1), total)
        if current == total {
            return WeekPlan(week: current, totalWeeks: total, isDeload: true, targetRIR: 4, extraSets: 0, loadFactor: 0.9)
        }
        let accumulation = total - 1
        let progress = accumulation <= 1 ? 1 : Double(current - 1) / Double(accumulation - 1)
        // RIR loopt van 3 naar 1; spiermassa krijgt er tot twee sets per oefening bij.
        let rir = Int((3 - 2 * progress).rounded())
        let extra = goal == .hypertrophy ? Int((2 * progress).rounded()) : 0
        return WeekPlan(week: current, totalWeeks: total, isDeload: false, targetRIR: rir, extraSets: extra, loadFactor: 1)
    }

    public static func sets(base: Int = baseSets, plan: WeekPlan) -> Int {
        if plan.isDeload { return max(1, Int((Double(base) / 2).rounded(.up))) }
        return base + plan.extraSets
    }

    public static func repRange(goal: ProgramGoal, compound: Bool) -> ClosedRange<Int> {
        switch goal {
        case .strength: compound ? 3...6 : 6...10
        case .hypertrophy: compound ? 6...10 : 10...15
        }
    }

    /// Positie in het blok op basis van afgeronde trainingen, niet de kalender:
    /// een gemiste dag schuift alles op in plaats van een week over te slaan.
    public static func position(completedSessions: Int, daysPerWeek: Int, rotationLength: Int,
                                totalWeeks: Int) -> ProgramPosition {
        let perWeek = max(daysPerWeek, 1)
        let done = max(completedSessions, 0)
        let finished = done >= perWeek * totalWeeks
        let week = min(done / perWeek + 1, max(totalWeeks, 1))
        return ProgramPosition(week: week, sessionInWeek: finished ? perWeek : done % perWeek,
                               dayIndex: done % max(rotationLength, 1), isFinished: finished)
    }
}

// MARK: - Volume per spiergroep

public enum MuscleSize: String, Sendable {
    case large, small
}

/// Harde sets per week: onder MEV groei je nauwelijks, tussen MAV-onder en -boven zit de meeste winst,
/// boven MRV herstel je niet meer. Vuistregels uit de sportwetenschap, geen persoonlijke metingen.
public struct VolumeLandmarks: Sendable, Equatable {
    public var mev: Int
    public var mavLow: Int
    public var mavHigh: Int
    public var mrv: Int
}

public enum VolumeGuide {
    public enum Status: String, Sendable {
        case low, productive, high
    }

    public static func landmarks(size: MuscleSize) -> VolumeLandmarks {
        switch size {
        case .large: VolumeLandmarks(mev: 8, mavLow: 12, mavHigh: 18, mrv: 22)
        case .small: VolumeLandmarks(mev: 6, mavLow: 8, mavHigh: 14, mrv: 18)
        }
    }

    /// Streefbereik voor deze week. Zonder blok het productieve bereik; in een blok groeit het mee
    /// van MEV naar MAV-boven, en in de deloadweek is het de helft van MEV tot MEV.
    public static func target(_ landmarks: VolumeLandmarks, plan: WeekPlan?) -> ClosedRange<Int> {
        guard let plan else { return landmarks.mavLow...landmarks.mavHigh }
        if plan.isDeload { return max(1, landmarks.mev / 2)...landmarks.mev }
        let accumulation = max(plan.totalWeeks - 1, 1)
        let progress = accumulation <= 1 ? 1 : Double(plan.week - 1) / Double(accumulation - 1)
        let low = landmarks.mev + Int((Double(landmarks.mavLow - landmarks.mev) * progress).rounded())
        let high = landmarks.mavLow + Int((Double(landmarks.mavHigh - landmarks.mavLow) * progress).rounded())
        return low...max(low, high)
    }

    public static func status(sets: Double, landmarks: VolumeLandmarks) -> Status {
        if sets < Double(landmarks.mev) { return .low }
        return sets > Double(landmarks.mrv) ? .high : .productive
    }
}

// MARK: - Stilstand en deload

public enum PlateauDetector {
    /// `bests` is de beste geschatte 1RM per training, oud naar nieuw. Stilstand: de laatste `window`
    /// trainingen kwamen niet meer dan 0,5% boven het beste van daarvoor.
    public static func isPlateau(_ bests: [Double], window: Int = 3) -> Bool {
        let values = bests.filter { $0 > 0 }
        guard values.count >= window + 1,
              let before = values.dropLast(window).max(),
              let recent = values.suffix(window).max() else { return false }
        return recent <= before * 1.005
    }
}

public struct DeloadAdvice: Sendable, Equatable {
    public enum Reason: String, Sendable {
        /// De belasting ligt deze week ver boven het eigen gemiddelde.
        case highLoad
        /// De helft of meer van de hoofdoefeningen staat stil.
        case stalled
        /// Lang achter elkaar getraind zonder lichtere week.
        case longBlock
    }

    public var reason: Reason
}

public enum DeloadAdvisor {
    public static let maxWeeksWithoutDeload = 8

    public static func advise(weeksInARow: Int, stalledLifts: Int, trackedLifts: Int,
                              loadRatio: Double?) -> DeloadAdvice? {
        if let loadRatio, loadRatio > 1.5 { return DeloadAdvice(reason: .highLoad) }
        if trackedLifts >= 2, stalledLifts * 2 >= trackedLifts { return DeloadAdvice(reason: .stalled) }
        if weeksInARow >= maxWeeksWithoutDeload { return DeloadAdvice(reason: .longBlock) }
        return nil
    }

    /// Gewicht voor een deload: 90%, afgerond op de kleinste stap.
    public static func deloadWeight(_ weight: Double, increment: Double) -> Double {
        guard weight > 0 else { return 0 }
        let step = max(increment, 0.5)
        return max(step, (weight * 0.9 / step).rounded() * step)
    }
}
