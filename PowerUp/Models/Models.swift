import Foundation
import PowerCore
import SwiftData

// Alle modellen zijn CloudKit-compatibel opgezet: standaardwaarden, optionele relaties,
// geen unique-constraints. Enums worden als ruwe string opgeslagen. Opslag is altijd SI.

@Model
final class UserProfile {
    var createdAt: Date = Date()
    var birthDate: Date = Date()
    var sexRaw: String = Sex.male.rawValue
    var heightCm: Double = 175
    var bodyFatPercent: Double?
    var activityRaw: String = ActivityLevel.moderate.rawValue
    var goalRaw: String = Goal.maintain.rawValue
    var trainingDaysPerWeek: Int = 3
    var equipmentRaw: String = Equipment.gym.rawValue
    var usesMetric: Bool = true
    var hideCalories: Bool = false
    var hideWeight: Bool = false
    var celebratePRs: Bool = true
    var e1rmFormulaRaw: String = OneRepMax.Formula.epley.rawValue
    var restSeconds: Int = 120
    /// Zelf gekozen schema; `nil` volgt het aantal trainingsdagen.
    var preferredPlanRaw: String?
    /// Weergave: system, light of dark.
    var appearanceRaw: String = Appearance.dark.rawValue
    /// Caloriedoel uit de laatste check-in; `nil` volgt de formule.
    var calorieTargetKcal: Double?
    /// Eigen eiwitdoel in g per kg; `nil` volgt de standaard voor het doel.
    var proteinPerKg: Double?
    /// Deel van de calorieën uit vet.
    var fatShare: Double = 0.25
    /// Voeding, gewicht en slaap uit Apple Health halen.
    var healthSyncEnabled: Bool = false
    var lastHealthSync: Date?
    /// Slaap van de laatste nacht uit Apple Health, met de dag waarop die gemeten is.
    var lastSleepHours: Double?
    var lastSleepDate: Date?
    /// Losse deloadweek buiten een programma, tot deze datum.
    var deloadUntil: Date?

    init() {}

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }
    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }
    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .gym }
        set { equipmentRaw = newValue.rawValue }
    }
    var e1rmFormula: OneRepMax.Formula {
        get { OneRepMax.Formula(rawValue: e1rmFormulaRaw) ?? .epley }
        set { e1rmFormulaRaw = newValue.rawValue }
    }
    var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .dark }
        set { appearanceRaw = newValue.rawValue }
    }
    var preferredPlan: StarterPlan? {
        get { preferredPlanRaw.flatMap(StarterPlan.init(rawValue:)) }
        set { preferredPlanRaw = newValue?.rawValue }
    }
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
    }

    /// Slaap van afgelopen nacht, alleen als die vandaag is opgehaald.
    var isDeloading: Bool { (deloadUntil ?? .distantPast) > Date() }

    var sleepHoursToday: Double? {
        guard let date = lastSleepDate, Calendar.current.isDateInToday(date) else { return nil }
        return lastSleepHours
    }

    func energyInput(weightKg: Double) -> EnergyInput {
        EnergyInput(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex,
                    bodyFatPercent: bodyFatPercent, activity: activity)
    }
}

enum Appearance: String, CaseIterable {
    case system, light, dark
}

enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, biceps, triceps, forearms, quads, hamstrings, glutes, calves, core, cardio
}

enum SetKind: String, CaseIterable {
    case warmup, normal, dropset, failure
}

@Model
final class Exercise {
    var slug: String = ""
    var nameEN: String = ""
    var nameNL: String = ""
    var primaryMuscleRaw: String = MuscleGroup.chest.rawValue
    var secondaryMusclesRaw: String = ""
    /// barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, cardio
    var gearRaw: String = "barbell"
    var isCardio: Bool = false
    var isCustom: Bool = false
    var mainLiftRaw: String?
    var instructions: String = ""
    @Relationship(inverse: \WorkoutExercise.exercise) var usages: [WorkoutExercise]?

    init(slug: String, nameEN: String, nameNL: String, primary: MuscleGroup,
         secondary: [MuscleGroup] = [], gear: String, isCardio: Bool = false,
         isCustom: Bool = false, mainLift: MainLift? = nil) {
        self.slug = slug
        self.nameEN = nameEN
        self.nameNL = nameNL
        self.primaryMuscleRaw = primary.rawValue
        self.secondaryMusclesRaw = secondary.map(\.rawValue).joined(separator: ",")
        self.gearRaw = gear
        self.isCardio = isCardio
        self.isCustom = isCustom
        self.mainLiftRaw = mainLift?.rawValue
    }

    var primaryMuscle: MuscleGroup { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
    var secondaryMuscles: [MuscleGroup] {
        secondaryMusclesRaw.split(separator: ",").compactMap { MuscleGroup(rawValue: String($0)) }
    }
    var mainLift: MainLift? { mainLiftRaw.flatMap(MainLift.init(rawValue:)) }
    var name: String {
        let dutch = Locale.current.language.languageCode?.identifier == "nl"
        return dutch && !nameNL.isEmpty ? nameNL : nameEN
    }
}

@Model
final class Workout {
    var name: String = ""
    var startedAt: Date = Date()
    var endedAt: Date?
    var notes: String = ""
    /// Gezet als de training bij een programma hoort.
    var programID: String?
    var programWeek: Int?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]?

    init(name: String, startedAt: Date = Date()) {
        self.name = name
        self.startedAt = startedAt
    }

    var sortedExercises: [WorkoutExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
    var doneSets: [SetEntry] {
        (exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isDone)
    }
    /// Totaal volume in kg, zonder warming-up-sets.
    var volumeKg: Double {
        doneSets.filter { $0.kind != .warmup }.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }
    var duration: TimeInterval? { endedAt.map { $0.timeIntervalSince(startedAt) } }
}

@Model
final class WorkoutExercise {
    var order: Int = 0
    var notes: String = ""
    var exercise: Exercise?
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
    var sets: [SetEntry]?

    init(order: Int, exercise: Exercise) {
        self.order = order
        self.exercise = exercise
    }

    var sortedSets: [SetEntry] { (sets ?? []).sorted { $0.order < $1.order } }
}

@Model
final class SetEntry {
    var order: Int = 0
    var kindRaw: String = SetKind.normal.rawValue
    var weightKg: Double = 0
    var reps: Int = 0
    var rir: Int?
    var rpe: Double?
    var durationMinutes: Double?
    var distanceKm: Double?
    var isDone: Bool = false
    var completedAt: Date?
    var workoutExercise: WorkoutExercise?

    init(order: Int, kind: SetKind = .normal, weightKg: Double = 0, reps: Int = 0) {
        self.order = order
        self.kindRaw = kind.rawValue
        self.weightKg = weightKg
        self.reps = reps
    }

    var kind: SetKind {
        get { SetKind(rawValue: kindRaw) ?? .normal }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class BodyWeightEntry {
    var date: Date = Date()
    var kg: Double = 0
    /// Gezet als de weging uit Apple Health komt, zodat hij niet dubbel wordt ingelezen.
    var healthSampleID: String?

    init(date: Date = Date(), kg: Double) {
        self.date = date
        self.kg = kg
    }
}

@Model
final class PersonalRecord {
    var date: Date = Date()
    var exerciseSlug: String = ""
    var exerciseName: String = ""
    var kindRaw: String = PRKind.weight.rawValue
    var weightKg: Double = 0
    var reps: Int = 0

    init(date: Date = Date(), exercise: Exercise, kind: PRKind, weightKg: Double, reps: Int) {
        self.date = date
        self.exerciseSlug = exercise.slug
        self.exerciseName = exercise.name
        self.kindRaw = kind.rawValue
        self.weightKg = weightKg
        self.reps = reps
    }

    var kind: PRKind { PRKind(rawValue: kindRaw) ?? .weight }
}

/// Inname: een dagtotaal uit een bron (Apple Health) of een snelle handmatige invoer.
@Model
final class NutritionEntry {
    /// Begin van de dag.
    var date: Date = Date()
    var kcal: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    /// "manual" of de `id` van een `NutritionSource`.
    var sourceRaw: String = NutritionEntry.manual
    var note: String = ""
    var createdAt: Date = Date()

    static let manual = "manual"

    init(date: Date, kcal: Double, proteinG: Double, carbsG: Double, fatG: Double,
         source: String = NutritionEntry.manual, note: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.sourceRaw = source
        self.note = note
    }

    var isManual: Bool { sourceRaw == NutritionEntry.manual }
}

/// Een blok van een paar weken met een vast schema, oplopende inspanning en een deload aan het eind.
@Model
final class TrainingProgram {
    var programID: String = UUID().uuidString
    var goalRaw: String = ProgramGoal.hypertrophy.rawValue
    var planRaw: String = StarterPlan.fullBody.rawValue
    var equipmentRaw: String = Equipment.gym.rawValue
    var daysPerWeek: Int = 3
    var totalWeeks: Int = 5
    var startedAt: Date = Date()
    var endedAt: Date?

    init(goal: ProgramGoal, plan: StarterPlan, equipment: Equipment, daysPerWeek: Int, totalWeeks: Int) {
        self.goalRaw = goal.rawValue
        self.planRaw = plan.rawValue
        self.equipmentRaw = equipment.rawValue
        self.daysPerWeek = daysPerWeek
        self.totalWeeks = totalWeeks
    }

    var goal: ProgramGoal { ProgramGoal(rawValue: goalRaw) ?? .hypertrophy }
    var plan: StarterPlan { StarterPlan(rawValue: planRaw) ?? .fullBody }
    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .gym }
    var isActive: Bool { endedAt == nil }
}

/// Resultaat van een wekelijkse check-in.
@Model
final class CheckIn {
    var date: Date = Date()
    var expenditureKcal: Double = 0
    var confidence: Double = 0
    var averageIntakeKcal: Double = 0
    var trendRatePerWeek: Double = 0
    var loggedDays: Int = 0
    var previousTargetKcal: Double = 0
    var proposedTargetKcal: Double = 0
    var accepted: Bool = false

    init(date: Date = Date(), estimate: ExpenditureEstimate, proposal: CheckInProposal, accepted: Bool) {
        self.date = date
        self.expenditureKcal = estimate.kcal
        self.confidence = estimate.confidence
        self.averageIntakeKcal = estimate.averageIntake ?? 0
        self.trendRatePerWeek = estimate.trendRatePerWeek ?? 0
        self.loggedDays = estimate.loggedDays
        self.previousTargetKcal = proposal.previousKcal
        self.proposedTargetKcal = proposal.targetKcal
        self.accepted = accepted
    }
}

enum AppSchema {
    static var models: [any PersistentModel.Type] { [
        UserProfile.self, Exercise.self, Workout.self, WorkoutExercise.self, SetEntry.self,
        BodyWeightEntry.self, PersonalRecord.self, NutritionEntry.self, CheckIn.self, TrainingProgram.self,
    ] }
}
