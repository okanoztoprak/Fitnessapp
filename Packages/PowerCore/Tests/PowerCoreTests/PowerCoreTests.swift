import Foundation
import Testing
@testable import PowerCore

private func close(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) <= tolerance
}

private let day: TimeInterval = 86_400
private let start = Date(timeIntervalSince1970: 1_700_000_000)

@Suite struct UnitTests {
    @Test func roundTrips() {
        #expect(close(UnitConversion.kgToLb(100), 220.46))
        #expect(close(UnitConversion.lbToKg(UnitConversion.kgToLb(82.5)), 82.5, tolerance: 1e-9))
        #expect(close(UnitConversion.cmToInch(180), 70.87))
        #expect(close(UnitConversion.inchToCm(70), 177.8))
    }
}

@Suite struct OneRepMaxTests {
    @Test func epley() {
        #expect(close(OneRepMax.estimate(weight: 100, reps: 5)!, 116.67))
    }

    @Test func brzycki() {
        #expect(close(OneRepMax.estimate(weight: 100, reps: 5, formula: .brzycki)!, 112.5))
    }

    @Test func singleIsTheWeightItself() {
        #expect(OneRepMax.estimate(weight: 140, reps: 1) == 140)
        #expect(OneRepMax.estimate(weight: 140, reps: 1, formula: .brzycki) == 140)
    }

    @Test func rejectsUnusableSets() {
        #expect(OneRepMax.estimate(weight: 100, reps: 0) == nil)
        #expect(OneRepMax.estimate(weight: 100, reps: 11) == nil)
        #expect(OneRepMax.estimate(weight: 0, reps: 5) == nil)
    }
}

@Suite struct EnergyTests {
    let man = EnergyInput(weightKg: 80, heightCm: 180, age: 30, sex: .male, activity: .moderate)

    @Test func mifflinMale() {
        let result = EnergyCalculator.bmr(man)
        #expect(close(result.value, 1780))
        #expect(result.formula == .mifflinStJeor)
    }

    @Test func mifflinFemale() {
        let woman = EnergyInput(weightKg: 60, heightCm: 165, age: 25, sex: .female, activity: .light)
        #expect(close(EnergyCalculator.bmr(woman).value, 1345.25))
    }

    @Test func katchWhenBodyFatKnown() {
        var input = man
        input.bodyFatPercent = 20
        let result = EnergyCalculator.bmr(input)
        #expect(close(result.value, 1752.4))
        #expect(result.formula == .katchMcArdle)
    }

    @Test func tdeeUsesActivityMultiplier() {
        #expect(close(EnergyCalculator.tdee(man), 2759))
    }

    @Test func cutTarget() {
        let target = EnergyCalculator.target(man, goal: .cut)
        #expect(close(target.kcal, 2207.2))
        #expect(!target.wasFloored)
        #expect(close(target.expectedWeeklyChangeKg, -0.5016, tolerance: 0.001))
        #expect(!target.exceedsSafeLossRate)
    }

    @Test func cutNeverGoesBelowBMR() {
        var input = man
        input.activity = .sedentary
        let target = EnergyCalculator.target(input, goal: .cut)
        #expect(close(target.kcal, 1780))
        #expect(target.wasFloored)
    }

    @Test func bulkAndMaintain() {
        #expect(close(EnergyCalculator.target(man, goal: .bulk).kcal, 3034.9))
        #expect(close(EnergyCalculator.target(man, goal: .maintain).kcal, 2759))
        #expect(close(EnergyCalculator.target(man, goal: .maintain).expectedWeeklyChangeKg, 0))
    }

    @Test func macrosAddUpToCalories() {
        let macros = EnergyCalculator.macros(kcal: 2000, weightKg: 80, goal: .maintain)
        #expect(close(macros.proteinG, 144))
        #expect(close(macros.fatG, 55.56))
        #expect(close(macros.carbsG, 231))
        let total = macros.proteinG * 4 + macros.carbsG * 4 + macros.fatG * 9
        #expect(close(total, 2000))
    }

    @Test func cutRaisesProtein() {
        let macros = EnergyCalculator.macros(kcal: 2200, weightKg: 80, goal: .cut)
        #expect(close(macros.proteinG, 176))
    }

    @Test func highBodyFatUsesLeanMass() {
        let macros = EnergyCalculator.macros(kcal: 2200, weightKg: 120, goal: .maintain, bodyFatPercent: 40)
        #expect(close(macros.proteinG, 72 * 2.2))
    }
}

@Suite struct WeightTrendTests {
    @Test func emptyAndSingle() {
        #expect(WeightTrend.ema([]).isEmpty)
        let one = WeightTrend.ema([WeightPoint(date: start, kg: 80)])
        #expect(one == [WeightPoint(date: start, kg: 80)])
    }

    @Test func constantWeightStaysConstant() {
        let points = (0..<10).map { WeightPoint(date: start + Double($0) * day, kg: 75) }
        #expect(WeightTrend.ema(points).allSatisfy { close($0.kg, 75, tolerance: 1e-9) })
    }

    @Test func dailyStep() {
        let trend = WeightTrend.ema([
            WeightPoint(date: start, kg: 80),
            WeightPoint(date: start + day, kg: 81),
        ])
        #expect(close(trend[1].kg, 80.1, tolerance: 1e-9))
    }

    @Test func gapIsInterpolated() {
        let trend = WeightTrend.ema([
            WeightPoint(date: start, kg: 80),
            WeightPoint(date: start + 2 * day, kg: 82),
        ])
        #expect(close(trend[1].kg, 80.29, tolerance: 1e-9))
    }

    @Test func sortsInput() {
        let trend = WeightTrend.ema([
            WeightPoint(date: start + day, kg: 81),
            WeightPoint(date: start, kg: 80),
        ])
        #expect(trend.first?.date == start)
    }

    @Test func spikeIsDamped() {
        var points = (0..<7).map { WeightPoint(date: start + Double($0) * day, kg: 80) }
        points.append(WeightPoint(date: start + 7 * day, kg: 82))
        #expect(close(WeightTrend.ema(points).last!.kg, 80.2, tolerance: 1e-9))
    }

    @Test func weeklyRate() {
        let trend = (0...14).map { WeightPoint(date: start + Double($0) * day, kg: 80 - Double($0) * 0.1) }
        #expect(close(WeightTrend.weeklyRate(trend: trend)!, -0.7, tolerance: 1e-6))
        #expect(WeightTrend.weeklyRate(trend: Array(trend.prefix(2))) == nil)
    }
}

@Suite struct PRTests {
    let history = [SetPerformance(weight: 80, reps: 8)]

    @Test func noHistoryMeansNoPR() {
        #expect(PRDetector.detect(set: SetPerformance(weight: 100, reps: 5), history: []).isEmpty)
    }

    @Test func heavierWeight() {
        let kinds = PRDetector.detect(set: SetPerformance(weight: 82.5, reps: 8), history: history)
        #expect(kinds == [.weight, .volume, .e1rm])
    }

    @Test func moreRepsAtSameWeight() {
        let kinds = PRDetector.detect(set: SetPerformance(weight: 80, reps: 9), history: history)
        #expect(kinds == [.reps, .volume, .e1rm])
    }

    @Test func lighterSetIsNoPR() {
        #expect(PRDetector.detect(set: SetPerformance(weight: 60, reps: 8), history: history).isEmpty)
    }

    @Test func equalSetIsNoPR() {
        #expect(PRDetector.detect(set: SetPerformance(weight: 80, reps: 8), history: history).isEmpty)
    }

    @Test func highRepSetIsNoE1RMPR() {
        let kinds = PRDetector.detect(set: SetPerformance(weight: 50, reps: 20), history: history)
        #expect(kinds == [.reps, .volume])
    }
}

@Suite struct PlateTests {
    @Test func simpleLoad() {
        let loadout = PlateCalculator.loadout(target: 100, bar: 20, plates: PlateCalculator.standardKg)
        #expect(loadout == PlateLoadout(perSide: [25, 15], remainder: 0))
    }

    @Test func remainder() {
        let loadout = PlateCalculator.loadout(target: 101, bar: 20, plates: PlateCalculator.standardKg)
        #expect(loadout.perSide == [25, 15])
        #expect(close(loadout.remainder, 1))
    }

    @Test func repeatedAndSmallPlates() {
        let loadout = PlateCalculator.loadout(target: 142.5, bar: 20, plates: PlateCalculator.standardKg)
        #expect(loadout == PlateLoadout(perSide: [25, 25, 10, 1.25], remainder: 0))
    }

    @Test func belowBar() {
        let loadout = PlateCalculator.loadout(target: 15, bar: 20, plates: PlateCalculator.standardKg)
        #expect(loadout == PlateLoadout(perSide: [], remainder: 0))
    }
}

@Suite struct StarterPlanTests {
    @Test func recommendation() {
        #expect(StarterPlan.recommend(daysPerWeek: 2) == .fullBody)
        #expect(StarterPlan.recommend(daysPerWeek: 3) == .fullBody)
        #expect(StarterPlan.recommend(daysPerWeek: 4) == .upperLower)
        #expect(StarterPlan.recommend(daysPerWeek: 6) == .pushPullLegs)
    }
}

@Suite struct ProgressionTests {
    private func sets(_ weight: Double, _ reps: [Int]) -> [SetPerformance] {
        reps.map { SetPerformance(weight: weight, reps: $0) }
    }

    @Test func noHistoryGivesNoSuggestion() {
        #expect(ProgressionAdvisor.suggest(lastSets: [], increment: 2.5) == nil)
    }

    @Test func addsWeightWhenAllSetsHitTheTop() {
        let suggestion = ProgressionAdvisor.suggest(lastSets: sets(60, [12, 12, 12]), increment: 2.5)
        #expect(suggestion == ProgressionSuggestion(weight: 62.5, reps: 8, reason: .addWeight))
    }

    @Test func addsARepInsideTheRange() {
        let suggestion = ProgressionAdvisor.suggest(lastSets: sets(60, [10, 9, 9]), increment: 2.5)
        #expect(suggestion == ProgressionSuggestion(weight: 60, reps: 10, reason: .addReps))
    }

    @Test func consolidatesBelowTheRange() {
        let suggestion = ProgressionAdvisor.suggest(lastSets: sets(100, [6, 5, 4]), increment: 2.5)
        #expect(suggestion == ProgressionSuggestion(weight: 100, reps: 8, reason: .consolidate))
    }

    @Test func lighterSetsDoNotCountAsWorkingSets() {
        let history = sets(40, [15]) + sets(60, [12, 12])
        #expect(ProgressionAdvisor.suggest(lastSets: history, increment: 2.5)?.reason == .addWeight)
    }

    @Test func bodyweightOnlyAddsReps() {
        let suggestion = ProgressionAdvisor.suggest(lastSets: sets(0, [12, 10, 9]), increment: 2.5)
        #expect(suggestion == ProgressionSuggestion(weight: 0, reps: 10, reason: .addReps))
    }
}

@Suite struct SessionAdvisorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// Maandag 13 november 2023, 12:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_699_876_800)
    private func date(_ offset: Int) -> Date { monday.addingTimeInterval(Double(offset) * day) }

    @Test func firstSession() {
        let advice = SessionAdvisor.advise(workoutDays: [], plannedPerWeek: 3, today: monday, calendar: calendar)
        #expect(advice.kind == .train)
        #expect(advice.reason == .firstSession)
    }

    @Test func restAfterTrainingToday() {
        let advice = SessionAdvisor.advise(workoutDays: [monday], plannedPerWeek: 3, today: monday, calendar: calendar)
        #expect(advice == SessionAdvice(kind: .rest, reason: .trainedToday, sessionsThisWeek: 1))
    }

    @Test func restWhenWeeklyGoalIsReached() {
        let advice = SessionAdvisor.advise(workoutDays: [date(0), date(1), date(3)], plannedPerWeek: 3,
                                           today: date(4), calendar: calendar)
        #expect(advice.reason == .weeklyGoalReached)
    }

    @Test func restAfterTwoDaysInARow() {
        let advice = SessionAdvisor.advise(workoutDays: [date(0), date(1)], plannedPerWeek: 4,
                                           today: date(2), calendar: calendar)
        #expect(advice.reason == .consecutiveDays)
    }

    @Test func sixDaySchemesMayTrainThreeDaysInARow() {
        let advice = SessionAdvisor.advise(workoutDays: [date(0), date(1)], plannedPerWeek: 6,
                                           today: date(2), calendar: calendar)
        #expect(advice.kind == .train)
    }

    @Test func behindScheduleLateInTheWeek() {
        // Zaterdag, 1 van 3 gedaan: nog twee dagen voor twee sessies.
        let advice = SessionAdvisor.advise(workoutDays: [date(0)], plannedPerWeek: 3, today: date(5), calendar: calendar)
        #expect(advice == SessionAdvice(kind: .train, reason: .behindSchedule, sessionsThisWeek: 1))
    }

    @Test func onTrackEarlyInTheWeek() {
        let advice = SessionAdvisor.advise(workoutDays: [date(-3)], plannedPerWeek: 3, today: date(1), calendar: calendar)
        #expect(advice == SessionAdvice(kind: .train, reason: .onTrack, sessionsThisWeek: 0))
    }

    @Test func nextDayPrefersNeverDoneThenOldest() {
        #expect(SessionAdvisor.nextDayIndex(lastPerformed: []) == nil)
        #expect(SessionAdvisor.nextDayIndex(lastPerformed: [date(0), nil, nil]) == 1)
        #expect(SessionAdvisor.nextDayIndex(lastPerformed: [date(2), date(0), date(1)]) == 1)
    }
}

@Suite struct StrengthTests {
    @Test func fractionAgainstEliteStandard() {
        // Squat: elite is 2,0 × lichaamsgewicht.
        #expect(close(StrengthStandards.fraction(e1rm: 80, bodyWeightKg: 80, lift: .squat, sex: .male), 0.5))
        #expect(close(StrengthStandards.fraction(e1rm: 56, bodyWeightKg: 80, lift: .squat, sex: .female), 0.5))
        #expect(StrengthStandards.fraction(e1rm: 0, bodyWeightKg: 80, lift: .squat, sex: .male) == 0)
        #expect(StrengthStandards.fraction(e1rm: 100, bodyWeightKg: 0, lift: .squat, sex: .male) == 0)
    }

    @Test func levels() {
        #expect(StrengthStandards.level(fraction: 0.1) == .beginner)
        #expect(StrengthStandards.level(fraction: 0.35) == .novice)
        #expect(StrengthStandards.level(fraction: 0.6) == .intermediate)
        #expect(StrengthStandards.level(fraction: 0.75) == .advanced)
        #expect(StrengthStandards.level(fraction: 1.1) == .elite)
    }

    @Test func progressAndNextTarget() {
        #expect(close(StrengthStandards.progressToNext(fraction: 0.6), 0.5))
        #expect(StrengthStandards.progressToNext(fraction: 1.0) == 1)
        // Van gevorderd (0,5) naar ver gevorderd (0,7) bij 80 kg: 0,7 × 160 = 112 kg.
        let target = StrengthStandards.nextTarget(fraction: 0.6, bodyWeightKg: 80, lift: .squat, sex: .male)
        #expect(close(target!, 112))
        #expect(StrengthStandards.nextTarget(fraction: 0.95, bodyWeightKg: 80, lift: .squat, sex: .male) == nil)
    }
}

@Suite struct InsightTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// Maandag 13 november 2023, 12:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_699_876_800)
    private func date(_ offset: Int) -> Date { monday.addingTimeInterval(Double(offset) * day) }

    @Test func recoveryTakesLongerAfterMoreSets() {
        #expect(MuscleRecovery.hoursToRecover(sets: 3) == 48)
        #expect(MuscleRecovery.hoursToRecover(sets: 8) == 72)
        #expect(MuscleRecovery.hoursToRecover(sets: 40) == 96)
    }

    @Test func recoveryFraction() {
        #expect(MuscleRecovery.fraction(hoursSinceTrained: nil, sets: 0) == 1)
        #expect(close(MuscleRecovery.fraction(hoursSinceTrained: 24, sets: 4), 0.5))
        #expect(MuscleRecovery.fraction(hoursSinceTrained: 200, sets: 4) == 1)
        #expect(MuscleRecovery.fraction(hoursSinceTrained: -5, sets: 4) == 0)
    }

    @Test func loadRatioAndStatus() {
        #expect(TrainingLoad.ratio(last7Days: 30, previous28Days: 0) == nil)
        #expect(close(TrainingLoad.ratio(last7Days: 30, previous28Days: 80)!, 1.5))
        #expect(TrainingLoad.status(ratio: nil) == .building)
        #expect(TrainingLoad.status(ratio: 0.5) == .low)
        #expect(TrainingLoad.status(ratio: 1.0) == .steady)
        #expect(TrainingLoad.status(ratio: 1.6) == .high)
    }

    @Test func readinessWithoutDataIsFull() {
        #expect(ReadinessCalculator.readiness(muscleRecovery: [], loadRatio: nil) == Readiness(score: 100))
    }

    @Test func readinessFollowsRecoveryAndBands() {
        #expect(ReadinessCalculator.readiness(muscleRecovery: [1, 1, 1, 1], loadRatio: 1.0).band == .high)
        let half = ReadinessCalculator.readiness(muscleRecovery: [0, 1], loadRatio: nil)
        #expect(half.score == 50)
        #expect(half.band == .moderate)
        #expect(ReadinessCalculator.readiness(muscleRecovery: [0.1, 0.2], loadRatio: nil).band == .low)
    }

    @Test func highLoadLowersReadinessWithACap() {
        #expect(ReadinessCalculator.readiness(muscleRecovery: [1], loadRatio: 1.5).score == 90)
        #expect(ReadinessCalculator.readiness(muscleRecovery: [1], loadRatio: 5).score == 75)
    }

    @Test func weekStreakCountsConsecutiveWeeks() {
        #expect(WeekStreak.current(workoutDays: [], today: monday, calendar: calendar) == 0)
        // Deze week, vorige week en de week daarvoor.
        #expect(WeekStreak.current(workoutDays: [date(1), date(-3), date(-10)], today: date(2), calendar: calendar) == 3)
    }

    @Test func emptyCurrentWeekDoesNotBreakTheStreak() {
        #expect(WeekStreak.current(workoutDays: [date(-3), date(-10)], today: date(1), calendar: calendar) == 2)
    }

    @Test func aMissedWeekBreaksTheStreak() {
        #expect(WeekStreak.current(workoutDays: [date(1), date(-10)], today: date(2), calendar: calendar) == 1)
    }
}
