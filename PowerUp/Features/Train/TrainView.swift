import PowerCore
import SwiftData
import SwiftUI

struct TrainView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]
    @Query private var programs: [TrainingProgram]

    private var workouts: [Workout] {
        allWorkouts.filter { $0.persistentModelID != router.discardedWorkoutID }
    }
    private var active: Workout? { workouts.first { $0.endedAt == nil } }
    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }
    private var plan: StarterPlan { Coach.plan(for: profile) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let status = ProgramStatus.active(programs).map { ProgramStatus(program: $0, finished: finished) }
                    let recommendation = Coach.recommendation(profile: profile, finished: finished, program: status)
                    if let active {
                        ActiveWorkoutCard(workout: active)
                    } else {
                        NextWorkoutCard(recommendation: recommendation, profile: profile)
                    }
                    if let status {
                        ProgramCard(status: status)
                        quickStartButtons
                    } else {
                        StartProgramCard(profile: profile)
                        programSection(recommended: recommendation.day)
                    }
                    let plateau = ProgramCoach.plateaus(finished: finished, formula: profile.e1rmFormula)
                    CoachNotesCard(profile: profile,
                                   advice: ProgramCoach.deloadAdvice(finished: finished, profile: profile,
                                                                     hasProgram: status != nil),
                                   stalled: plateau.stalled)
                    WeeklyVolumeCard(volumes: ProgramCoach.weeklyVolume(finished: finished, plan: status?.weekPlan)) { muscle in
                        openFocus(muscle)
                    }
                    librarySection
                    historySection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Training")
            .brandToolbar()
        }
    }

    // MARK: Schema

    @ViewBuilder
    private func programSection(recommended: TemplateDay?) -> some View {
        let suggested = StarterPlan.recommend(daysPerWeek: profile.trainingDaysPerWeek)
        SectionTitle(String(localized: "Schema"),
                     caption: String(localized: "Bij \(profile.trainingDaysPerWeek) dagen per week past \(suggested.title) het best."))
        Picker("Schema", selection: Binding(get: { plan }, set: { profile.preferredPlan = $0 })) {
            ForEach(StarterPlan.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Coach.dayStatuses(plan: plan, profile: profile, finished: finished)) { status in
                    Button {
                        router.proposal = Coach.proposal(
                            for: status.day, caption: Coach.relativeDay(status.lastPerformed), in: context,
                            training: ProgramCoach.freeContext(profile: profile))
                    } label: {
                        DayCard(status: status, isNext: status.day == recommended)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .scrollClipDisabled()
        quickStartButtons
    }

    private var quickStartButtons: some View {
        HStack(spacing: 10) {
            Button {
                var proposal = Coach.smartProposal(profile: profile, finished: finished, in: context)
                proposal.training = ProgramCoach.freeContext(profile: profile)
                router.proposal = proposal
            } label: {
                Label("Slimme training", systemImage: "sparkles")
            }
            .buttonStyle(SoftButtonStyle())
            Button {
                router.presentedWorkout = WorkoutFactory.start(name: String(localized: "Vrije training"), in: context,
                                                               training: ProgramCoach.freeContext(profile: profile))
            } label: {
                Label("Lege training", systemImage: "plus")
            }
            .buttonStyle(SoftButtonStyle())
        }
        .disabled(active != nil)
        .opacity(active != nil ? 0.4 : 1)
    }

    private func openFocus(_ muscle: MuscleGroup) {
        var proposal = Coach.focusProposal(for: muscle, equipment: profile.equipment, in: context)
        proposal.training = ProgramCoach.freeContext(profile: profile)
        router.proposal = proposal
    }

    // MARK: Bibliotheek en geschiedenis

    private var librarySection: some View {
        NavigationLink {
            ExerciseLibraryView(profile: profile)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                Text("Oefenbibliotheek").font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .card(padding: 16)
        }
        .buttonStyle(PressableStyle())
        .padding(.top, 8)
    }

    @ViewBuilder
    private var historySection: some View {
        SectionTitle(String(localized: "Geschiedenis"))
        if finished.isEmpty {
            Text("Nog geen trainingen. Je eerste sessie legt je basislijn vast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .card()
        }
        ForEach(finished) { workout in
            NavigationLink {
                WorkoutDetailView(workout: workout, profile: profile)
            } label: {
                HistoryRow(workout: workout, profile: profile)
            }
            .buttonStyle(PressableStyle())
            .contextMenu {
                Button("Verwijder training", systemImage: "trash", role: .destructive) {
                    context.delete(workout)
                    context.saveOrLog()
                }
            }
        }
    }
}

private struct DayCard: View {
    let status: Coach.DayStatus
    let isNext: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isNext {
                Tag(text: String(localized: "Aan de beurt"), filled: true)
                    .fixedSize()
            } else {
                Image(systemName: "bolt.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 30, height: 30)
                    .background(Theme.raised, in: Circle())
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 4)
            Text(status.day.name)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(status.day.slugs.count) oefeningen")
                .font(.footnote).foregroundStyle(.secondary)
            Text(Coach.relativeDay(status.lastPerformed))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 168, alignment: .leading)
        .frame(minHeight: 128, alignment: .topLeading)
        .card(padding: 14)
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.accentText.opacity(0.6), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryRow: View {
    let workout: Workout
    let profile: UserProfile

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(workout.startedAt, format: .dateTime.day())
                    .font(Theme.number(.title3))
                Text(workout.startedAt, format: .dateTime.month(.abbreviated))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46, height: 50)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name).font(.headline)
                Text("\(UnitFormatter.sets(workout.doneSets.count)) · \(profile.units.weightText(workout.volumeKg, digits: 0))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let duration = workout.duration {
                Text("\(max(1, Int(duration / 60))) min")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(workout.startedAt, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    StatTile(value: "\(workout.doneSets.count)", label: String(localized: "Sets"), symbol: "checkmark.circle.fill")
                    StatTile(value: profile.units.weightText(workout.volumeKg, digits: 0),
                             label: String(localized: "Volume"), symbol: "scalemass.fill")
                    if let duration = workout.duration {
                        StatTile(value: "\(max(1, Int(duration / 60))) min", label: String(localized: "Duur"), symbol: "clock.fill")
                    }
                }
                .card()
                ForEach(workout.sortedExercises) { item in
                    let isCardio = item.exercise?.isCardio ?? false
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.exercise?.name ?? "").font(.headline)
                        ForEach(item.sortedSets.filter(\.isDone)) { set in
                            HStack {
                                Text(set.kind.badge.isEmpty ? "\(set.order + 1)" : set.kind.badge)
                                    .font(Theme.number(.caption))
                                    .frame(width: 26, height: 26)
                                    .background(Theme.raised, in: Circle())
                                Text(SetText.describe(set, isCardio: isCardio, units: profile.units))
                                    .font(.body.monospacedDigit())
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
                    .card()
                }
                if !workout.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notities").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text(workout.notes)
                    }
                    .card()
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Verwijder training", systemImage: "trash", role: .destructive) { confirmDelete = true }
        }
        .confirmationDialog("Training verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijder", role: .destructive) {
                let target = workout
                dismiss()
                // Verwijder pas als het scherm weg is; een view op een verwijderd model crasht.
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    context.delete(target)
                    context.saveOrLog()
                }
            }
        }
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
