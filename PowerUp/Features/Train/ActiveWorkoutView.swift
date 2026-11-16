import PowerCore
import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var workout: Workout
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @State private var showPicker = false
    @State private var showDiscardConfirm = false
    @State private var plateTarget: PlateTarget?
    @State private var burst: BurstInfo?

    struct PlateTarget: Identifiable {
        let id = UUID()
        let kg: Double
    }

    struct BurstInfo: Equatable {
        let id = UUID()
        let subtitle: String
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(workout.sortedExercises) { item in
                    ExerciseSection(item: item, workout: workout, profile: profile,
                                    onComplete: { complete($0, in: item) },
                                    onPlates: { plateTarget = PlateTarget(kg: $0) })
                }
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Oefening toevoegen", systemImage: "plus.circle.fill")
                    }
                }
                Section("Notities") {
                    TextField("Hoe ging het?", text: $workout.notes, axis: .vertical)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Minimaliseer", systemImage: "chevron.down") { router.presentedWorkout = nil }
                        Button("Training weggooien", systemImage: "trash", role: .destructive) {
                            showDiscardConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Meer opties")
                }
                ToolbarItem(placement: .principal) {
                    Text(workout.startedAt, style: .timer)
                        .font(.headline.monospacedDigit())
                        .accessibilityLabel("Trainingsduur")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { finish() }.fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Gereed") { hideKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                RestTimerBar(timer: router.restTimer)
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet(profile: profile) { exercise in
                    WorkoutFactory.add(exercise, to: workout, in: context)
                }
            }
            .sheet(item: $plateTarget) { target in
                PlateCalculatorSheet(initialKg: target.kg, units: profile.units)
            }
            .confirmationDialog("Training weggooien?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Weggooien", role: .destructive) { discard() }
            } message: {
                Text("Alle gelogde sets van deze training worden verwijderd.")
            }
        }
        .overlay {
            if let burst {
                PRBurstView(title: String(localized: "NIEUW RECORD!"), subtitle: burst.subtitle)
                    .onTapGesture { self.burst = nil }
                    .transition(.opacity)
            }
        }
        .task(id: burst) {
            guard burst != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { withAnimation { burst = nil } }
        }
    }

    private func complete(_ set: SetEntry, in item: WorkoutExercise) {
        hideKeyboard()
        set.isDone.toggle()
        guard set.isDone else {
            set.completedAt = nil
            return
        }
        set.completedAt = Date()
        Haptics.tap()
        router.restTimer.start(seconds: profile.restSeconds)

        guard let exercise = item.exercise, !exercise.isCardio, set.kind != .warmup,
              History.hasFinishedHistory(exercise) else { return }
        let performance = SetPerformance(weight: set.weightKg, reps: set.reps)
        let kinds = PRDetector.detect(set: performance,
                                      history: History.performances(for: exercise, excluding: set),
                                      formula: profile.e1rmFormula)
        guard !kinds.isEmpty else { return }
        for kind in kinds {
            context.insert(PersonalRecord(exercise: exercise, kind: kind, weightKg: set.weightKg, reps: set.reps))
        }
        GameService.award(.personalRecord, in: context)
        if profile.celebratePRs {
            let names = PRKind.allCases.filter(kinds.contains).map(\.title).joined(separator: " · ")
            Haptics.burst()
            withAnimation {
                burst = BurstInfo(subtitle: "\(exercise.name)\n\(SetText.describe(set, isCardio: false, units: profile.units))\n\(names)")
            }
        }
    }

    private func finish() {
        hideKeyboard()
        router.restTimer.stop()
        guard !workout.doneSets.isEmpty else {
            discard()
            return
        }
        workout.endedAt = Date()
        GameService.award(.workout, in: context)
        GameService.refreshPowerLevel(in: context)
        Haptics.success()
        let finished = workout
        router.presentedWorkout = nil
        // Niet-afgevinkte sets opruimen nadat het scherm dicht is.
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            for item in finished.exercises ?? [] {
                for set in item.sets ?? [] where !set.isDone { context.delete(set) }
                if (item.sets ?? []).allSatisfy({ !$0.isDone }) { context.delete(item) }
            }
            context.saveOrLog()
        }
    }

    private func discard() {
        router.restTimer.stop()
        let discarded = workout
        // Verberg de training direct in de lijsten; verwijder pas na het sluiten van het scherm.
        context.saveOrLog() // Na opslaan is de identifier definitief.
        router.discardedWorkoutID = discarded.persistentModelID
        router.presentedWorkout = nil
        // Records en record-XP uit deze training vervallen mee.
        let since = discarded.startedAt
        for record in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [] where record.date >= since {
            context.delete(record)
        }
        for event in (try? context.fetch(FetchDescriptor<XPEvent>())) ?? []
        where event.source == .personalRecord && event.date >= since {
            context.delete(event)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            context.delete(discarded)
            context.saveOrLog()
        }
    }
}

private struct ExerciseSection: View {
    @Bindable var item: WorkoutExercise
    let workout: Workout
    let profile: UserProfile
    let onComplete: (SetEntry) -> Void
    let onPlates: (Double) -> Void
    @Environment(\.modelContext) private var context

    private var isCardio: Bool { item.exercise?.isCardio ?? false }
    private var openSets: [SetEntry] { item.sortedSets.filter { !$0.isDone && $0.kind != .warmup } }

    private func isApplied(_ suggestion: ProgressionSuggestion) -> Bool {
        openSets.allSatisfy { abs($0.weightKg - suggestion.weight) < 0.01 && $0.reps == suggestion.reps }
    }

    private func apply(_ suggestion: ProgressionSuggestion) {
        for set in openSets {
            set.weightKg = suggestion.weight
            set.reps = suggestion.reps
        }
        Haptics.tap()
    }

    var body: some View {
        Section {
            if let exercise = item.exercise {
                let previous = History.lastSets(for: exercise, before: workout)
                if !previous.isEmpty {
                    let summary = previous
                        .map { SetText.describe($0, isCardio: isCardio, units: profile.units) }
                        .joined(separator: ", ")
                    Text("Vorige keer: \(summary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let target = Coach.target(for: exercise, before: workout, units: profile.units) {
                    TargetRow(target: target, isApplied: isApplied(target.suggestion)) { apply(target.suggestion) }
                }
            }
            ForEach(item.sortedSets) { set in
                SetRow(set: set, isCardio: isCardio, units: profile.units) { onComplete(set) }
                    .swipeActions(edge: .trailing) {
                        Button("Verwijder", systemImage: "trash", role: .destructive) {
                            context.delete(set)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !isCardio, item.exercise?.gearRaw == "barbell" {
                            Button("Schijven", systemImage: "circle.circle") { onPlates(set.weightKg) }
                                .tint(.blue)
                        }
                    }
            }
            TextField("Notitie", text: $item.notes, axis: .vertical)
                .font(.footnote)
            Button {
                WorkoutFactory.addSet(to: item, in: context)
            } label: {
                Label("Set toevoegen", systemImage: "plus")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                Text(item.exercise?.name ?? "")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                Button("Verwijder oefening", systemImage: "xmark.circle.fill") {
                    context.delete(item)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TargetRow: View {
    let target: Coach.Target
    let isApplied: Bool
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Doel vandaag: \(target.text)")
                    .font(.subheadline.weight(.bold))
                Text(target.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isApplied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Doel ingevuld")
            } else {
                Button("Vul in", action: onApply)
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.bold))
            }
        }
        .listRowBackground(Theme.accent.opacity(0.1))
    }
}

private struct SetRow: View {
    @Bindable var set: SetEntry
    let isCardio: Bool
    let units: UnitFormatter
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isCardio {
                field(Binding(get: { set.durationMinutes ?? 0 }, set: { set.durationMinutes = $0 }), label: "min")
                field(Binding(get: { set.distanceKm ?? 0 }, set: { set.distanceKm = $0 }), label: "km")
            } else {
                kindMenu
                field(Binding(get: { units.displayWeight(set.weightKg) },
                              set: { set.weightKg = units.kg(fromDisplay: $0) }),
                      label: units.weightUnit)
                field(Binding(int: $set.reps), label: "reps", decimal: false)
                rirMenu
            }
            Spacer(minLength: 0)
            Button(action: onToggle) {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(set.isDone ? Text("Set afgerond") : Text("Set afvinken"))
        }
        .opacity(set.isDone ? 0.75 : 1)
    }

    private func field(_ binding: Binding<Double>, label: String, decimal: Bool = true) -> some View {
        VStack(spacing: 0) {
            NumberField(value: binding, allowsDecimal: decimal)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(label)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minWidth: 56, maxWidth: 84)
    }

    private var kindMenu: some View {
        Menu {
            Picker("Soort set", selection: $set.kind) {
                ForEach(SetKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } label: {
            Text(set.kind.badge.isEmpty ? "\(set.order + 1)" : set.kind.badge)
                .font(.subheadline.weight(.heavy))
                .padding(4)
                .frame(minWidth: 30, minHeight: 30)
                .background(set.kind == .normal ? Color(.tertiarySystemFill) : Theme.accent.opacity(0.3),
                            in: Circle())
        }
        .accessibilityLabel("Soort set: \(set.kind.title)")
    }

    private var rirMenu: some View {
        Menu {
            Picker("RIR", selection: $set.rir) {
                Text("Geen").tag(Int?.none)
                ForEach(0..<6) { Text("\($0)").tag(Int?.some($0)) }
            }
        } label: {
            VStack(spacing: 0) {
                Text(set.rir.map { "\($0)" } ?? "–")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(width: 40)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                Text("RIR").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Reps in reserve")
    }
}

struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                let remaining = timer.remaining(at: timeline.date)
                HStack(spacing: 12) {
                    Image(systemName: "timer").accessibilityHidden(true)
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                        .accessibilityLabel("Rusttijd")
                    EnergyBar(fraction: Double(remaining) / Double(max(timer.totalSeconds, 1)))
                    Button("−15") { timer.add(seconds: -15) }
                    Button("+15") { timer.add(seconds: 15) }
                    Button("Sla over", systemImage: "forward.end.fill") { timer.stop() }
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }
}

struct PlateCalculatorSheet: View {
    let units: UnitFormatter
    @State private var target: Double
    @State private var bar: Double
    @Environment(\.dismiss) private var dismiss

    init(initialKg: Double, units: UnitFormatter) {
        self.units = units
        _target = State(initialValue: units.displayWeight(initialKg))
        _bar = State(initialValue: units.barWeight)
    }

    var body: some View {
        let loadout = PlateCalculator.loadout(target: target, bar: bar, plates: units.plates)
        NavigationStack {
            Form {
                LabeledContent("Doelgewicht (\(units.weightUnit))") {
                    NumberField(value: $target).frame(width: 100)
                }
                LabeledContent("Stang (\(units.weightUnit))") {
                    NumberField(value: $bar).frame(width: 100)
                }
                Section("Per kant") {
                    if loadout.perSide.isEmpty {
                        Text("Alleen de stang").foregroundStyle(.secondary)
                    } else {
                        Text(loadout.perSide.map { UnitFormatter.number($0, digits: 2) }.joined(separator: " + "))
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                    }
                    if loadout.remainder > 0 {
                        Label("\(UnitFormatter.number(loadout.remainder, digits: 2)) \(units.weightUnit) is niet te laden met deze schijven.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Schijvencalculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
