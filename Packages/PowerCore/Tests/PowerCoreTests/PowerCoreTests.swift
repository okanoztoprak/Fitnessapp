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

@Suite struct XPTests {
    @Test func levelCurve() {
        #expect(LevelCurve.totalXP(toReach: 1) == 0)
        #expect(LevelCurve.totalXP(toReach: 2) == 100)
        #expect(LevelCurve.totalXP(toReach: 3) == 250)
        #expect(LevelCurve.totalXP(toReach: 4) == 450)
    }

    @Test func progress() {
        #expect(LevelCurve.progress(totalXP: 0) == LevelProgress(level: 1, xpIntoLevel: 0, xpForNextLevel: 100))
        #expect(LevelCurve.progress(totalXP: 100) == LevelProgress(level: 2, xpIntoLevel: 0, xpForNextLevel: 150))
        #expect(LevelCurve.progress(totalXP: 260) == LevelProgress(level: 3, xpIntoLevel: 10, xpForNextLevel: 200))
    }

    @Test func progressMatchesTotals() {
        for level in 1...30 {
            #expect(LevelCurve.progress(totalXP: LevelCurve.totalXP(toReach: level)).level == level)
        }
    }

    @Test func secondWorkoutSameDayEarnsNothing() {
        #expect(XPRules.award(.workout, countTodayForSource: 0, totalToday: 0) == 100)
        #expect(XPRules.award(.workout, countTodayForSource: 1, totalToday: 100) == 0)
    }

    @Test func dailyCap() {
        #expect(XPRules.award(.personalRecord, countTodayForSource: 0, totalToday: 380) == 20)
        #expect(XPRules.award(.weighIn, countTodayForSource: 0, totalToday: 400) == 0)
    }
}

@Suite struct PowerLevelTests {
    @Test func breakdown() {
        let result = PowerLevelCalculator.calculate(PowerLevelInput(
            bodyWeightKg: 80, sex: .male, experience: .beginner,
            liftE1RMs: [.squat: 160], sessionsLast28Days: 12,
            plannedSessionsPerWeek: 3, cardioMinutesPerWeek: 75))
        #expect(result.strength == 1200)
        #expect(result.consistency == 2500)
        #expect(result.conditioning == 600)
        #expect(result.total == 4350)
        #expect(result.stage == .ascended)
    }

    @Test func newUserStartsAsRookie() {
        let result = PowerLevelCalculator.calculate(PowerLevelInput(
            bodyWeightKg: 70, sex: .female, experience: .beginner))
        #expect(result.total == 50)
        #expect(result.stage == .rookie)
    }

    @Test func overtrainingIsNotRewarded() {
        let planned = PowerLevelInput(bodyWeightKg: 80, sex: .male, experience: .beginner,
                                      sessionsLast28Days: 12, plannedSessionsPerWeek: 3)
        var extra = planned
        extra.sessionsLast28Days = 28
        #expect(PowerLevelCalculator.calculate(planned) == PowerLevelCalculator.calculate(extra))
    }

    @Test func femaleStandardsAreScaled() {
        let male = PowerLevelCalculator.calculate(PowerLevelInput(
            bodyWeightKg: 60, sex: .male, experience: .beginner, liftE1RMs: [.bench: 63]))
        let female = PowerLevelCalculator.calculate(PowerLevelInput(
            bodyWeightKg: 60, sex: .female, experience: .beginner, liftE1RMs: [.bench: 63]))
        #expect(male.strength == 840)
        #expect(female.strength == 1200)
    }

    @Test func cappedAtMaximum() {
        let lifts = Dictionary(uniqueKeysWithValues: MainLift.allCases.map { ($0, 1000.0) })
        let result = PowerLevelCalculator.calculate(PowerLevelInput(
            bodyWeightKg: 80, sex: .male, experience: .advanced, liftE1RMs: lifts,
            sessionsLast28Days: 20, plannedSessionsPerWeek: 5, cardioMinutesPerWeek: 300))
        #expect(result.total == 9999)
        #expect(result.stage == .mythic)
    }

    @Test func stageThresholds() {
        #expect(Stage.stage(forPowerLevel: 0) == .rookie)
        #expect(Stage.stage(forPowerLevel: 499) == .rookie)
        #expect(Stage.stage(forPowerLevel: 500) == .kindled)
        #expect(Stage.stage(forPowerLevel: 9999) == .mythic)
        #expect(Stage.rookie.next == .kindled)
        #expect(Stage.mythic.next == nil)
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

@Suite struct StreakTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func countsConsecutiveDays() {
        let days = [start, start - day, start - 2 * day]
        #expect(StreakCalculator.current(activeDays: days, today: start, calendar: calendar) == 3)
    }

    @Test func todayNotYetLoggedKeepsStreak() {
        let days = [start - day, start - 2 * day]
        #expect(StreakCalculator.current(activeDays: days, today: start, calendar: calendar) == 2)
    }

    @Test func gapBreaksStreak() {
        let days = [start, start - 2 * day, start - 3 * day]
        #expect(StreakCalculator.current(activeDays: days, today: start, calendar: calendar) == 1)
        #expect(StreakCalculator.current(activeDays: [start - 3 * day], today: start, calendar: calendar) == 0)
    }

    @Test func multipleEntriesPerDayCountOnce() {
        let days = [start, start + 60, start - day]
        #expect(StreakCalculator.current(activeDays: days, today: start, calendar: calendar) == 2)
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
