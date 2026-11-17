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
            let sets = usage.sortedSets.filter { $0.isDone && $0.kind != .warmup && hasValues($0, exercise) }
            if !sets.isEmpty { return sets }
        }
        return []
    }

    /// Lege sets (uit oudere versies) tellen niet als prestatie.
    private static func hasValues(_ set: SetEntry, _ exercise: Exercise) -> Bool {
        exercise.isCardio ? (set.durationMinutes ?? 0) > 0 || (set.distanceKm ?? 0) > 0 : set.reps > 0
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
    /// Start een training. Sets worden vooringevuld met de vorige prestatie; in een programma bepaalt
    /// de week het aantal sets, en in een deload gaat het gewicht naar 90%.
    static func start(name: String, slugs: [String] = [], in context: ModelContext,
                      training: TrainingContext = .free, units: UnitFormatter = UnitFormatter(metric: true)) -> Workout {
        let workout = Workout(name: name)
        workout.programID = training.programID
        workout.programWeek = training.programID == nil ? nil : training.plan?.week
        context.insert(workout)
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let bySlug = Dictionary(all.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        for slug in slugs {
            guard let exercise = bySlug[slug] else { continue }
            let item = WorkoutExercise(order: (workout.exercises ?? []).count, exercise: exercise)
            context.insert(item)
            item.workout = workout
            fillSets(of: item, exercise: exercise, workout: workout, in: context, training: training, units: units)
        }
        return workout
    }

    static func add(_ exercise: Exercise, to workout: Workout, in context: ModelContext,
                    training: TrainingContext = .free) {
        let item = WorkoutExercise(order: (workout.exercises ?? []).count, exercise: exercise)
        context.insert(item)
        item.workout = workout
        fillSets(of: item, exercise: exercise, workout: workout, in: context, training: training)
    }

    /// Vult een oefening met sets op basis van de vorige keer en de regels van de week.
    static func fillSets(of item: WorkoutExercise, exercise: Exercise, workout: Workout, in context: ModelContext,
                         training: TrainingContext, units: UnitFormatter = UnitFormatter(metric: true)) {
        let previous = History.lastSets(for: exercise, before: workout)
        let count: Int = if exercise.isCardio {
            1
        } else if let plan = training.plan {
            Mesocycle.sets(plan: plan)
        } else {
            max(previous.count, 3)
        }
        let increment = Coach.increment(for: exercise, units: units)
        for index in 0..<count {
            let source = index < previous.count ? previous[index] : previous.last
            var weight = source?.weightKg ?? 0
            if training.isDeload { weight = DeloadAdvisor.deloadWeight(weight, increment: increment) }
            let set = SetEntry(order: index, weightKg: weight, reps: source?.reps ?? 0)
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

extension ModelContext {
    /// Slaat direct op in plaats van te wachten op autosave, zodat afronden en weggooien
    /// ook blijven staan als de app meteen daarna wordt afgesloten.
    func saveOrLog() {
        do {
            try save()
        } catch {
            print("POWERUP save failed: \(error)")
        }
    }
}
