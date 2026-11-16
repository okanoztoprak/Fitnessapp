import SwiftData
import SwiftUI

@main
struct PowerUpApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema(AppSchema.models))
        } catch {
            fatalError("Kon de database niet openen: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Gedeelde navigatiestatus: welke training staat open als full-screen cover.
@MainActor
@Observable
final class AppRouter {
    var presentedWorkout: Workout?
    /// Training die net is weggegooid en zo wordt verwijderd; telt nergens meer mee.
    var discardedWorkoutID: PersistentIdentifier?
    let restTimer = RestTimer()
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var router = AppRouter()

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.accent)
        .environment(router)
        .task { ExerciseSeed.seedIfNeeded(context) }
    }
}

struct MainTabView: View {
    let profile: UserProfile
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView {
            Tab("Vandaag", systemImage: "bolt.fill") {
                TodayView(profile: profile)
            }
            Tab("Train", systemImage: "dumbbell.fill") {
                TrainView(profile: profile)
            }
            Tab("Voeding", systemImage: "fork.knife") {
                NutritionView(profile: profile)
            }
            Tab("Voortgang", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView(profile: profile)
            }
            Tab("Held", systemImage: "flame.fill") {
                HeroView(profile: profile)
            }
        }
        .fullScreenCover(item: $router.presentedWorkout) { workout in
            ActiveWorkoutView(workout: workout, profile: profile)
        }
    }
}
