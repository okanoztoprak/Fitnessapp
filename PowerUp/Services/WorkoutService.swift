import Foundation
import PowerCore
import SwiftData

/// Historie per oefening: vorige prestatie, PR-vergelijking en e1RM-verloop.
@MainActor
enum History {
    /// Afgeronde, niet-warming-up-sets van de laatste afgeronde training met deze oefening.
    static func lastSets(for exercise: Exercise, before workout: Workout?) -> [SetEntry] {
        let usages = (exercise.usages ?? [])
            .filter { $0.workout?.endedAt != nil && $0.workout !== workout }
            .sorted { ($0.workout?.startedAt ?? .distantPast) > ($1.workout?.startedAt ?? .distantPast) }
        for usage in usages {
            let sets = usage.sortedSets.filter { $0.isDone && $0.kind != .warmup }
            if !sets.isEmpty { return sets }
        }
        return []
    }

    static func hasFinishedHistory(_ exercise: Exercise) -> Bool {
        !lastSets(for: exercise, before: nil).isEmpty
    }

    /// Alle eerder afgevinkte sets van deze oefening, behalve `excluded`.
    static func performances(for exercise: Exercise, excluding excluded: SetEntry) -> [SetPerformance] {
        (exercise.usages ?? [])
            .flatMap { $0.sets ?? [] }
            .filter { $0.isDone && $0.kind != .warmup && $0 !== excluded }
            .map { SetPerformance(weight: $0.weightKg, reps: $0.reps) }
    }

    /// Beste e1RM per afgeronde training, op datum.
    static func e1rmSeries(for exercise: Exercise, formula: OneRepMax.Formula) -> [E1RMPoint] {
        (exercise.usages ?? []).compactMap { usage -> E1RMPoint? in
            guard let workout = usage.workout, workout.endedAt != nil else { return nil }
            let best = (usage.sets ?? [])
                .filter { $0.isDone && $0.kind != .warmup }
                .compactMap { OneRepMax.estimate(weight: $0.weightKg, reps: $0.reps, formula: formula) }
                .max()
            return best.map { E1RMPoint(date: workout.startedAt, value: $0) }
        }
        .sorted { $0.date < $1.date }
    }
}

struct E1RMPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

@MainActor
enum WorkoutFactory {
    /// Start een training. Sets worden vooringevuld met de vorige prestatie.
    static func start(name: String, slugs: [String] = [], in context: ModelContext) -> Workout {
        let workout = Workout(name: name)
        context.insert(workout)
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let bySlug = Dictionary(all.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        for slug in slugs {
            guard let exercise = bySlug[slug] else { continue }
            add(exercise, to: workout, in: context)
        }
        return workout
    }

    static func add(_ exercise: Exercise, to workout: Workout, in context: ModelContext) {
        let item = WorkoutExercise(order: (workout.exercises ?? []).count, exercise: exercise)
        context.insert(item)
        item.workout = workout
        let previous = History.lastSets(for: exercise, before: workout)
        let count = exercise.isCardio ? 1 : max(previous.count, 3)
        for index in 0..<count {
            let source = index < previous.count ? previous[index] : previous.last
            let set = SetEntry(order: index, weightKg: source?.weightKg ?? 0, reps: source?.reps ?? 0)
            context.insert(set)
            set.workoutExercise = item
        }
    }

    static func addSet(to item: WorkoutExercise, in context: ModelContext) {
        let last = item.sortedSets.last
        let set = SetEntry(order: (last?.order ?? -1) + 1, kind: last?.kind == .warmup ? .warmup : .normal,
                           weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0)
        context.insert(set)
        set.workoutExercise = item
    }
}
