import Foundation
import PowerCore
import SwiftData
import SwiftUI

/// Onder welke regels een training valt: een programmaweek, een losse deloadweek, of vrij.
struct TrainingContext: Equatable {
    var goal: ProgramGoal?
    var plan: WeekPlan?
    var programID: String?

    static let free = TrainingContext()

    var isDeload: Bool { plan?.isDeload ?? false }

    /// Losse deloadweek: dezelfde regels als de laatste week van een blok.
    static func deload(goal: ProgramGoal? = nil) -> TrainingContext {
        TrainingContext(goal: goal, plan: Mesocycle.plan(week: 2, totalWeeks: 2, goal: goal ?? .hypertrophy))
    }
}

/// Waar je staat in je programma.
@MainActor
struct ProgramStatus {
    let program: TrainingProgram
    let days: [TemplateDay]
    let completed: Int
    let position: ProgramPosition
    let weekPlan: WeekPlan

    init(program: TrainingProgram, finished: [Workout]) {
        self.program = program
        days = StarterTemplates.days(plan: program.plan, equipment: program.equipment)
        completed = finished.filter { $0.programID == program.programID }.count
        position = Mesocycle.position(completedSessions: completed, daysPerWeek: program.daysPerWeek,
                                      rotationLength: days.count, totalWeeks: program.totalWeeks)
        weekPlan = Mesocycle.plan(week: position.week, totalWeeks: program.totalWeeks, goal: program.goal)
    }

    var nextDay: TemplateDay? { days.isEmpty || position.isFinished ? nil : days[position.dayIndex % days.count] }

    var context: TrainingContext {
        TrainingContext(goal: program.goal, plan: weekPlan, programID: program.programID)
    }

    /// 0...1 door het hele blok.
    var progress: Double {
        Double(completed) / Double(max(program.daysPerWeek * program.totalWeeks, 1))
    }

    static func active(_ programs: [TrainingProgram]) -> TrainingProgram? {
        programs.filter(\.isActive).max { $0.startedAt < $1.startedAt }
    }
}

/// Regels voor programma's, volume, stilstand en deloads. De rekenregels staan in PowerCore.
@MainActor
enum ProgramCoach {
    // MARK: Context

    static func context(for workout: Workout, programs: [TrainingProgram], profile: UserProfile) -> TrainingContext {
        if let id = workout.programID, let program = programs.first(where: { $0.programID == id }) {
            let week = workout.programWeek ?? 1
            return TrainingContext(goal: program.goal,
                                   plan: Mesocycle.plan(week: week, totalWeeks: program.totalWeeks, goal: program.goal),
                                   programID: id)
        }
        return profile.isDeloading ? .deload() : .free
    }

    /// Context voor een nieuwe training, als die niet uit een programma komt.
    static func freeContext(profile: UserProfile) -> TrainingContext {
        profile.isDeloading ? .deload() : .free
    }

    static func isCompound(_ exercise: Exercise) -> Bool {
        exercise.mainLift != nil || exercise.gearRaw == "barbell"
    }

    // MARK: Teksten

    static func goalTitle(_ goal: ProgramGoal) -> String {
        switch goal {
        case .hypertrophy: String(localized: "Spiermassa")
        case .strength: String(localized: "Kracht")
        }
    }

    static func goalDetail(_ goal: ProgramGoal) -> String {
        switch goal {
        case .hypertrophy: String(localized: "Meer sets per week en 6 tot 15 herhalingen")
        case .strength: String(localized: "Zwaarder gewicht, 3 tot 6 herhalingen op de hoofdoefeningen")
        }
    }

    static func programName(_ program: TrainingProgram) -> String {
        "\(goalTitle(program.goal)) · \(program.plan.title)"
    }

    static func weekLine(_ plan: WeekPlan) -> String {
        plan.isDeload
            ? String(localized: "Week \(plan.week) van \(plan.totalWeeks) · Deload")
            : String(localized: "Week \(plan.week) van \(plan.totalWeeks) · RIR \(plan.targetRIR)")
    }

    static func weekExplanation(_ plan: WeekPlan, goal: ProgramGoal) -> String {
        if plan.isDeload {
            return String(localized: "Deloadweek: minder sets en 90% van je gewicht. Je lichaam haalt nu de winst van het blok binnen.")
        }
        let sets = Mesocycle.sets(plan: plan)
        return String(localized: "\(sets) sets per oefening. Stop elke set met nog \(plan.targetRIR) herhalingen in de tank.")
    }

    // MARK: Volume

    struct MuscleVolume: Identifiable {
        let muscle: MuscleGroup
        let sets: Double
        let target: ClosedRange<Int>
        let landmarks: VolumeLandmarks
        var id: String { muscle.rawValue }

        var status: VolumeGuide.Status {
            if sets > Double(landmarks.mrv) { return .high }
            return sets >= Double(target.lowerBound) ? .productive : .low
        }
    }

    static let volumeMuscles: [MuscleGroup] = [.chest, .back, .shoulders, .quads, .hamstrings, .glutes,
                                               .biceps, .triceps, .calves, .core]

    static func size(of muscle: MuscleGroup) -> MuscleSize {
        switch muscle {
        case .chest, .back, .shoulders, .quads, .hamstrings, .glutes: .large
        default: .small
        }
    }

    static func weeklyVolume(finished: [Workout], plan: WeekPlan?, now: Date = Date()) -> [MuscleVolume] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let totals = Insights.muscleSets(finished: finished.filter { $0.startedAt >= start }, days: 8, now: now)
        return volumeMuscles.map { muscle in
            let landmarks = VolumeGuide.landmarks(size: size(of: muscle))
            return MuscleVolume(muscle: muscle, sets: totals[muscle] ?? 0,
                                target: VolumeGuide.target(landmarks, plan: plan), landmarks: landmarks)
        }
    }

    static func color(for status: VolumeGuide.Status) -> Color {
        switch status {
        case .low: Theme.cool
        case .productive: Theme.good
        case .high: Theme.bad
        }
    }

    // MARK: Stilstand en deload

    /// Oefeningen met minstens vier trainingen die al drie keer niet vooruit zijn gegaan.
    static func plateaus(finished: [Workout], formula: OneRepMax.Formula) -> (stalled: [Exercise], tracked: Int) {
        var seen = Set<String>()
        var stalled: [Exercise] = []
        var tracked = 0
        for workout in finished {
            for item in workout.exercises ?? [] {
                guard let exercise = item.exercise, !exercise.isCardio, !seen.contains(exercise.slug) else { continue }
                seen.insert(exercise.slug)
                let series = History.e1rmSeries(for: exercise, formula: formula).map(\.value)
                guard series.count >= 4 else { continue }
                tracked += 1
                if PlateauDetector.isPlateau(series) { stalled.append(exercise) }
            }
        }
        return (stalled, tracked)
    }

    static func deloadAdvice(finished: [Workout], profile: UserProfile, hasProgram: Bool) -> DeloadAdvice? {
        guard !hasProgram, !profile.isDeloading else { return nil }
        let plateau = plateaus(finished: finished, formula: profile.e1rmFormula)
        return DeloadAdvisor.advise(weeksInARow: Insights.weekStreak(finished: finished),
                                    stalledLifts: plateau.stalled.count, trackedLifts: plateau.tracked,
                                    loadRatio: Insights.loadRatio(finished: finished))
    }

    static func adviceText(_ advice: DeloadAdvice) -> String {
        switch advice.reason {
        case .highLoad:
            String(localized: "Je traint deze week veel zwaarder dan normaal. Een lichtere week voorkomt dat vermoeidheid je inhaalt.")
        case .stalled:
            String(localized: "De helft van je oefeningen gaat niet meer vooruit. Een deloadweek laat vermoeidheid zakken, daarna stijg je meestal weer.")
        case .longBlock:
            String(localized: "Je traint al \(DeloadAdvisor.maxWeeksWithoutDeload) weken achter elkaar. Tijd voor een lichtere week.")
        }
    }

    // MARK: Vervangen

    /// Andere oefeningen voor dezelfde spiergroep met het materiaal dat je hebt.
    static func alternatives(for exercise: Exercise, equipment: Equipment, in context: ModelContext) -> [Exercise] {
        let allowed: Set<String> = switch equipment {
        case .gym: ["barbell", "dumbbell", "machine", "cable", "bodyweight", "kettlebell", "band"]
        case .dumbbells: ["dumbbell", "bodyweight", "kettlebell", "band"]
        case .home: ["bodyweight", "band"]
        }
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        // Geen andere hoofdlift als vervanger (een deadlift is geen vervanging voor een row).
        func fits(_ candidate: Exercise) -> Bool {
            candidate.mainLift == nil || candidate.mainLift == exercise.mainLift
        }
        func rank(_ candidate: Exercise) -> Int { candidate.gearRaw == exercise.gearRaw ? 0 : 1 }
        return all
            .filter { $0.slug != exercise.slug && !$0.isCardio && $0.primaryMuscle == exercise.primaryMuscle
                && allowed.contains($0.gearRaw) && fits($0) }
            .sorted { (rank($0), $0.name) < (rank($1), $1.name) }
    }
}
