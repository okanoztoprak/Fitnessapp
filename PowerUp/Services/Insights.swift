import Foundation
import PowerCore
import SwiftData

/// Statistieken over de trainingshistorie. De rekenregels staan in PowerCore; dit verzamelt de data.
@MainActor
enum Insights {
    struct WeekBucket: Identifiable {
        let week: Date
        var sets = 0
        var volumeKg = 0.0
        var workouts = 0
        var id: Date { week }
    }

    struct Milestone: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let progress: Double
        var achieved: Bool { progress >= 1 }
    }

    /// Afgevinkte sets zonder warming-up.
    static func hardSets(in workout: Workout) -> Int {
        workout.doneSets.filter { $0.kind != .warmup }.count
    }

    /// De laatste `weeks` kalenderweken, ook de lege, van oud naar nieuw.
    static func weekly(finished: [Workout], weeks: Int = 12, now: Date = Date()) -> [WeekBucket] {
        let calendar = Calendar.current
        guard let current = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        var buckets: [Date: WeekBucket] = [:]
        for offset in 0..<weeks {
            if let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: current) {
                buckets[week] = WeekBucket(week: week)
            }
        }
        for workout in finished {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: workout.startedAt)?.start,
                  buckets[week] != nil else { continue }
            buckets[week]?.sets += hardSets(in: workout)
            buckets[week]?.volumeKg += workout.volumeKg
            buckets[week]?.workouts += 1
        }
        return buckets.values.sorted { $0.week < $1.week }
    }

    static func loadRatio(finished: [Workout], now: Date = Date()) -> Double? {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let fiveWeeksAgo = now.addingTimeInterval(-35 * 86_400)
        var recent = 0, before = 0
        for workout in finished {
            if workout.startedAt >= weekAgo {
                recent += hardSets(in: workout)
            } else if workout.startedAt >= fiveWeeksAgo {
                before += hardSets(in: workout)
            }
        }
        return TrainingLoad.ratio(last7Days: Double(recent), previous28Days: Double(before))
    }

    static func streakText(_ weeks: Int) -> String {
        weeks == 1 ? String(localized: "1 week op rij") : String(localized: "\(weeks) weken op rij")
    }

    static func weekStreak(finished: [Workout], now: Date = Date()) -> Int {
        WeekStreak.current(workoutDays: finished.map(\.startedAt), today: now)
    }

    /// Sets per spiergroep in de laatste `days` dagen; secundaire spieren tellen half.
    static func muscleSets(finished: [Workout], days: Int = 28, now: Date = Date()) -> [MuscleGroup: Double] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        var totals: [MuscleGroup: Double] = [:]
        for workout in finished where workout.startedAt >= cutoff {
            for item in workout.exercises ?? [] {
                guard let exercise = item.exercise, !exercise.isCardio else { continue }
                let sets = Double((item.sets ?? []).filter { $0.isDone && $0.kind != .warmup }.count)
                guard sets > 0 else { continue }
                totals[exercise.primaryMuscle, default: 0] += sets
                for muscle in exercise.secondaryMuscles { totals[muscle, default: 0] += sets / 2 }
            }
        }
        return totals
    }

    /// Beste geschatte 1RM per hoofdlift.
    static func bestLifts(finished: [Workout], formula: OneRepMax.Formula) -> [MainLift: Double] {
        var best: [MainLift: Double] = [:]
        for workout in finished {
            for item in workout.exercises ?? [] {
                guard let lift = item.exercise?.mainLift else { continue }
                let top = (item.sets ?? []).filter { $0.isDone && $0.kind != .warmup }
                    .compactMap { OneRepMax.estimate(weight: $0.weightKg, reps: $0.reps, formula: formula) }
                    .max() ?? 0
                if top > (best[lift] ?? 0) { best[lift] = top }
            }
        }
        return best
    }

    /// Volumeverschil met de vorige afgeronde training met dezelfde naam, als fractie (0,08 = +8%).
    static func volumeChange(of workout: Workout, among finished: [Workout]) -> Double? {
        let previous = finished
            .filter { $0 !== workout && $0.name == workout.name && $0.startedAt < workout.startedAt }
            .max { $0.startedAt < $1.startedAt }
        guard let previous, previous.volumeKg > 0 else { return nil }
        return workout.volumeKg / previous.volumeKg - 1
    }

    /// Aantal sets per kalenderdag.
    static func setsPerDay(finished: [Workout]) -> [Date: Int] {
        let calendar = Calendar.current
        var days: [Date: Int] = [:]
        for workout in finished {
            days[calendar.startOfDay(for: workout.startedAt), default: 0] += max(1, hardSets(in: workout))
        }
        return days
    }

    static func exercisesDone(in workout: Workout) -> Int {
        (workout.exercises ?? []).filter { ($0.sets ?? []).contains(where: \.isDone) }.count
    }

    static func muscles(in workout: Workout) -> [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for item in workout.sortedExercises {
            guard let exercise = item.exercise, (item.sets ?? []).contains(where: \.isDone),
                  !seen.contains(exercise.primaryMuscle) else { continue }
            seen.append(exercise.primaryMuscle)
        }
        return seen
    }

    static func milestones(finished: [Workout], recordCount: Int, streak: Int) -> [Milestone] {
        let count = Double(finished.count)
        let tons = finished.reduce(0) { $0 + $1.volumeKg } / 1000
        return [
            Milestone(id: "first", title: String(localized: "Eerste training"), symbol: "flag.checkered", progress: count),
            Milestone(id: "w10", title: String(localized: "10 trainingen"), symbol: "10.circle.fill", progress: count / 10),
            Milestone(id: "w25", title: String(localized: "25 trainingen"), symbol: "25.circle.fill", progress: count / 25),
            Milestone(id: "w50", title: String(localized: "50 trainingen"), symbol: "50.circle.fill", progress: count / 50),
            Milestone(id: "pr1", title: String(localized: "Eerste record"), symbol: "trophy.fill", progress: Double(recordCount)),
            Milestone(id: "pr10", title: String(localized: "10 records"), symbol: "medal.fill", progress: Double(recordCount) / 10),
            Milestone(id: "s4", title: String(localized: "4 weken op rij"), symbol: "flame.fill", progress: Double(streak) / 4),
            Milestone(id: "s12", title: String(localized: "12 weken op rij"), symbol: "calendar.badge.checkmark", progress: Double(streak) / 12),
            Milestone(id: "t10", title: String(localized: "10 ton verzet"), symbol: "scalemass.fill", progress: tons / 10),
            Milestone(id: "t100", title: String(localized: "100 ton verzet"), symbol: "mountain.2.fill", progress: tons / 100),
        ]
    }
}
