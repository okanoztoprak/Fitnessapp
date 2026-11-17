import Foundation
import PowerCore
import SwiftData
import SwiftUI

/// Een voorstel voor een training dat de gebruiker eerst kan bekijken.
struct WorkoutProposal: Identifiable {
    let id = UUID()
    let title: String
    let caption: String
    let exercises: [Exercise]
}

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
        /// 0 = net getraind, 1 = volledig hersteld.
        let recovery: Double
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
        if recommendation.isRest { return String(localized: "Rustdag") }
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
            return String(localized: "Weekdoel gehaald: \(done) van \(planned). Meer trainen levert nu weinig op; herstel wel.")
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

    // MARK: Herstel en gereedheid

    static func muscleStatuses(finished: [Workout], now: Date = Date()) -> [MuscleStatus] {
        var last: [MuscleGroup: (date: Date, sets: Int)] = [:]
        for workout in finished {
            let date = workout.endedAt ?? workout.startedAt
            var perMuscle: [MuscleGroup: Int] = [:]
            for item in workout.exercises ?? [] {
                guard let exercise = item.exercise, !exercise.isCardio else { continue }
                let sets = (item.sets ?? []).filter { $0.isDone && $0.kind != .warmup }.count
                if sets > 0 { perMuscle[exercise.primaryMuscle, default: 0] += sets }
            }
            for (muscle, sets) in perMuscle where date > (last[muscle]?.date ?? .distantPast) {
                last[muscle] = (date, sets)
            }
        }
        return MuscleGroup.allCases.filter { $0 != .cardio && $0 != .forearms }.map { muscle in
            let entry = last[muscle]
            let hours = entry.map { now.timeIntervalSince($0.date) / 3600 }
            return MuscleStatus(muscle: muscle, lastTrained: entry?.date,
                                recovery: MuscleRecovery.fraction(hoursSinceTrained: hours, sets: entry?.sets ?? 0))
        }
    }

    static func statusText(_ status: MuscleStatus) -> String {
        if status.lastTrained == nil { return String(localized: "Fris") }
        if status.recovery >= 1 { return String(localized: "Hersteld") }
        return String(localized: "Herstelt")
    }

    static func color(forRecovery fraction: Double) -> Color {
        fraction >= 0.8 ? Theme.good : (fraction >= 0.4 ? Theme.warn : Theme.bad)
    }

    static func readiness(finished: [Workout], sleepHours: Double? = nil, now: Date = Date()) -> Readiness {
        ReadinessCalculator.readiness(
            muscleRecovery: finished.isEmpty ? [] : muscleStatuses(finished: finished, now: now).map(\.recovery),
            loadRatio: Insights.loadRatio(finished: finished, now: now),
            sleepHours: sleepHours)
    }

    static func color(for band: Readiness.Band) -> Color {
        switch band {
        case .high: Theme.good
        case .moderate: Theme.warn
        case .low: Theme.bad
        }
    }

    static func trainedToday(_ finished: [Workout], now: Date = Date()) -> Bool {
        finished.contains { Calendar.current.isDate($0.startedAt, inSameDayAs: now) }
    }

    /// Spiergroepen die minstens 80% hersteld zijn.
    static func freshMuscleCount(finished: [Workout], now: Date = Date()) -> (fresh: Int, total: Int) {
        let statuses = muscleStatuses(finished: finished, now: now)
        return (statuses.filter { $0.recovery >= 0.8 }.count, statuses.count)
    }

    static func title(for readiness: Readiness, hasHistory: Bool, trainedToday: Bool = false) -> String {
        guard hasHistory else { return String(localized: "Fris aan de start") }
        if trainedToday { return String(localized: "Vandaag getraind") }
        switch readiness.band {
        case .high: return String(localized: "Klaar om te trainen")
        case .moderate: return String(localized: "Deels hersteld")
        case .low: return String(localized: "Herstel eerst")
        }
    }

    static func advice(for readiness: Readiness, hasHistory: Bool, finished: [Workout] = []) -> String {
        guard hasHistory else {
            return String(localized: "Na je eerste training zie je hier hoe hersteld je bent.")
        }
        if trainedToday(finished) {
            let count = freshMuscleCount(finished: finished)
            return String(localized: "Goed bezig. \(count.fresh) van \(count.total) spiergroepen zijn fris voor je volgende sessie.")
        }
        switch readiness.band {
        case .high: return String(localized: "Je spieren zijn hersteld. Een goed moment voor een zware sessie.")
        case .moderate: return String(localized: "Trainen kan prima. Kies spiergroepen die al fris zijn.")
        case .low: return String(localized: "Je hebt recent zwaar getraind. Rust of een lichte sessie levert nu meer op.")
        }
    }

    static func loadText(_ status: TrainingLoad.Status) -> String {
        switch status {
        case .building: String(localized: "Opbouw")
        case .low: String(localized: "Laag")
        case .steady: String(localized: "Stabiel")
        case .high: String(localized: "Hoog")
        }
    }

    // MARK: Voorstellen

    static func exercises(slugs: [String], in context: ModelContext) -> [Exercise] {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let bySlug = Dictionary(all.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        return slugs.compactMap { bySlug[$0] }
    }

    static func proposal(for day: TemplateDay, caption: String, in context: ModelContext) -> WorkoutProposal {
        WorkoutProposal(title: day.name, caption: caption, exercises: exercises(slugs: day.slugs, in: context))
    }

    static func focusProposal(for muscle: MuscleGroup, equipment: Equipment, in context: ModelContext) -> WorkoutProposal {
        WorkoutProposal(title: String(localized: "Focus: \(muscle.title)"),
                        caption: String(localized: "Vier oefeningen voor één spiergroep, passend bij je materiaal."),
                        exercises: focusExercises(for: muscle, equipment: equipment, in: context))
    }

    /// Stelt een training samen uit de spiergroepen die het best hersteld zijn.
    static func smartProposal(profile: UserProfile, finished: [Workout], in context: ModelContext) -> WorkoutProposal {
        // Grote spiergroepen eerst bij gelijk herstel.
        let priority: [MuscleGroup] = [.quads, .chest, .back, .hamstrings, .shoulders, .glutes, .triceps, .biceps, .core, .calves]
        let statuses = muscleStatuses(finished: finished).sorted { lhs, rhs in
            if abs(lhs.recovery - rhs.recovery) > 0.05 { return lhs.recovery > rhs.recovery }
            let left = lhs.lastTrained ?? .distantPast, right = rhs.lastTrained ?? .distantPast
            if left != right { return left < right }
            return (priority.firstIndex(of: lhs.muscle) ?? 99) < (priority.firstIndex(of: rhs.muscle) ?? 99)
        }
        var chosen: [Exercise] = []
        for status in statuses where chosen.count < 6 {
            let candidates = focusExercises(for: status.muscle, equipment: profile.equipment, in: context)
            if let pick = candidates.first(where: { candidate in !chosen.contains { $0 === candidate } }) {
                chosen.append(pick)
            }
        }
        // Zware samengestelde oefeningen vooraan.
        chosen.sort { ($0.mainLift == nil ? 1 : 0) < ($1.mainLift == nil ? 1 : 0) }
        return WorkoutProposal(title: String(localized: "Slimme training"),
                               caption: String(localized: "Samengesteld uit de spiergroepen die nu het best hersteld zijn."),
                               exercises: chosen)
    }

    static func estimatedMinutes(exerciseCount: Int, restSeconds: Int) -> Int {
        // Drie sets per oefening, ongeveer 45 seconden per set plus rust.
        Int((Double(exerciseCount * 3 * (restSeconds + 45)) / 60 / 5).rounded() * 5)
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
            result += pick(all.filter { $0.secondaryMuscles.contains(muscle) && $0.primaryMuscle != muscle })
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
