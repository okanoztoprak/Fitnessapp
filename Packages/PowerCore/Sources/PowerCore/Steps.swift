import Foundation

/// Stappen van één kalenderdag.
public struct DailySteps: Sendable, Equatable {
    public var date: Date
    public var count: Int

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

/// De stappen van de afgelopen zeven dagen tegenover het doel.
public struct StepWeek: Sendable, Equatable {
    public var goal: Int
    /// Zeven dagen, oudste eerst; de laatste is vandaag.
    public var days: [DailySteps]

    public var today: Int { days.last?.count ?? 0 }
    public var progress: Double { goal > 0 ? Double(today) / Double(goal) : 0 }
    public var remaining: Int { max(0, goal - today) }
    public var goalReached: Bool { goal > 0 && today >= goal }

    /// Dagen van de zeven waarop het doel gehaald is.
    public var daysHit: Int { days.filter { $0.count >= goal }.count }

    /// Gemiddelde van de afgelopen zes volle dagen, zonder dagen zonder metingen.
    public var average: Int? {
        let measured = days.dropLast().filter { $0.count > 0 }
        guard !measured.isEmpty else { return nil }
        return Int((Double(measured.reduce(0) { $0 + $1.count }) / Double(measured.count)).rounded())
    }

    /// Dagen op rij met het doel gehaald. Vandaag telt mee zodra het doel gehaald is,
    /// maar breekt de reeks niet zolang de dag nog loopt.
    public var streak: Int {
        var count = goalReached ? 1 : 0
        for day in days.dropLast().reversed() {
            guard day.count >= goal else { break }
            count += 1
        }
        return count
    }

    public var hasData: Bool { days.contains { $0.count > 0 } }
}

public enum StepGoal {
    /// Bij volwassenen vlakt de gezondheidswinst in onderzoek af rond 8.000 tot 10.000 stappen.
    public static let standard = 8_000
    public static let range = 2_000...30_000
    public static let step = 500

    /// Vult de zeven dagen tot en met vandaag aan, ook dagen zonder metingen.
    public static func week(_ samples: [DailySteps], goal: Int, today: Date,
                            calendar: Calendar = .current) -> StepWeek {
        let end = calendar.startOfDay(for: today)
        var byDay: [Date: Int] = [:]
        for sample in samples {
            byDay[calendar.startOfDay(for: sample.date), default: 0] += sample.count
        }
        let days = (0..<7).reversed().compactMap { offset -> DailySteps? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return DailySteps(date: day, count: byDay[day] ?? 0)
        }
        return StepWeek(goal: goal, days: days)
    }

    public static func clamp(_ goal: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, goal))
    }
}
