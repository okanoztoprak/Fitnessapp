import Foundation

public struct WeightPoint: Sendable, Equatable {
    public var date: Date
    public var kg: Double
    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

public enum WeightTrend {
    /// Exponentieel voortschrijdend gemiddelde met dagelijkse stappen.
    /// Gemiste dagen worden lineair geïnterpoleerd, zodat een gat de trend niet laat verspringen.
    /// Geeft één trendpunt per meting terug, op volgorde van datum.
    public static func ema(_ points: [WeightPoint], alpha: Double = 0.1) -> [WeightPoint] {
        let sorted = points.sorted { $0.date < $1.date }
        guard var previous = sorted.first else { return [] }
        var trend = previous.kg
        var result = [WeightPoint(date: previous.date, kg: trend)]
        for point in sorted.dropFirst() {
            let seconds = point.date.timeIntervalSince(previous.date)
            let days = max(1, Int((seconds / 86_400).rounded()))
            for day in 1...days {
                let interpolated = previous.kg + (point.kg - previous.kg) * Double(day) / Double(days)
                trend += alpha * (interpolated - trend)
            }
            result.append(WeightPoint(date: point.date, kg: trend))
            previous = point
        }
        return result
    }

    /// Verandering van de trend in kg per week over de laatste `windowDays` dagen.
    public static func weeklyRate(trend: [WeightPoint], windowDays: Int = 14) -> Double? {
        guard let last = trend.last else { return nil }
        let cutoff = last.date.addingTimeInterval(-Double(windowDays) * 86_400)
        guard let first = trend.first(where: { $0.date >= cutoff }) else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86_400
        guard days >= 3 else { return nil }
        return (last.kg - first.kg) / days * 7
    }
}
