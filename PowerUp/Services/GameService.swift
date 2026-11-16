import Foundation
import PowerCore
import SwiftData

/// XP en power level. Alle regels zelf staan in PowerCore; dit haalt alleen de data op.
@MainActor
enum GameService {
    /// Kent XP toe volgens de dagregels. Geeft het toegekende aantal terug (0 als de limiet bereikt is).
    @discardableResult
    static func award(_ source: XPSource, in context: ModelContext, date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = ((try? context.fetch(FetchDescriptor<XPEvent>())) ?? [])
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
        let amount = XPRules.award(
            source,
            countTodayForSource: today.filter { $0.source == source }.count,
            totalToday: today.reduce(0) { $0 + $1.amount })
        guard amount > 0 else { return 0 }
        context.insert(XPEvent(date: date, source: source, amount: amount))
        return amount
    }

    static func currentInput(in context: ModelContext, now: Date = Date()) -> PowerLevelInput? {
        guard let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first else { return nil }
        let weights = (try? context.fetch(FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let finished = ((try? context.fetch(FetchDescriptor<Workout>())) ?? []).filter { $0.endedAt != nil }
        let calendar = Calendar.current

        let strengthCutoff = now.addingTimeInterval(-90 * 86_400)
        var lifts: [MainLift: Double] = [:]
        var cardioMinutes = 0.0
        let weekCutoff = now.addingTimeInterval(-7 * 86_400)
        for workout in finished {
            for item in workout.exercises ?? [] {
                guard let exercise = item.exercise else { continue }
                let sets = (item.sets ?? []).filter { $0.isDone && $0.kind != .warmup }
                if exercise.isCardio, workout.startedAt >= weekCutoff {
                    cardioMinutes += sets.reduce(0) { $0 + ($1.durationMinutes ?? 0) }
                }
                if let lift = exercise.mainLift, workout.startedAt >= strengthCutoff {
                    let best = sets.compactMap {
                        OneRepMax.estimate(weight: $0.weightKg, reps: $0.reps, formula: profile.e1rmFormula)
                    }.max() ?? 0
                    lifts[lift] = max(lifts[lift] ?? 0, best)
                }
            }
        }
        let monthCutoff = now.addingTimeInterval(-28 * 86_400)
        let sessionDays = Set(finished.filter { $0.startedAt >= monthCutoff }
            .map { calendar.startOfDay(for: $0.startedAt) })

        return PowerLevelInput(
            bodyWeightKg: weights.last?.kg ?? 0,
            sex: profile.sex,
            experience: profile.experience,
            liftE1RMs: lifts,
            sessionsLast28Days: sessionDays.count,
            plannedSessionsPerWeek: profile.trainingDaysPerWeek,
            cardioMinutesPerWeek: cardioMinutes)
    }

    /// Herberekent het power level en bewaart één snapshot per dag.
    @discardableResult
    static func refreshPowerLevel(in context: ModelContext, now: Date = Date()) -> PowerLevelResult? {
        guard let input = currentInput(in: context, now: now) else { return nil }
        let result = PowerLevelCalculator.calculate(input)
        let snapshots = (try? context.fetch(
            FetchDescriptor<PowerLevelSnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        if let latest = snapshots.first, Calendar.current.isDate(latest.date, inSameDayAs: now) {
            latest.date = now
            latest.total = result.total
            latest.strength = result.strength
            latest.consistency = result.consistency
            latest.conditioning = result.conditioning
        } else {
            context.insert(PowerLevelSnapshot(date: now, result: result))
        }
        return result
    }
}
