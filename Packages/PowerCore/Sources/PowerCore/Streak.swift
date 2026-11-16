import Foundation

public enum StreakCalculator {
    /// Aantal opeenvolgende actieve dagen tot en met vandaag.
    /// Als vandaag nog niets gelogd is, telt de reeks tot en met gisteren door.
    public static func current(activeDays: [Date], today: Date, calendar: Calendar) -> Int {
        let days = Set(activeDays.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
