import PowerCore
import SwiftData
import SwiftUI

struct TrainView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    private var active: Workout? { workouts.first { $0.endedAt == nil } }
    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

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
                    Section("Start") {
                        ForEach(StarterTemplates.days(for: profile)) { day in
                            Button {
                                router.presentedWorkout = WorkoutFactory.start(name: day.name, slugs: day.slugs, in: context)
                            } label: {
                                LabeledContent {
                                    Text("\(day.slugs.count) oefeningen")
                                } label: {
                                    Label(day.name, systemImage: "bolt.fill")
                                }
                            }
                        }
                        Button {
                            router.presentedWorkout = WorkoutFactory.start(
                                name: String(localized: "Vrije training"), in: context)
                        } label: {
                            Label("Lege training", systemImage: "plus")
                        }
                    }
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
        }
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
