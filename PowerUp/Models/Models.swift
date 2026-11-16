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
    var experienceRaw: String = Experience.beginner.rawValue
    var trainingDaysPerWeek: Int = 3
    var equipmentRaw: String = Equipment.gym.rawValue
    var usesMetric: Bool = true
    var mentorToneRaw: String = MentorTone.hype.rawValue
    var hideCalories: Bool = false
    var hideWeight: Bool = false
    var celebratePRs: Bool = true
    var e1rmFormulaRaw: String = OneRepMax.Formula.epley.rawValue
    var restSeconds: Int = 120
    /// Zelf gekozen schema; `nil` volgt het aantal trainingsdagen.
    var preferredPlanRaw: String?

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
    var experience: Experience {
        get { Experience(rawValue: experienceRaw) ?? .beginner }
        set { experienceRaw = newValue.rawValue }
    }
    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .gym }
        set { equipmentRaw = newValue.rawValue }
    }
    var mentorTone: MentorTone {
        get { MentorTone(rawValue: mentorToneRaw) ?? .hype }
        set { mentorToneRaw = newValue.rawValue }
    }
    var e1rmFormula: OneRepMax.Formula {
        get { OneRepMax.Formula(rawValue: e1rmFormulaRaw) ?? .epley }
        set { e1rmFormulaRaw = newValue.rawValue }
    }
    var preferredPlan: StarterPlan? {
        get { preferredPlanRaw.flatMap(StarterPlan.init(rawValue:)) }
        set { preferredPlanRaw = newValue?.rawValue }
    }
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
    }

    func energyInput(weightKg: Double) -> EnergyInput {
        EnergyInput(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex,
                    bodyFatPercent: bodyFatPercent, activity: activity)
    }
}

enum MentorTone: String, CaseIterable {
    case hype, strict, calm
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

    init(date: Date = Date(), kg: Double) {
        self.date = date
        self.kg = kg
    }
}

@Model
final class XPEvent {
    var date: Date = Date()
    var sourceRaw: String = XPSource.workout.rawValue
    var amount: Int = 0

    init(date: Date = Date(), source: XPSource, amount: Int) {
        self.date = date
        self.sourceRaw = source.rawValue
        self.amount = amount
    }

    var source: XPSource { XPSource(rawValue: sourceRaw) ?? .workout }
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

@Model
final class PowerLevelSnapshot {
    var date: Date = Date()
    var total: Int = 0
    var strength: Int = 0
    var consistency: Int = 0
    var conditioning: Int = 0
    var formulaVersion: Int = PowerLevelCalculator.formulaVersion

    init(date: Date = Date(), result: PowerLevelResult) {
        self.date = date
        self.total = result.total
        self.strength = result.strength
        self.consistency = result.consistency
        self.conditioning = result.conditioning
    }
}

enum AppSchema {
    static var models: [any PersistentModel.Type] { [
        UserProfile.self, Exercise.self, Workout.self, WorkoutExercise.self, SetEntry.self,
        BodyWeightEntry.self, XPEvent.self, PersonalRecord.self, PowerLevelSnapshot.self,
    ] }
}
