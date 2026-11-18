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
    @State private var showSummary = false
    @State private var plateTarget: PlateTarget?
    @State private var toast: ToastInfo?
    @State private var swapItem: WorkoutExercise?
    @Query private var programs: [TrainingProgram]

    private var training: TrainingContext {
        ProgramCoach.context(for: workout, programs: programs, profile: profile)
    }

    struct PlateTarget: Identifiable {
        let id = UUID()
        let kg: Double
    }

    struct ToastInfo: Equatable {
        let id = UUID()
        let title: String
        let detail: String
    }

    var body: some View {
        if showSummary {
            WorkoutSummaryView(workout: workout, profile: profile) { router.presentedWorkout = nil }
                .transition(.opacity)
        } else {
            logger
        }
    }

    private var logger: some View {
        NavigationStack {
            List {
                Section {
                    LiveStats(workout: workout, units: profile.units)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if let plan = training.plan {
                        Label(training.programID == nil ? String(localized: "Deloadweek") : ProgramCoach.weekLine(plan),
                              systemImage: plan.isDeload ? "moon.fill" : "calendar")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(plan.isDeload ? Theme.cool : Theme.accentText)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
                    }
                }
                ForEach(workout.sortedExercises) { item in
                    ExerciseSection(item: item, workout: workout, profile: profile, training: training,
                                    onComplete: { complete($0, in: item) },
                                    onPlates: { plateTarget = PlateTarget(kg: $0) },
                                    onSwap: { swapItem = item })
                }
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Oefening toevoegen", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .listRowBackground(Theme.card)
                }
                Section("Notities") {
                    TextField("Hoe ging het?", text: $workout.notes, axis: .vertical)
                        .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
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
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Meer opties")
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
                    WorkoutFactory.add(exercise, to: workout, in: context, training: training)
                }
            }
            .sheet(item: $swapItem) { item in
                SwapExerciseSheet(item: item, profile: profile) { replacement in
                    swap(item, to: replacement)
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
        .overlay(alignment: .top) {
            if let toast {
                RecordToast(title: toast.title, detail: toast.detail)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .dismissibleToast { withAnimation { self.toast = nil } }
            }
        }
        .overlay {
            if toast != nil { ConfettiView().id(toast?.id) }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { withAnimation { toast = nil } }
        }
    }

    private func complete(_ set: SetEntry, in item: WorkoutExercise) {
        hideKeyboard()
        if set.isDone {
            set.isDone = false
            set.completedAt = nil
            removeRecords(for: set, in: item)
            return
        }
        let isCardio = item.exercise?.isCardio ?? false
        if !Self.hasValues(set, isCardio: isCardio) {
            // Leeg: neem de vorige prestatie of de set erboven over, zoals in de bekende loggers.
            let index = item.sortedSets.firstIndex { $0 === set } ?? 0
            let previous = item.exercise.map { History.lastSets(for: $0, before: workout) } ?? []
            let source = index < previous.count ? previous[index]
                : item.sortedSets.prefix(index).last { Self.hasValues($0, isCardio: isCardio) }
            guard let source else {
                Haptics.warning()
                return
            }
            set.weightKg = source.weightKg
            set.reps = source.reps
            set.durationMinutes = source.durationMinutes
            set.distanceKm = source.distanceKm
        }
        set.isDone = true
        set.completedAt = Date()
        Haptics.tap()
        router.restTimer.start(seconds: profile.restSeconds, workoutName: workout.name)

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
        if profile.celebratePRs {
            let names = PRKind.allCases.filter(kinds.contains).map(\.title).joined(separator: " · ")
            Haptics.burst()
            withAnimation(.spring(duration: 0.4)) {
                toast = ToastInfo(
                    title: String(localized: "Nieuw record: \(exercise.name)"),
                    detail: "\(SetText.describe(set, isCardio: false, units: profile.units)) · \(names)")
            }
        }
    }

    static func hasValues(_ set: SetEntry, isCardio: Bool) -> Bool {
        isCardio ? (set.durationMinutes ?? 0) > 0 || (set.distanceKm ?? 0) > 0 : set.reps > 0
    }

    /// Een set die weer wordt uitgevinkt neemt de records mee die hij opleverde.
    private func removeRecords(for set: SetEntry, in item: WorkoutExercise) {
        guard let slug = item.exercise?.slug else { return }
        let since = workout.startedAt
        for record in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        where record.exerciseSlug == slug && record.date >= since
            && abs(record.weightKg - set.weightKg) < 0.001 && record.reps == set.reps {
            context.delete(record)
        }
    }

    /// Vervangt een oefening waarvan nog niets is afgevinkt; de sets komen van de vorige keer met de nieuwe.
    private func swap(_ item: WorkoutExercise, to replacement: Exercise) {
        for set in item.sets ?? [] { context.delete(set) }
        item.exercise = replacement
        WorkoutFactory.fillSets(of: item, exercise: replacement, workout: workout, in: context,
                                training: training, units: profile.units)
        Haptics.tap()
    }

    private func finish() {
        hideKeyboard()
        router.restTimer.stop()
        guard !workout.doneSets.isEmpty else {
            discard()
            return
        }
        workout.endedAt = Date()
        Haptics.success()
        withAnimation { showSummary = true }
        let finished = workout
        // Niet-afgevinkte sets opruimen nadat het logscherm weg is.
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
        // Records uit deze training vervallen mee.
        let since = discarded.startedAt
        for record in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [] where record.date >= since {
            context.delete(record)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            context.delete(discarded)
            context.saveOrLog()
        }
    }
}

/// Duur, volume en sets, live bijgewerkt tijdens het loggen.
private struct LiveStats: View {
    let workout: Workout
    let units: UnitFormatter

    var body: some View {
        let total = (workout.exercises ?? []).reduce(0) { $0 + ($1.sets ?? []).count }
        HStack(spacing: 0) {
            stat(label: String(localized: "Duur")) {
                Text(workout.startedAt, style: .timer)
            }
            Divider().frame(height: 32)
            stat(label: String(localized: "Volume")) {
                Text(units.weightText(workout.volumeKg, digits: 0))
                    .contentTransition(.numericText())
            }
            Divider().frame(height: 32)
            stat(label: String(localized: "Sets")) {
                Text("\(workout.doneSets.count)/\(total)")
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .animation(.snappy, value: workout.doneSets.count)
    }

    private func stat(label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(spacing: 2) {
            value()
                .font(Theme.number(.title3))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseSection: View {
    @Bindable var item: WorkoutExercise
    let workout: Workout
    let profile: UserProfile
    let training: TrainingContext
    let onComplete: (SetEntry) -> Void
    let onPlates: (Double) -> Void
    let onSwap: () -> Void
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
        let previous = item.exercise.map { History.lastSets(for: $0, before: workout) } ?? []
        Section {
            if let exercise = item.exercise,
               let target = Coach.target(for: exercise, before: workout, units: profile.units, training: training) {
                TargetRow(target: target, isApplied: isApplied(target.suggestion)) { apply(target.suggestion) }
            }
            ColumnHeader(isCardio: isCardio, unit: profile.units.weightUnit)
                .listRowBackground(Theme.card)
                .listRowSeparator(.hidden)
            ForEach(Array(item.sortedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                SetRow(set: set, isCardio: isCardio, units: profile.units,
                       previous: index < previous.count ? previous[index] : nil) { onComplete(set) }
                    .listRowBackground(set.isDone ? Theme.good.opacity(0.14) : Theme.card)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("Verwijder", systemImage: "trash", role: .destructive) {
                            context.delete(set)
                        }
                    }
            }
            Button {
                WorkoutFactory.addSet(to: item, in: context)
            } label: {
                Label("Set toevoegen", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Theme.card)
            .listRowSeparator(.hidden)
            TextField("Notitie", text: $item.notes, axis: .vertical)
                .font(.footnote)
                .listRowBackground(Theme.card)
                .listRowSeparator(.hidden)
        } header: {
            HStack {
                Text(item.exercise?.name ?? "")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                Menu {
                    if !isCardio, item.exercise?.gearRaw == "barbell" {
                        Button("Schijvencalculator", systemImage: "circle.circle") {
                            onPlates(item.sortedSets.first { !$0.isDone }?.weightKg ?? item.sortedSets.last?.weightKg ?? 0)
                        }
                    }
                    if !(item.sets ?? []).contains(where: \.isDone) {
                        Button("Vervang oefening", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                    }
                    Button("Verwijder oefening", systemImage: "trash", role: .destructive) {
                        context.delete(item)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Opties voor \(item.exercise?.name ?? "")")
            }
        }
    }
}

/// Vaste kolombreedtes, gedeeld door de kop en de rijen.
private enum Column {
    static let set: CGFloat = 34
    static let field: CGFloat = 72
    static let check: CGFloat = 44
}

private struct ColumnHeader: View {
    let isCardio: Bool
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Set").frame(width: Column.set)
            Text("Vorige").frame(maxWidth: .infinity, alignment: .leading)
            Text(isCardio ? "min" : unit).frame(width: Column.field)
            Text(isCardio ? "km" : "reps").frame(width: Column.field)
            Image(systemName: "checkmark").frame(width: Column.check)
        }
        .font(.caption.weight(.bold))
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private struct TargetRow: View {
    let target: Coach.Target
    let isApplied: Bool
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .foregroundStyle(Theme.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Doel vandaag: \(target.text)")
                    .font(.subheadline.weight(.bold))
                if let rir = target.rir {
                    Text("RIR \(rir)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.raised, in: Capsule())
                        .accessibilityLabel("Nog \(rir) herhalingen in de tank")
                }
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
        .listRowBackground(Theme.accentText.opacity(0.12))
    }
}

private struct SetRow: View {
    @Bindable var set: SetEntry
    let isCardio: Bool
    let units: UnitFormatter
    let previous: SetEntry?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            kindMenu
            previousButton
            if isCardio {
                field(Binding(get: { set.durationMinutes ?? 0 }, set: { set.durationMinutes = $0 }), label: "min")
                field(Binding(get: { set.distanceKm ?? 0 }, set: { set.distanceKm = $0 }), label: "km")
            } else {
                field(Binding(get: { units.displayWeight(set.weightKg) },
                              set: { set.weightKg = units.kg(fromDisplay: $0) }),
                      label: units.weightUnit)
                field(Binding(int: $set.reps), label: "reps", decimal: false)
            }
            Button(action: onToggle) {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isDone ? Theme.good : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: Column.check, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(set.isDone ? Text("Set afgerond") : Text("Set afvinken"))
        }
    }

    /// Vorige prestatie; een tik neemt de waarden over.
    @ViewBuilder
    private var previousButton: some View {
        if let previous {
            Button {
                set.weightKg = previous.weightKg
                set.reps = previous.reps
                set.durationMinutes = previous.durationMinutes
                set.distanceKm = previous.distanceKm
                Haptics.tap()
            } label: {
                Text(compact(previous))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Vorige keer: \(SetText.describe(previous, isCardio: isCardio, units: units))")
            .accessibilityHint("Neemt deze waarden over")
        } else {
            Text("–")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
    }

    private func compact(_ entry: SetEntry) -> String {
        if isCardio { return SetText.describe(entry, isCardio: true, units: units) }
        if entry.weightKg == 0 { return "× \(entry.reps)" }
        return "\(UnitFormatter.number(units.displayWeight(entry.weightKg), digits: 2)) × \(entry.reps)"
    }

    private func field(_ binding: Binding<Double>, label: String, decimal: Bool = true) -> some View {
        NumberField(value: binding, allowsDecimal: decimal)
            .font(Theme.number(.body))
            .padding(.vertical, 8)
            .frame(width: Column.field)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel(label)
    }

    private var kindMenu: some View {
        Menu {
            Picker("Soort set", selection: $set.kind) {
                ForEach(SetKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Reps in reserve", selection: $set.rir) {
                Text("RIR: geen").tag(Int?.none)
                ForEach(0..<6) { Text("RIR \($0)").tag(Int?.some($0)) }
            }
            .pickerStyle(.menu)
        } label: {
            VStack(spacing: 0) {
                Text(set.kind.badge.isEmpty ? "\(set.order + 1)" : set.kind.badge)
                    .font(Theme.number(.subheadline))
                    .foregroundStyle(set.kind == .normal ? Color.primary : Theme.accentText)
                if let rir = set.rir {
                    Text("R\(rir)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: Column.set, height: 36)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityLabel("Soort set: \(set.kind.title)")
    }
}

/// Zwevende rusttimer met ring en knoppen om tijd toe te voegen of over te slaan.
struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                let remaining = timer.remaining(at: timeline.date)
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(Theme.accent.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: Double(remaining) / Double(max(timer.totalSeconds, 1)))
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "timer").font(.caption.weight(.bold))
                    }
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rust").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                            .font(Theme.number(.title3))
                            .monospacedDigit()
                            .accessibilityLabel("Rusttijd")
                    }
                    Spacer(minLength: 4)
                    Button("−15") { timer.add(seconds: -15) }
                        .fixedSize()
                    Button("+15") { timer.add(seconds: 15) }
                        .fixedSize()
                    Button("Sla over", systemImage: "forward.end.fill") { timer.stop() }
                        .labelStyle(.iconOnly)
                        .fixedSize()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .lineLimit(1)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                Group {
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
                                .font(Theme.number(.title3))
                        }
                        if loadout.remainder > 0 {
                            Label("\(UnitFormatter.number(loadout.remainder, digits: 2)) \(units.weightUnit) is niet te laden met deze schijven.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Schijvencalculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Andere oefeningen voor dezelfde spiergroep, bijvoorbeeld als een apparaat bezet is.
struct SwapExerciseSheet: View {
    let item: WorkoutExercise
    let profile: UserProfile
    let onPick: (Exercise) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let alternatives = item.exercise.map { ProgramCoach.alternatives(for: $0, equipment: profile.equipment, in: context) } ?? []
        NavigationStack {
            List {
                Section {
                    ForEach(alternatives) { exercise in
                        Button {
                            onPick(exercise)
                            dismiss()
                        } label: {
                            HStack {
                                ExerciseRowLabel(exercise: exercise)
                                Spacer()
                                if let last = History.lastSets(for: exercise, before: nil).first {
                                    Text(SetText.describe(last, isCardio: false, units: profile.units))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        .listRowBackground(Theme.card)
                    }
                    if alternatives.isEmpty {
                        Text("Geen andere oefeningen voor deze spiergroep met je materiaal.")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Theme.card)
                    }
                } header: {
                    Text("Zelfde spiergroep: \(item.exercise?.primaryMuscle.title ?? "")")
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Vervang \(item.exercise?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
