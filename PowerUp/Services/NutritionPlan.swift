import Foundation
import PowerCore
import SwiftData

/// Alles wat de voedingsschermen nodig hebben, uitgerekend uit profiel, wegingen en inname.
/// De rekenregels staan in PowerCore.
@MainActor
struct NutritionPlan {
    let weightKg: Double
    let formula: CalorieTarget
    let expenditure: ExpenditureEstimate
    /// Doel dat nu geldt: uit de laatste check-in, anders uit de formule.
    let targetKcal: Double
    let isFromCheckIn: Bool
    let macros: MacroTarget
    let today: DailyIntake
    /// Dagtotalen, oud naar nieuw.
    let days: [DailyIntake]
    let firstLoggedDay: Date?

    init(profile: UserProfile, weights: [BodyWeightEntry], entries: [NutritionEntry], now: Date = Date()) {
        let sortedWeights = weights.sorted { $0.date < $1.date }
        let points = sortedWeights.map { WeightPoint(date: $0.date, kg: $0.kg) }
        weightKg = WeightTrend.ema(AdaptiveExpenditure.withoutOutliers(points)).last?.kg ?? sortedWeights.last?.kg ?? 75
        formula = EnergyCalculator.target(profile.energyInput(weightKg: weightKg), goal: profile.goal)
        days = Self.dailyTotals(entries)
        firstLoggedDay = days.first?.date
        expenditure = AdaptiveExpenditure.estimate(intake: days, weights: points, formulaTDEE: formula.tdee, today: now)
        if let saved = profile.calorieTargetKcal, saved > 0 {
            targetKcal = max(saved, formula.bmr)
            isFromCheckIn = true
        } else {
            targetKcal = formula.kcal
            isFromCheckIn = false
        }
        macros = EnergyCalculator.macros(kcal: targetKcal, weightKg: weightKg, goal: profile.goal,
                                         bodyFatPercent: profile.bodyFatPercent,
                                         proteinPerKg: profile.proteinPerKg, fatShare: profile.fatShare)
        let start = Calendar.current.startOfDay(for: now)
        today = days.first { $0.date == start } ?? DailyIntake(date: start, kcal: 0)
    }

    /// Verwachte verandering in kg per week bij dit doel, op basis van het beste verbruik.
    var expectedWeeklyChangeKg: Double {
        (targetKcal - expenditure.kcal) * 7 / EnergyCalculator.kcalPerKg
    }

    var exceedsSafeLossRate: Bool { -expectedWeeklyChangeKg > weightKg * 0.01 }
    var isFloored: Bool { targetKcal <= formula.bmr + 0.5 }

    /// Laatste zeven dagen inclusief vandaag, ook de lege.
    func lastWeek(now: Date = Date()) -> [DailyIntake] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return days.first { $0.date == day } ?? DailyIntake(date: day, kcal: 0)
        }
    }

    func proposal(goal: Goal) -> CheckInProposal {
        WeeklyCheckIn.propose(previousTarget: targetKcal, expenditure: expenditure.kcal, goal: goal,
                              bmr: formula.bmr, weightKg: weightKg)
    }

    static func dailyTotals(_ entries: [NutritionEntry]) -> [DailyIntake] {
        let calendar = Calendar.current
        var totals: [Date: DailyIntake] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            var total = totals[day] ?? DailyIntake(date: day, kcal: 0)
            total.kcal += entry.kcal
            total.proteinG += entry.proteinG
            total.carbsG += entry.carbsG
            total.fatG += entry.fatG
            totals[day] = total
        }
        return totals.values.sorted { $0.date < $1.date }
    }
}

/// Haalt data op uit een bron en zet die in SwiftData.
@MainActor
enum HealthSync {
    struct Result {
        var days = 0
        var weights = 0
        var sleepHours: Double?
    }

    static let lookbackDays = 35

    @discardableResult
    static func run(profile: UserProfile, context: ModelContext, source: some NutritionSource = HealthKitService.shared,
                    health: HealthKitService = .shared, now: Date = Date()) async throws -> Result {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: calendar.startOfDay(for: now)) ?? now
        var result = Result()

        // Voeding: dagtotalen van de bron vervangen wat eerder uit dezelfde bron kwam.
        let days = try await source.dailyNutrition(from: start, to: end)
        let sourceID = source.id
        let existing = (try? context.fetch(FetchDescriptor<NutritionEntry>(
            predicate: #Predicate { $0.sourceRaw == sourceID && $0.date >= start }))) ?? []
        for entry in existing { context.delete(entry) }
        for day in days {
            context.insert(NutritionEntry(date: day.date, kcal: day.kcal, proteinG: day.proteinG,
                                          carbsG: day.carbsG, fatG: day.fatG, source: sourceID))
        }
        result.days = days.count

        // Gewicht: nieuwe metingen erbij, niet op dagen met een handmatige weging.
        let weights = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
        let knownIDs = Set(weights.compactMap(\.healthSampleID))
        let manualDays = Set(weights.filter { $0.healthSampleID == nil }.map { calendar.startOfDay(for: $0.date) })
        let weightStart = calendar.date(byAdding: .day, value: -90, to: now) ?? start
        for sample in try await health.bodyWeights(from: weightStart, to: end)
        where !knownIDs.contains(sample.id) && !manualDays.contains(calendar.startOfDay(for: sample.date)) {
            let entry = BodyWeightEntry(date: sample.date, kg: sample.kg)
            entry.healthSampleID = sample.id
            context.insert(entry)
            result.weights += 1
        }

        // Slaap is optioneel; een fout daar mag de rest niet tegenhouden.
        if let hours = try? await health.lastNightSleepHours(now: now) {
            profile.lastSleepHours = hours
            profile.lastSleepDate = now
            result.sleepHours = hours
        }
        profile.lastHealthSync = now
        context.saveOrLog()
        return result
    }
}
