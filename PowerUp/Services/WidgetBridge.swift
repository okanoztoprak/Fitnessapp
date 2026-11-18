import Foundation
import WidgetKit

/// Schrijft de stand voor de widgets weg en ververst ze alleen als er iets veranderd is.
@MainActor
enum WidgetBridge {
    static func updateSteps(_ steps: Int, goal: Int, now: Date = Date()) {
        var snapshot = WidgetSnapshot.load()
        snapshot.steps = steps
        snapshot.stepsDate = now
        snapshot.stepGoal = goal
        save(snapshot)
    }

    static func updateGoal(_ goal: Int) {
        var snapshot = WidgetSnapshot.load()
        snapshot.stepGoal = goal
        save(snapshot)
    }

    static func updateToday(nextWorkout: String, detail: String?, weekStreak: Int, trainedToday: Bool) {
        var snapshot = WidgetSnapshot.load()
        snapshot.nextWorkout = nextWorkout
        snapshot.nextDetail = detail
        snapshot.weekStreak = weekStreak
        snapshot.trainedToday = trainedToday
        save(snapshot)
    }

    private static func save(_ snapshot: WidgetSnapshot) {
        let old = WidgetSnapshot.load()
        // Het tijdstip van de meting telt niet mee, wel of het nog dezelfde dag is.
        var compare = snapshot
        compare.stepsDate = old.stepsDate
        let sameDay = old.stepsDate.map { Calendar.current.isDate($0, inSameDayAs: snapshot.stepsDate ?? $0) } ?? false
        snapshot.save()
        guard compare != old || !sameDay else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
