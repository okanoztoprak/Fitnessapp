import SwiftData
import SwiftUI
import UIKit

@main
struct PowerUpApp: App {
    private let container: ModelContainer

    init() {
        Self.styleSegmentedControls()
        do {
            container = try ModelContainer(for: Schema(AppSchema.models))
        } catch {
            fatalError("Kon de database niet openen: \(error)")
        }
    }

    /// Segmentknoppen (zoals Weergave en Eenheden): gekozen optie in lime met bosgroene tekst,
    /// de rest op een groene ondergrond. SwiftUI biedt hier geen eigen stijl voor.
    @MainActor
    private static func styleSegmentedControls() {
        let control = UISegmentedControl.appearance()
        control.selectedSegmentTintColor = UIColor(Theme.accent)
        control.backgroundColor = UIColor(Theme.raised)
        control.setTitleTextAttributes([.foregroundColor: UIColor(Theme.onAccent),
                                        .font: UIFont.systemFont(ofSize: 14, weight: .semibold)], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor(Theme.ink)], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Gedeelde navigatiestatus: welke training staat open, en welk voorstel wordt bekeken.
@MainActor
@Observable
final class AppRouter {
    /// Eén router voor de hele app, zodat Siri-opdrachten er ook bij kunnen.
    static let shared = AppRouter()
    /// Gezet door de Siri-opdracht "Start een training".
    var intentStartWorkout = false
    var presentedWorkout: Workout?
    /// Training die net is weggegooid en zo wordt verwijderd; telt nergens meer mee.
    var discardedWorkoutID: PersistentIdentifier?
    /// Voorstel dat als sheet wordt getoond.
    var proposal: WorkoutProposal?
    /// Voorstel dat start zodra de sheet dicht is.
    var pendingStart: WorkoutProposal?
    let restTimer = RestTimer()

    func start(_ proposal: WorkoutProposal) {
        pendingStart = proposal
        self.proposal = nil
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var router = AppRouter.shared

    private var colorScheme: ColorScheme? {
        switch profiles.first?.appearance ?? .dark {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.accentText)
        .toggleStyle(BrandToggleStyle())
        .environment(router)
        .preferredColorScheme(colorScheme)
        .task { ExerciseSeed.seedIfNeeded(context) }
    }
}

struct MainTabView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        TabView {
            Tab("Vandaag", systemImage: "circle.hexagongrid.fill") {
                TodayView(profile: profile)
            }
            Tab("Training", systemImage: "dumbbell.fill") {
                TrainView(profile: profile)
            }
            Tab("Voortgang", systemImage: "chart.xyaxis.line") {
                ProgressTabView(profile: profile)
            }
            Tab("Voeding", systemImage: "fork.knife") {
                NutritionView(profile: profile)
            }
            Tab("Profiel", systemImage: "person.fill") {
                ProfileView(profile: profile)
            }
        }
        .sheet(item: $router.proposal, onDismiss: startPending) { proposal in
            WorkoutPreviewSheet(proposal: proposal, profile: profile)
        }
        .fullScreenCover(item: $router.presentedWorkout) { workout in
            ActiveWorkoutView(workout: workout, profile: profile)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await syncHealthIfStale()
        }
        .task(id: router.intentStartWorkout) { startFromIntent() }
        .task { await ProStore.shared.load() }
    }

    /// Haalt Apple Health op bij het openen van de app, hooguit eens per kwartier.
    private func syncHealthIfStale() async {
        guard profile.healthSyncEnabled else { return }
        if let last = profile.lastHealthSync, Date().timeIntervalSince(last) < 15 * 60 { return }
        _ = try? await HealthSync.run(profile: profile, context: context)
    }

    /// Siri vroeg om een training: toon het voorstel, tenzij er al een training loopt.
    private func startFromIntent() {
        guard router.intentStartWorkout else { return }
        router.intentStartWorkout = false
        guard router.presentedWorkout == nil else { return }
        let finished = (try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.endedAt != nil }))) ?? []
        var proposal = Coach.smartProposal(profile: profile, finished: finished, in: context)
        proposal.training = ProgramCoach.freeContext(profile: profile)
        router.proposal = proposal
    }

    /// Start pas als de sheet weg is; twee presentaties tegelijk botsen.
    private func startPending() {
        guard let proposal = router.pendingStart else { return }
        router.pendingStart = nil
        router.presentedWorkout = WorkoutFactory.start(name: proposal.title, slugs: proposal.exercises.map(\.slug),
                                                       in: context, training: proposal.training, units: profile.units)
    }
}
