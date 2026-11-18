import Foundation

/// Wat de widgets van de app nodig hebben. De app schrijft dit weg, de widgets lezen het.
struct WidgetSnapshot: Codable, Equatable {
    /// "group." + de bundle-ID van de app; de widget-extensie heeft dezelfde ID met ".widgets" erachter.
    static let appGroup: String = {
        let id = Bundle.main.bundleIdentifier ?? "com.example.powerup"
        let base = id.hasSuffix(".widgets") ? String(id.dropLast(".widgets".count)) : id
        return "group.\(base)"
    }()
    private static let key = "widgetSnapshot"

    var stepsDate: Date?
    var steps: Int = 0
    var stepGoal: Int = 8_000
    var nextWorkout: String?
    var nextDetail: String?
    var weekStreak: Int = 0
    var trainedToday = false

    /// Stappen van vandaag; een oude meting telt als nul.
    func stepsToday(now: Date = Date()) -> Int {
        guard let stepsDate, Calendar.current.isDate(stepsDate, inSameDayAs: now) else { return 0 }
        return steps
    }

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}
