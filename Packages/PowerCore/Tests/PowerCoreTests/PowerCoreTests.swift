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

@Suite struct MacroSettingsTests {
    @Test func customProteinAndFat() {
        let macros = EnergyCalculator.macros(kcal: 2400, weightKg: 80, goal: .maintain,
                                             proteinPerKg: 2.0, fatShare: 0.3)
        #expect(close(macros.proteinG, 160))
        #expect(close(macros.fatG, 80))
        #expect(close(macros.carbsG, (2400 - 640 - 720) / 4.0))
    }

    @Test func customProteinIgnoresLeanMassAdjustment() {
        let macros = EnergyCalculator.macros(kcal: 2400, weightKg: 100, goal: .maintain,
                                             bodyFatPercent: 30, proteinPerKg: 1.6)
        #expect(close(macros.proteinG, 160))
    }

    @Test func fatShareIsBounded() {
        let macros = EnergyCalculator.macros(kcal: 1800, weightKg: 70, goal: .maintain, fatShare: 0.9)
        #expect(close(macros.fatG, 1800 * 0.45 / 9))
    }
}

@Suite struct AdaptiveExpenditureTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private func dayAt(_ offset: Int) -> Date {
        calendar.startOfDay(for: today).addingTimeInterval(Double(offset) * day)
    }

    private func intake(_ kcal: Double, days: Int = 21) -> [DailyIntake] {
        (1...days).map { DailyIntake(date: dayAt(-$0), kcal: kcal) }
    }

    /// Lineair verloop over 60 dagen, zodat de trend is ingeschoten.
    private func weights(start: Double, perWeek: Double) -> [WeightPoint] {
        (0...60).map { offset in
            WeightPoint(date: dayAt(offset - 60), kg: start + perWeek / 7 * Double(offset))
        }
    }

    @Test func withoutDataUsesTheFormula() {
        let estimate = AdaptiveExpenditure.estimate(intake: [], weights: [], formulaTDEE: 2700,
                                                    today: today, calendar: calendar)
        #expect(estimate.kcal == 2700)
        #expect(estimate.confidence == 0)
        #expect(estimate.observedKcal == nil)
    }

    @Test func stableWeightMeansIntakeIsExpenditure() {
        let estimate = AdaptiveExpenditure.estimate(intake: intake(2500), weights: weights(start: 80, perWeek: 0),
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(estimate.confidence == 1)
        #expect(close(estimate.kcal, 2500, tolerance: 1))
        #expect(estimate.loggedDays == 21)
    }

    @Test func losingWeightMeansExpenditureIsAboveIntake() {
        // 0,5 kg per week verlies = 550 kcal per dag tekort.
        let estimate = AdaptiveExpenditure.estimate(intake: intake(2000), weights: weights(start: 84, perWeek: -0.5),
                                                    formulaTDEE: 2500, today: today, calendar: calendar)
        #expect(close(estimate.kcal, 2550, tolerance: 25))
        #expect(close(estimate.trendRatePerWeek!, -0.5, tolerance: 0.03))
    }

    @Test func incompleteDaysAreIgnored() {
        let mixed = intake(2500, days: 14) + (15...21).map { DailyIntake(date: dayAt(-$0), kcal: 400) }
        let estimate = AdaptiveExpenditure.estimate(intake: mixed, weights: weights(start: 80, perWeek: 0),
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(estimate.loggedDays == 14)
        #expect(close(estimate.averageIntake!, 2500))
    }

    @Test func fewLoggedDaysBlendWithTheFormula() {
        let estimate = AdaptiveExpenditure.estimate(intake: intake(2300, days: 7), weights: weights(start: 80, perWeek: 0),
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(close(estimate.confidence, 0.5))
        #expect(close(estimate.kcal, 2500, tolerance: 1))
    }

    @Test func todayDoesNotCount() {
        let estimate = AdaptiveExpenditure.estimate(intake: [DailyIntake(date: dayAt(0), kcal: 3000)] + intake(2500),
                                                    weights: weights(start: 80, perWeek: 0),
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(close(estimate.averageIntake!, 2500))
    }

    @Test func outliersAreClamped() {
        let estimate = AdaptiveExpenditure.estimate(intake: intake(1200), weights: weights(start: 80, perWeek: 0),
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(close(estimate.observedKcal!, 2700 * 0.65))
    }

    @Test func aTypoInTheWeightIsIgnored() {
        var history = weights(start: 82, perWeek: 0)
        history.append(WeightPoint(date: dayAt(0), kg: 93))
        let estimate = AdaptiveExpenditure.estimate(intake: intake(2500), weights: history,
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(close(estimate.kcal, 2500, tolerance: 1))
        #expect(AdaptiveExpenditure.withoutOutliers(history).count == history.count - 1)
    }

    @Test func tooShortWeightHistoryKeepsTheFormula() {
        let short = [WeightPoint(date: dayAt(-3), kg: 80), WeightPoint(date: dayAt(-1), kg: 79.8)]
        let estimate = AdaptiveExpenditure.estimate(intake: intake(2500), weights: short,
                                                    formulaTDEE: 2700, today: today, calendar: calendar)
        #expect(estimate.kcal == 2700)
        #expect(estimate.loggedDays == 21)
    }
}

@Suite struct WeeklyCheckInTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private let today = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func cutTargetFollowsExpenditure() {
        let proposal = WeeklyCheckIn.propose(previousTarget: 2100, expenditure: 2600, goal: .cut, bmr: 1750, weightKg: 80)
        #expect(proposal.targetKcal == 2080)
        #expect(!proposal.wasStepLimited)
    }

    @Test func stepsAreLimited() {
        let proposal = WeeklyCheckIn.propose(previousTarget: 2000, expenditure: 3000, goal: .maintain, bmr: 1700, weightKg: 80)
        #expect(proposal.targetKcal == 2300)
        #expect(proposal.wasStepLimited)
        #expect(proposal.change == 300)
    }

    @Test func neverBelowBMR() {
        let proposal = WeeklyCheckIn.propose(previousTarget: 1500, expenditure: 1700, goal: .cut, bmr: 1450, weightKg: 50)
        #expect(proposal.targetKcal == 1450)
        #expect(proposal.wasFloored)
    }

    @Test func lossRateIsCappedAtOnePercent() {
        // 80 kg: hooguit 0,8 kg per week = 880 kcal per dag tekort; 20% van 2600 = 520, dat mag.
        let normal = WeeklyCheckIn.propose(previousTarget: 2100, expenditure: 2600, goal: .cut, bmr: 1750, weightKg: 80)
        #expect(!normal.wasRateLimited)
        // 50 kg: hooguit 550 kcal per dag tekort; 20% van 3000 = 600 is te veel.
        let aggressive = WeeklyCheckIn.propose(previousTarget: 2400, expenditure: 3000, goal: .cut, bmr: 1300, weightKg: 50)
        #expect(aggressive.wasRateLimited)
        #expect(aggressive.targetKcal == 2450)
    }

    @Test func dueAfterSevenDays() {
        let sixDaysAgo = today.addingTimeInterval(-6 * day)
        let sevenDaysAgo = today.addingTimeInterval(-7 * day)
        #expect(!WeeklyCheckIn.isDue(lastCheckIn: nil, firstLoggedDay: nil, today: today, calendar: calendar))
        #expect(!WeeklyCheckIn.isDue(lastCheckIn: nil, firstLoggedDay: sixDaysAgo, today: today, calendar: calendar))
        #expect(WeeklyCheckIn.isDue(lastCheckIn: nil, firstLoggedDay: sevenDaysAgo, today: today, calendar: calendar))
        #expect(!WeeklyCheckIn.isDue(lastCheckIn: sixDaysAgo, firstLoggedDay: sevenDaysAgo, today: today, calendar: calendar))
        #expect(WeeklyCheckIn.daysUntilDue(lastCheckIn: sixDaysAgo, firstLoggedDay: nil, today: today, calendar: calendar) == 1)
    }
}

@Suite struct SleepTests {
    private let night = Date(timeIntervalSince1970: 1_700_000_000)
    private func span(_ from: Double, _ to: Double) -> TimeSpan {
        TimeSpan(start: night.addingTimeInterval(from * 3600), end: night.addingTimeInterval(to * 3600))
    }

    @Test func overlappingSourcesCountOnce() {
        #expect(close(SleepCalculator.hours([span(0, 4), span(3, 7)]), 7))
        #expect(close(SleepCalculator.hours([span(0, 3), span(4, 7)]), 6))
        #expect(SleepCalculator.hours([]) == 0)
    }

    @Test func shortSleepLowersReadiness() {
        #expect(ReadinessCalculator.sleepPenalty(hours: nil) == 0)
        #expect(ReadinessCalculator.sleepPenalty(hours: 8) == 0)
        #expect(close(ReadinessCalculator.sleepPenalty(hours: 6), 6))
        #expect(ReadinessCalculator.sleepPenalty(hours: 2) == 20)
        #expect(ReadinessCalculator.readiness(muscleRecovery: [], loadRatio: nil, sleepHours: 5).score == 88)
    }
}


@Suite struct MesocycleTests {
    @Test func fiveWeekHypertrophyBlock() {
        let weeks = (1...5).map { Mesocycle.plan(week: $0, totalWeeks: 5, goal: .hypertrophy) }
        #expect(weeks.map(\.targetRIR) == [3, 2, 2, 1, 4])
        #expect(weeks.map { Mesocycle.sets(plan: $0) } == [3, 4, 4, 5, 2])
        #expect(weeks.map(\.isDeload) == [false, false, false, false, true])
        #expect(weeks.last?.loadFactor == 0.9)
    }

    @Test func strengthKeepsTheSetsFlat() {
        let weeks = (1...4).map { Mesocycle.plan(week: $0, totalWeeks: 4, goal: .strength) }
        #expect(weeks.map { Mesocycle.sets(plan: $0) } == [3, 3, 3, 2])
        #expect(weeks.map(\.targetRIR) == [3, 2, 1, 4])
    }

    @Test func weeksAreClamped() {
        #expect(Mesocycle.plan(week: 0, totalWeeks: 4, goal: .strength).week == 1)
        #expect(Mesocycle.plan(week: 9, totalWeeks: 4, goal: .strength).isDeload)
    }

    @Test func repRanges() {
        #expect(Mesocycle.repRange(goal: .strength, compound: true) == 3...6)
        #expect(Mesocycle.repRange(goal: .hypertrophy, compound: false) == 10...15)
    }

    @Test func positionFollowsCompletedSessions() {
        let start = Mesocycle.position(completedSessions: 0, daysPerWeek: 3, rotationLength: 2, totalWeeks: 5)
        #expect(start == ProgramPosition(week: 1, sessionInWeek: 0, dayIndex: 0, isFinished: false))
        // Na vier trainingen: week 2, tweede training van de week, A/B-rotatie weer bij A.
        let later = Mesocycle.position(completedSessions: 4, daysPerWeek: 3, rotationLength: 2, totalWeeks: 5)
        #expect(later == ProgramPosition(week: 2, sessionInWeek: 1, dayIndex: 0, isFinished: false))
        let done = Mesocycle.position(completedSessions: 15, daysPerWeek: 3, rotationLength: 2, totalWeeks: 5)
        #expect(done.isFinished)
        #expect(done.week == 5)
    }
}

@Suite struct VolumeGuideTests {
    @Test func targetWithoutProgramIsTheProductiveRange() {
        #expect(VolumeGuide.target(VolumeGuide.landmarks(size: .large), plan: nil) == 12...18)
    }

    @Test func targetGrowsThroughTheBlock() {
        let large = VolumeGuide.landmarks(size: .large)
        let first = VolumeGuide.target(large, plan: Mesocycle.plan(week: 1, totalWeeks: 5, goal: .hypertrophy))
        let last = VolumeGuide.target(large, plan: Mesocycle.plan(week: 4, totalWeeks: 5, goal: .hypertrophy))
        let deload = VolumeGuide.target(large, plan: Mesocycle.plan(week: 5, totalWeeks: 5, goal: .hypertrophy))
        #expect(first == 8...12)
        #expect(last == 12...18)
        #expect(deload == 4...8)
    }

    @Test func status() {
        let small = VolumeGuide.landmarks(size: .small)
        #expect(VolumeGuide.status(sets: 3, landmarks: small) == .low)
        #expect(VolumeGuide.status(sets: 10, landmarks: small) == .productive)
        #expect(VolumeGuide.status(sets: 20, landmarks: small) == .high)
    }
}

@Suite struct PlateauAndDeloadTests {
    @Test func plateauNeedsEnoughSessions() {
        #expect(!PlateauDetector.isPlateau([100, 100, 100]))
    }

    @Test func noProgressForThreeSessionsIsAPlateau() {
        #expect(PlateauDetector.isPlateau([95, 100, 99, 100, 100.3]))
        #expect(!PlateauDetector.isPlateau([95, 100, 99, 100, 102]))
    }

    @Test func deloadReasons() {
        #expect(DeloadAdvisor.advise(weeksInARow: 2, stalledLifts: 0, trackedLifts: 3, loadRatio: 1.6)?.reason == .highLoad)
        #expect(DeloadAdvisor.advise(weeksInARow: 2, stalledLifts: 2, trackedLifts: 4, loadRatio: 1)?.reason == .stalled)
        #expect(DeloadAdvisor.advise(weeksInARow: 8, stalledLifts: 0, trackedLifts: 4, loadRatio: 1)?.reason == .longBlock)
        #expect(DeloadAdvisor.advise(weeksInARow: 3, stalledLifts: 1, trackedLifts: 4, loadRatio: 1.1) == nil)
        // Eén oefening die stilstaat is nog geen reden.
        #expect(DeloadAdvisor.advise(weeksInARow: 3, stalledLifts: 1, trackedLifts: 1, loadRatio: nil) == nil)
    }

    @Test func deloadWeightRoundsToTheIncrement() {
        #expect(DeloadAdvisor.deloadWeight(100, increment: 2.5) == 90)
        #expect(DeloadAdvisor.deloadWeight(62.5, increment: 2.5) == 57.5)
        #expect(DeloadAdvisor.deloadWeight(0, increment: 2.5) == 0)
    }
}
