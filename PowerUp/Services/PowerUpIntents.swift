import AppIntents
import Foundation

/// Opent de app met een voorstel voor de slimme training van vandaag.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start een training"
    static let description = IntentDescription("Opent RIVO met een voorstel voor je training van vandaag.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.intentStartWorkout = true
        return .result()
    }
}

/// Zegt hoeveel stappen je vandaag hebt gezet, zonder de app te openen.
struct StepsTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Stappen van vandaag"
    static let description = IntentDescription("Zegt hoeveel stappen je vandaag hebt gezet en hoeveel je nog nodig hebt voor je doel.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let steps = (try? await HealthKitService.shared.dailySteps(from: start, to: end))?.reduce(0) { $0 + $1.count } ?? 0
        let goal = WidgetSnapshot.load().stepGoal
        let text = steps >= goal
            ? String(localized: "Je hebt vandaag \(steps.formatted()) stappen gezet. Je doel van \(goal.formatted()) is gehaald.")
            : String(localized: "Je hebt vandaag \(steps.formatted()) stappen gezet. Nog \((goal - steps).formatted()) tot je doel.")
        return .result(dialog: "\(text)")
    }
}

struct PowerUpShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWorkoutIntent(),
                    phrases: ["Start een training in \(.applicationName)", "Train met \(.applicationName)"],
                    shortTitle: "Start training", systemImageName: "dumbbell.fill")
        AppShortcut(intent: StepsTodayIntent(),
                    phrases: ["Hoeveel stappen heb ik in \(.applicationName)", "Mijn stappen in \(.applicationName)"],
                    shortTitle: "Stappen", systemImageName: "figure.walk")
    }
}
