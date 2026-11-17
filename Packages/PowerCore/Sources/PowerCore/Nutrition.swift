import Foundation

/// Totale inname van één kalenderdag.
public struct DailyIntake: Sendable, Equatable {
    public var date: Date
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(date: Date, kcal: Double, proteinG: Double = 0, carbsG: Double = 0, fatG: Double = 0) {
        self.date = date
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

// MARK: - Adaptief verbruik

public struct ExpenditureEstimate: Sendable, Equatable {
    /// Beste schatting van het dagverbruik.
    public var kcal: Double
    /// Schatting uit de formule (BMR × activiteit).
    public var formulaKcal: Double
    /// Verbruik afgeleid uit inname en gewichtstrend; `nil` zonder genoeg data.
    public var observedKcal: Double?
    /// 0 = alleen formule, 1 = alleen gemeten.
    public var confidence: Double
    /// Volledig gelogde dagen in het venster.
    public var loggedDays: Int
    /// Gemiddelde inname op gelogde dagen.
    public var averageIntake: Double?
    /// Verandering van het trendgewicht in kg per week.
    public var trendRatePerWeek: Double?
}

/// Verbruik uit de energiebalans: inname minus de energie die in de gewichtsverandering zit.
/// Zolang er weinig data is, weegt de formule zwaarder mee.
public enum AdaptiveExpenditure {
    public static let windowDays = 21
    public static let minimumLoggedDays = 7
    public static let fullConfidenceDays = 14.0
    /// Dagen met minder dan dit deel van het formuleverbruik gelden als onvolledig gelogd.
    public static let completeLogFraction = 0.4

    public static func estimate(intake: [DailyIntake], weights: [WeightPoint], formulaTDEE: Double,
                                today: Date, calendar: Calendar = .current) -> ExpenditureEstimate {
        let formulaOnly = ExpenditureEstimate(kcal: formulaTDEE, formulaKcal: formulaTDEE, observedKcal: nil,
                                              confidence: 0, loggedDays: 0, averageIntake: nil,
                                              trendRatePerWeek: nil)
        let end = calendar.startOfDay(for: today)
        guard formulaTDEE > 0,
              let start = calendar.date(byAdding: .day, value: -windowDays, to: end) else { return formulaOnly }

        // Vandaag telt niet mee: die dag is nog niet af.
        let logged = intake.filter {
            $0.date >= start && $0.date < end && $0.kcal >= formulaTDEE * completeLogFraction
        }
        let average = logged.isEmpty ? nil : logged.reduce(0) { $0 + $1.kcal } / Double(logged.count)
        var result = formulaOnly
        result.loggedDays = logged.count
        result.averageIntake = average

        let trend = WeightTrend.ema(withoutOutliers(weights)).filter { $0.date >= start && $0.date <= today }
        guard let first = trend.first, let last = trend.last else { return result }
        let spanDays = last.date.timeIntervalSince(first.date) / 86_400
        guard spanDays >= 7 else { return result }
        let ratePerDay = (last.kg - first.kg) / spanDays
        result.trendRatePerWeek = ratePerDay * 7

        guard let average, logged.count >= minimumLoggedDays else { return result }
        let observed = average - ratePerDay * EnergyCalculator.kcalPerKg
        // Begrens uitschieters door onvolledig loggen of vochtschommelingen.
        let clamped = min(max(observed, formulaTDEE * 0.65), formulaTDEE * 1.5)
        let confidence = min(1, Double(logged.count) / fullConfidenceDays) * min(1, spanDays / fullConfidenceDays)
        result.observedKcal = clamped
        result.confidence = confidence
        result.kcal = confidence * clamped + (1 - confidence) * formulaTDEE
        return result
    }
}

extension AdaptiveExpenditure {
    /// Maximale afwijking van de mediaan voordat een weging als tikfout of meetfout geldt.
    public static let outlierFraction = 0.06

    /// Laat wegingen weg die meer dan 6% van de mediaan afwijken, zoals 93 kg tussen wegingen van 82 kg.
    /// Eén tikfout zou anders het verbruik dagenlang scheeftrekken.
    public static func withoutOutliers(_ weights: [WeightPoint]) -> [WeightPoint] {
        guard weights.count >= 3 else { return weights }
        let sorted = weights.map(\.kg).sorted()
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
        return weights.filter { abs($0.kg - median) <= median * outlierFraction }
    }
}

// MARK: - Wekelijkse check-in

public struct CheckInProposal: Sendable, Equatable {
    public var previousKcal: Double
    public var targetKcal: Double
    /// Verhoogd naar de rustverbranding.
    public var wasFloored: Bool
    /// Verhoogd om niet sneller dan 1% lichaamsgewicht per week af te vallen.
    public var wasRateLimited: Bool
    /// De stap is beperkt zodat het doel geleidelijk verandert.
    public var wasStepLimited: Bool

    public var change: Double { targetKcal - previousKcal }
}

public enum WeeklyCheckIn {
    public static let maxStep = 300.0
    public static let interval = 7

    public static func propose(previousTarget: Double, expenditure: Double, goal: Goal,
                               bmr: Double, weightKg: Double) -> CheckInProposal {
        var target = expenditure * goal.calorieFactor
        var rateLimited = false
        let safeMinimum = expenditure - weightKg * 0.01 * EnergyCalculator.kcalPerKg / 7
        if target < safeMinimum {
            target = safeMinimum
            rateLimited = true
        }
        var stepLimited = false
        if previousTarget > 0, abs(target - previousTarget) > maxStep {
            target = previousTarget + (target > previousTarget ? maxStep : -maxStep)
            stepLimited = true
        }
        var floored = false
        if target < bmr {
            target = bmr
            floored = true
        }
        return CheckInProposal(previousKcal: previousTarget, targetKcal: (target / 10).rounded() * 10,
                               wasFloored: floored, wasRateLimited: rateLimited, wasStepLimited: stepLimited)
    }

    /// Een check-in is om de zeven dagen aan de beurt, de eerste zeven dagen na het eerste gelogde eten.
    public static func isDue(lastCheckIn: Date?, firstLoggedDay: Date?, today: Date,
                             calendar: Calendar = .current) -> Bool {
        guard let reference = lastCheckIn ?? firstLoggedDay else { return false }
        return daysUntilDue(lastCheckIn: lastCheckIn, firstLoggedDay: reference, today: today, calendar: calendar) == 0
    }

    /// Dagen tot de volgende check-in; 0 als hij nu aan de beurt is, `nil` zonder data.
    public static func daysUntilDue(lastCheckIn: Date?, firstLoggedDay: Date?, today: Date,
                                    calendar: Calendar = .current) -> Int? {
        guard let reference = lastCheckIn ?? firstLoggedDay else { return nil }
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference),
                                              to: calendar.startOfDay(for: today)).day ?? 0
        return max(0, interval - elapsed)
    }
}

// MARK: - Slaap

public struct TimeSpan: Sendable, Equatable {
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum SleepCalculator {
    /// Totale slaapduur in uren. Overlappende metingen (bijvoorbeeld telefoon én horloge) tellen één keer.
    public static func hours(_ spans: [TimeSpan]) -> Double {
        let sorted = spans.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        var total = 0.0
        var current: TimeSpan?
        for span in sorted {
            if let open = current, span.start <= open.end {
                current?.end = max(open.end, span.end)
            } else {
                if let open = current { total += open.end.timeIntervalSince(open.start) }
                current = span
            }
        }
        if let open = current { total += open.end.timeIntervalSince(open.start) }
        return total / 3600
    }
}
