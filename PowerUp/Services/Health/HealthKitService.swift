import Foundation
import HealthKit
import PowerCore

/// Apple Health: voeding (ook wat MyFitnessPal daar neerzet), lichaamsgewicht en slaap. Alleen lezen.
final class HealthKitService: NutritionSource {
    static let shared = HealthKitService()

    let id = "health"
    let displayName = "Apple Health"
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let nutritionTypes: [(HKQuantityTypeIdentifier, HKUnit)] = [
        (.dietaryEnergyConsumed, .kilocalorie()),
        (.dietaryProtein, .gram()),
        (.dietaryCarbohydrates, .gram()),
        (.dietaryFatTotal, .gram()),
    ]

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>(Self.nutritionTypes.map { HKQuantityType($0.0) })
        types.insert(HKQuantityType(.bodyMass))
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }

    func requestAccess() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: Voeding

    func dailyNutrition(from start: Date, to end: Date) async throws -> [DailyNutrition] {
        let calendar = Calendar.current
        var totals: [Date: [HKQuantityTypeIdentifier: Double]] = [:]
        for (identifier, unit) in Self.nutritionTypes {
            for (day, value) in try await dailySums(identifier, unit: unit, from: start, to: end, calendar: calendar) {
                totals[day, default: [:]][identifier] = value
            }
        }
        return totals.map { day, values in
            DailyNutrition(date: day,
                           kcal: values[.dietaryEnergyConsumed] ?? 0,
                           proteinG: values[.dietaryProtein] ?? 0,
                           carbsG: values[.dietaryCarbohydrates] ?? 0,
                           fatG: values[.dietaryFatTotal] ?? 0)
        }
        .filter { $0.kcal > 0 || $0.proteinG > 0 }
        .sorted { $0.date < $1.date }
    }

    private func dailySums(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date,
                           calendar: Calendar) async throws -> [Date: Double] {
        let anchor = calendar.startOfDay(for: start)
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: anchor, end: end))
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate, options: .cumulativeSum, anchorDate: anchor,
            intervalComponents: DateComponents(day: 1))
        let collection = try await descriptor.result(for: store)
        var result: [Date: Double] = [:]
        for statistics in collection.statistics() {
            if let sum = statistics.sumQuantity()?.doubleValue(for: unit), sum > 0 {
                result[calendar.startOfDay(for: statistics.startDate)] = sum
            }
        }
        return result
    }

    // MARK: Gewicht

    func bodyWeights(from start: Date, to end: Date) async throws -> [ExternalWeight] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass),
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return try await descriptor.result(for: store).map {
            ExternalWeight(id: $0.uuid.uuidString, date: $0.startDate,
                           kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
        }
    }

    // MARK: Slaap

    /// Slaap van de afgelopen nacht (18:00 gisteren tot nu); `nil` zonder metingen.
    func lastNightSleepHours(now: Date = Date()) async throws -> Double? {
        let calendar = Calendar.current
        let evening = calendar.date(byAdding: .hour, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis),
                                         predicate: HKQuery.predicateForSamples(withStart: evening, end: now))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let spans = try await descriptor.result(for: store)
            .filter { asleep.contains($0.value) }
            .map { TimeSpan(start: $0.startDate, end: $0.endDate) }
        guard !spans.isEmpty else { return nil }
        return SleepCalculator.hours(spans)
    }

    enum HealthError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            String(localized: "Apple Health is niet beschikbaar op dit apparaat.")
        }
    }
}

#if DEBUG
extension HealthKitService {
    /// Alleen voor testen in de simulator: zet drie weken voorbeeldvoeding, -gewicht en -slaap in Health.
    func writeSampleData(now: Date = Date()) async throws {
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.bodyMass), HKCategoryType(.sleepAnalysis),
        ]
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        let calendar = Calendar.current
        var samples: [HKSample] = []
        for offset in 0..<22 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)),
                  let meal = calendar.date(byAdding: .hour, value: 13, to: day) else { continue }
            // Ongeveer 2250 kcal met wat variatie; vandaag nog maar een deel van de dag.
            let wiggle = Double((offset * 37) % 300) - 150
            let share = offset == 0 ? 0.55 : 1.0
            let kcal = (2250 + wiggle) * share
            let values: [(HKQuantityTypeIdentifier, HKQuantity)] = [
                (.dietaryEnergyConsumed, HKQuantity(unit: .kilocalorie(), doubleValue: kcal)),
                (.dietaryProtein, HKQuantity(unit: .gram(), doubleValue: 165 * share)),
                (.dietaryCarbohydrates, HKQuantity(unit: .gram(), doubleValue: 230 * share)),
                (.dietaryFatTotal, HKQuantity(unit: .gram(), doubleValue: 70 * share)),
            ]
            for (identifier, quantity) in values {
                samples.append(HKQuantitySample(type: HKQuantityType(identifier), quantity: quantity, start: meal, end: meal))
            }
            if offset % 2 == 0, let morning = calendar.date(byAdding: .hour, value: 7, to: day) {
                // Langzaam dalend gewicht met dagelijkse ruis.
                let kg = 82.0 - 0.06 * Double(21 - offset) + (offset % 3 == 0 ? 0.4 : -0.2)
                samples.append(HKQuantitySample(type: HKQuantityType(.bodyMass),
                                                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                                start: morning, end: morning))
            }
        }
        if let bedtime = calendar.date(byAdding: .hour, value: -1, to: calendar.startOfDay(for: now)),
           let wake = calendar.date(byAdding: .minute, value: 6 * 60 + 20, to: calendar.startOfDay(for: now)) {
            samples.append(HKCategorySample(type: HKCategoryType(.sleepAnalysis),
                                            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                            start: bedtime, end: wake))
        }
        try await store.save(samples)
    }
}
#endif
