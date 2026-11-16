import Foundation
import PowerCore
import SwiftData

/// Trainingsaanbevelingen. De regels staan in PowerCore; dit verzamelt de data en maakt de teksten.
@MainActor
enum Coach {
    struct DayStatus: Identifiable {
        let day: TemplateDay
        let lastPerformed: Date?
        var id: String { day.id }
    }

    struct Recommendation {
        let advice: SessionAdvice
        let day: TemplateDay?
        let plannedPerWeek: Int

        var isRest: Bool { advice.kind == .rest }
    }

    struct MuscleStatus: Identifiable {
        let muscle: MuscleGroup
        let lastTrained: Date?
        let status: RecoveryStatus
        var id: String { muscle.rawValue }
    }

    // MARK: Schema

    static func plan(for profile: UserProfile) -> StarterPlan {
        profile.preferredPlan ?? .recommend(daysPerWeek: profile.trainingDaysPerWeek)
    }

    static func dayStatuses(plan: StarterPlan, profile: UserProfile, finished: [Workout]) -> [DayStatus] {
        StarterTemplates.days(plan: plan, equipment: profile.equipment).map { day in
            DayStatus(day: day, lastPerformed: finished.filter { $0.name == day.name }.map(\.startedAt).max())
        }
    }

    static func recommendation(profile: UserProfile, finished: [Workout], now: Date = Date()) -> Recommendation {
        let advice = SessionAdvisor.advise(workoutDays: finished.map(\.startedAt),
                                           plannedPerWeek: profile.trainingDaysPerWeek, today: now)
        let statuses = dayStatuses(plan: plan(for: profile), profile: profile, finished: finished)
        let index = SessionAdvisor.nextDayIndex(lastPerformed: statuses.map(\.lastPerformed))
        return Recommendation(advice: advice, day: index.map { statuses[$0].day },
                              plannedPerWeek: profile.trainingDaysPerWeek)
    }

    static func headline(_ recommendation: Recommendation) -> String {
        if recommendation.isRest { return String(localized: "Rustdag aanbevolen") }
        return recommendation.day?.name ?? String(localized: "Vrije training")
    }

    static func explanation(_ recommendation: Recommendation) -> String {
        let done = recommendation.advice.sessionsThisWeek
        let planned = recommendation.plannedPerWeek
        switch recommendation.advice.reason {
        case .firstSession:
            return String(localized: "Je eerste sessie legt je basislijn vast. Kies een gewicht waarmee je nog 2 à 3 reps overhoudt.")
        case .onTrack:
            return String(localized: "Je ligt op schema: \(done) van \(planned) trainingen deze week. Deze dag is het langst geleden.")
        case .behindSchedule:
            return String(localized: "Nog \(planned - done) te gaan deze week en de dagen raken op. Vandaag is een goed moment.")
        case .trainedToday:
            return String(localized: "Je hebt vandaag al getraind. Herstel hoort bij het plan.")
        case .weeklyGoalReached:
            return String(localized: "Weekdoel gehaald: \(done) van \(planned). Extra trainen levert geen extra XP op; herstel wel.")
        case .consecutiveDays:
            return String(localized: "Je hebt twee dagen achter elkaar getraind. Een rustdag houdt je volgende sessie scherp.")
        }
    }

    static func relativeDay(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return String(localized: "Nog niet gedaan") }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return String(localized: "Vandaag")
        case 1: return String(localized: "Gisteren")
        default: return String(localized: "\(days) dagen geleden")
        }
    }

    // MARK: Spiergroepen

    static func muscleStatuses(finished: [Workout], now: Date = Date()) -> [MuscleStatus] {
        var last: [MuscleGroup: Date] = [:]
        for workout in finished {
            for item in workout.exercises ?? [] {
                guard let exercise = item.exercise, !exercise.isCardio,
                      (item.sets ?? []).contains(where: { $0.isDone && $0.kind != .warmup }) else { continue }
                let date = workout.endedAt ?? workout.startedAt
                if date > (last[exercise.primaryMuscle] ?? .distantPast) { last[exercise.primaryMuscle] = date }
            }
        }
        return MuscleGroup.allCases.filter { $0 != .cardio && $0 != .forearms }.map { muscle in
            let date = last[muscle]
            let hours = date.map { now.timeIntervalSince($0) / 3600 }
            return MuscleStatus(muscle: muscle, lastTrained: date, status: .status(hoursSinceTrained: hours))
        }
    }

    static func statusText(_ status: MuscleStatus) -> String {
        switch status.status {
        case .untrained: String(localized: "Nog niet getraind")
        case .recovering: String(localized: "Herstelt nog")
        case .ready: String(localized: "Hersteld")
        case .overdue: String(localized: "Lang geleden")
        }
    }

    /// Vier oefeningen voor één spiergroep, passend bij het beschikbare materiaal.
    static func focusExercises(for muscle: MuscleGroup, equipment: Equipment, in context: ModelContext) -> [Exercise] {
        let all = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).filter { !$0.isCardio }
        let gearOrder: [String] = switch equipment {
        case .gym: ["barbell", "dumbbell", "machine", "cable", "bodyweight", "kettlebell", "band"]
        case .dumbbells: ["dumbbell", "bodyweight", "kettlebell", "band"]
        case .home: ["bodyweight", "band"]
        }
        func rank(_ exercise: Exercise) -> Int {
            (exercise.mainLift == nil ? 100 : 0) + (gearOrder.firstIndex(of: exercise.gearRaw) ?? 0)
        }
        func pick(_ candidates: [Exercise]) -> [Exercise] {
            // Stabiel sorteren: hoofdlifts eerst, daarna in volgorde van materiaal, dan op slug.
            candidates.filter { gearOrder.contains($0.gearRaw) }
                .sorted { (rank($0), $0.slug) < (rank($1), $1.slug) }
        }
        var result = pick(all.filter { $0.primaryMuscle == muscle })
        if result.count < 3 {
            let extra = pick(all.filter { $0.secondaryMuscles.contains(muscle) && $0.primaryMuscle != muscle })
            result += extra
        }
        // Wissel materiaal af zodat het niet vier keer dezelfde beweging wordt.
        var chosen: [Exercise] = []
        var usedGear = Set<String>()
        for exercise in result where chosen.count < 4 && !usedGear.contains(exercise.gearRaw) {
            chosen.append(exercise)
            usedGear.insert(exercise.gearRaw)
        }
        for exercise in result where chosen.count < 4 && !chosen.contains(where: { $0 === exercise }) {
            chosen.append(exercise)
        }
        return chosen
    }

    // MARK: Progressie

    struct Target {
        let suggestion: ProgressionSuggestion
        let text: String
        let reason: String
    }

    static func target(for exercise: Exercise, before workout: Workout?, units: UnitFormatter) -> Target? {
        guard !exercise.isCardio else { return nil }
        let last = History.lastSets(for: exercise, before: workout)
            .map { SetPerformance(weight: $0.weightKg, reps: $0.reps) }
        let range: ClosedRange<Int> = exercise.mainLift != nil ? 5...8
            : (exercise.gearRaw == "bodyweight" ? 8...15 : 8...12)
        guard let suggestion = ProgressionAdvisor.suggest(lastSets: last, repRange: range,
                                                          increment: increment(for: exercise, units: units))
        else { return nil }
        let text = suggestion.weight > 0
            ? "\(units.weightText(suggestion.weight, digits: 2)) × \(suggestion.reps)"
            : String(localized: "\(suggestion.reps) reps")
        let reason: String = switch suggestion.reason {
        case .addWeight: String(localized: "Alle sets haalden \(range.upperBound) reps. Tijd voor meer gewicht.")
        case .addReps: String(localized: "Zelfde gewicht, één rep erbij.")
        case .consolidate: String(localized: "Vorige keer zwaar. Haal eerst \(range.lowerBound) reps op dit gewicht.")
        }
        return Target(suggestion: suggestion, text: text, reason: reason)
    }

    /// Kleinste zinvolle stap in kg, afgestemd op materiaal en eenheden.
    static func increment(for exercise: Exercise, units: UnitFormatter) -> Double {
        let heavy = exercise.mainLift == .squat || exercise.mainLift == .deadlift
        if units.metric {
            if heavy { return 5 }
            return exercise.gearRaw == "dumbbell" ? 2 : 2.5
        }
        return UnitConversion.lbToKg(heavy ? 10 : 5)
    }
}
