import PowerCore
import SwiftData
import SwiftUI

struct TrainView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]
    @State private var focus: FocusProposal?

    struct FocusProposal: Identifiable {
        let muscle: MuscleGroup
        let exercises: [Exercise]
        var id: String { muscle.rawValue }
    }

    private var workouts: [Workout] {
        allWorkouts.filter { $0.persistentModelID != router.discardedWorkoutID }
    }
    private var active: Workout? { workouts.first { $0.endedAt == nil } }
    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }
    private var plan: StarterPlan { Coach.plan(for: profile) }

    var body: some View {
        NavigationStack {
            List {
                if let active {
                    Section("Bezig") {
                        Button {
                            router.presentedWorkout = active
                        } label: {
                            Label("Ga verder met \(active.name)", systemImage: "play.fill")
                        }
                    }
                } else {
                    startSections
                }
                Section {
                    NavigationLink {
                        ExerciseLibraryView(profile: profile)
                    } label: {
                        Label("Oefenbibliotheek", systemImage: "books.vertical.fill")
                    }
                }
                Section("Geschiedenis") {
                    if finished.isEmpty {
                        Text("Nog geen trainingen. Je eerste sessie legt je basislijn vast.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(finished) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout, profile: profile)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name).font(.headline)
                                Text("\(workout.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(workout.doneSets.count) sets · \(profile.units.weightText(workout.volumeKg, digits: 0))")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(finished[index]) }
                        GameService.refreshPowerLevel(in: context)
                    }
                }
            }
            .navigationTitle("Train")
            .confirmationDialog(focus.map { String(localized: "Focus: \($0.muscle.title)") } ?? "",
                                isPresented: Binding(get: { focus != nil }, set: { if !$0 { focus = nil } }),
                                titleVisibility: .visible, presenting: focus) { proposal in
                Button("Start focus-training") {
                    start(name: String(localized: "Focus: \(proposal.muscle.title)"),
                          slugs: proposal.exercises.map(\.slug))
                }
            } message: { proposal in
                Text(proposal.exercises.map(\.name).joined(separator: "\n"))
            }
        }
    }

    @ViewBuilder
    private var startSections: some View {
        let recommendation = Coach.recommendation(profile: profile, finished: finished)
        Section {
            CoachCard(recommendation: recommendation) { start(name: $0.name, slugs: $0.slugs) }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
        Section {
            Picker("Schema", selection: Binding(get: { plan }, set: { profile.preferredPlan = $0 })) {
                ForEach(StarterPlan.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(Coach.dayStatuses(plan: plan, profile: profile, finished: finished)) { status in
                Button {
                    start(name: status.day.name, slugs: status.day.slugs)
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.day.name).font(.headline)
                            Text("\(status.day.slugs.count) oefeningen · \(Coach.relativeDay(status.lastPerformed))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if status.day == recommendation.day {
                            Text("Aan de beurt")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.energy, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            Button {
                start(name: String(localized: "Vrije training"), slugs: [])
            } label: {
                Label("Lege training", systemImage: "plus")
            }
        } header: {
            Text("Schema")
        } footer: {
            let suggested = StarterPlan.recommend(daysPerWeek: profile.trainingDaysPerWeek)
            Text("Bij \(profile.trainingDaysPerWeek) dagen per week past \(suggested.title) het best. Je kunt altijd wisselen.")
        }
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Coach.muscleStatuses(finished: finished)) { status in
                        Button {
                            focus = FocusProposal(muscle: status.muscle, exercises: Coach.focusExercises(
                                for: status.muscle, equipment: profile.equipment, in: context))
                        } label: {
                            MuscleChip(status: status)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Herstel per spiergroep")
        } footer: {
            Text("Tik op een spiergroep voor een focus-training met vier oefeningen.")
        }
    }

    private func start(name: String, slugs: [String]) {
        router.presentedWorkout = WorkoutFactory.start(name: name, slugs: slugs, in: context)
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    let profile: UserProfile

    var body: some View {
        List {
            Section {
                HStack {
                    StatView(value: "\(workout.doneSets.count)", label: String(localized: "Sets"))
                    StatView(value: profile.units.weightText(workout.volumeKg, digits: 0), label: String(localized: "Volume"))
                    if let duration = workout.duration {
                        StatView(value: "\(Int(duration / 60)) min", label: String(localized: "Duur"))
                    }
                }
            }
            ForEach(workout.sortedExercises) { item in
                Section(item.exercise?.name ?? "") {
                    ForEach(item.sortedSets.filter(\.isDone)) { set in
                        HStack {
                            Text(set.kind.badge.isEmpty ? "\(set.order + 1)" : set.kind.badge)
                                .font(.caption.weight(.bold))
                                .frame(width: 24)
                                .foregroundStyle(.secondary)
                            Text(SetText.describe(set, isCardio: item.exercise?.isCardio ?? false, units: profile.units))
                            Spacer()
                            if let rir = set.rir {
                                Text("RIR \(rir)").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !item.notes.isEmpty {
                        Text(item.notes).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if !workout.notes.isEmpty {
                Section("Notities") { Text(workout.notes) }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum SetText {
    static func describe(_ set: SetEntry, isCardio: Bool, units: UnitFormatter) -> String {
        if isCardio {
            var parts: [String] = []
            if let minutes = set.durationMinutes, minutes > 0 {
                parts.append("\(UnitFormatter.number(minutes)) min")
            }
            if let km = set.distanceKm, km > 0 {
                parts.append("\(UnitFormatter.number(km, digits: 2)) km")
            }
            return parts.isEmpty ? "–" : parts.joined(separator: " · ")
        }
        if set.weightKg == 0 { return "\(set.reps) reps" }
        return "\(units.weightText(set.weightKg, digits: 2)) × \(set.reps)"
    }
}
