import Charts
import PowerCore
import SwiftData
import SwiftUI

/// Doorzoekbare lijst met spiergroepfilter; gedeeld door de bibliotheek en de kiezer.
struct ExerciseList<Row: View>: View {
    @Query(sort: \Exercise.nameEN) private var exercises: [Exercise]
    @State private var search = ""
    @State private var muscle: MuscleGroup?
    @ViewBuilder let row: (Exercise) -> Row

    private var filtered: [Exercise] {
        exercises
            .filter { exercise in
                (muscle == nil || exercise.primaryMuscle == muscle)
                    && (search.isEmpty
                        || exercise.nameEN.localizedCaseInsensitiveContains(search)
                        || exercise.nameNL.localizedCaseInsensitiveContains(search))
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            Group {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            chip(String(localized: "Alles"), selected: muscle == nil) { muscle = nil }
                            ForEach(MuscleGroup.allCases, id: \.self) { group in
                                chip(group.title, selected: muscle == group) { muscle = group }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 0))
                }
                Section {
                    ForEach(filtered) { exercise in
                        row(exercise)
                    }
                    if filtered.isEmpty {
                        Text("Geen oefeningen gevonden.").foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .searchable(text: $search, prompt: "Zoek een oefening")
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Theme.accent : Theme.raised, in: Capsule())
                .foregroundStyle(selected ? Theme.onAccent : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ExerciseRowLabel: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
            Text("\(exercise.primaryMuscle.title) · \(GearLabel.title(exercise.gearRaw))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ExerciseLibraryView: View {
    let profile: UserProfile
    @State private var showNew = false

    var body: some View {
        ExerciseList { exercise in
            NavigationLink {
                ExerciseDetailView(exercise: exercise, profile: profile)
            } label: {
                ExerciseRowLabel(exercise: exercise)
            }
        }
        .navigationTitle("Oefeningen")
        .toolbar {
            Button("Nieuwe oefening", systemImage: "plus") { showNew = true }
        }
        .sheet(isPresented: $showNew) { NewExerciseSheet() }
    }
}

struct ExercisePickerSheet: View {
    let profile: UserProfile
    let onPick: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            ExerciseList { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    ExerciseRowLabel(exercise: exercise)
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Kies een oefening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Nieuwe oefening", systemImage: "plus") { showNew = true }
                }
            }
            .sheet(isPresented: $showNew) { NewExerciseSheet() }
        }
    }
}

struct NewExerciseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscle = MuscleGroup.chest
    @State private var gear = "barbell"

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    TextField("Naam", text: $name)
                    Picker("Spiergroep", selection: $muscle) {
                        ForEach(MuscleGroup.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if muscle != .cardio {
                        Picker("Materiaal", selection: $gear) {
                            ForEach(GearLabel.all.filter { $0 != "cardio" }, id: \.self) {
                                Text(GearLabel.title($0)).tag($0)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Nieuwe oefening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        context.insert(Exercise(
                            slug: "custom-\(UUID().uuidString)", nameEN: trimmed, nameNL: trimmed,
                            primary: muscle, gear: muscle == .cardio ? "cardio" : gear,
                            isCardio: muscle == .cardio, isCustom: true))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PersonalRecord.date, order: .reverse) private var allRecords: [PersonalRecord]

    var body: some View {
        let series = History.e1rmSeries(for: exercise, formula: profile.e1rmFormula)
        let records = allRecords.filter { $0.exerciseSlug == exercise.slug }
        List {
            Group {
                Section {
                    LabeledContent("Primair", value: exercise.primaryMuscle.title)
                    if !exercise.secondaryMuscles.isEmpty {
                        LabeledContent("Secundair",
                                       value: exercise.secondaryMuscles.map(\.title).joined(separator: ", "))
                    }
                    LabeledContent("Materiaal", value: GearLabel.title(exercise.gearRaw))
                }
                if let guide = ExerciseGuide.guide(for: exercise.slug) {
                    ExerciseGuideSection(exercise: exercise, guide: guide)
                }
                if !exercise.isCardio {
                    Section("Geschatte 1RM") {
                        if series.count < 2 {
                            Text("Log deze oefening in minstens twee trainingen om je verloop te zien.")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(series) { point in
                                LineMark(x: .value("Datum", point.date),
                                         y: .value("e1RM", profile.units.displayWeight(point.value)))
                                    .foregroundStyle(Theme.accentText)
                                PointMark(x: .value("Datum", point.date),
                                          y: .value("e1RM", profile.units.displayWeight(point.value)))
                                    .foregroundStyle(Theme.accentText)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 180)
                        }
                        if let best = series.map(\.value).max() {
                            LabeledContent("Beste e1RM", value: profile.units.weightText(best))
                        }
                        if PlateauDetector.isPlateau(series.map(\.value)) {
                            Label("Drie trainingen zonder vooruitgang. Probeer een ander rep-bereik, vervang de oefening tijdelijk of neem een deload.",
                                  systemImage: "chart.line.flattrend.xyaxis")
                                .font(.footnote)
                                .foregroundStyle(Theme.warn)
                        }
                    }
                }
                if !records.isEmpty {
                    Section("Records") {
                        ForEach(records.prefix(10)) { record in
                            LabeledContent {
                                Text(record.date, format: .dateTime.day().month().year())
                            } label: {
                                Text("\(record.kind.title): \(profile.units.weightText(record.weightKg, digits: 2)) × \(record.reps)")
                            }
                        }
                    }
                }
                if exercise.isCustom {
                    Section {
                        Button("Verwijder oefening", role: .destructive) {
                            context.delete(exercise)
                            dismiss()
                        }
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Uitvoering van een oefening: stappen, een tip, de meest gemaakte fout en een link naar video's.
struct ExerciseGuideSection: View {
    let exercise: Exercise
    let guide: ExerciseGuide

    var body: some View {
        Section("Uitvoering") {
            if let pattern = MovementPattern.pattern(for: exercise.slug) {
                ExerciseAnimation(pattern: pattern)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(Theme.number(.subheadline))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 26, height: 26)
                        .background(Theme.accent, in: Circle())
                        .accessibilityHidden(true)
                    Text(step.prefix(1).uppercased() + step.dropFirst() + ".")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Stap \(index + 1): \(step)"))
            }
            Label {
                Text(guide.tip).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(Theme.warn)
            }
            Label {
                Text(guide.mistake).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
            }
            .accessibilityLabel(Text("Veelgemaakte fout: \(guide.mistake)"))
            if let url = Self.videoURL(for: exercise) {
                Link(destination: url) {
                    Label("Bekijk video's van de uitvoering", systemImage: "play.rectangle.fill")
                }
            }
        }
    }

    /// Zoekt op YouTube naar de Engelse naam; daar staan de meeste goede techniekvideo's.
    static func videoURL(for exercise: Exercise) -> URL? {
        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [URLQueryItem(name: "search_query", value: "\(exercise.nameEN) proper form")]
        return components?.url
    }
}

/// Uitvoering als blad, te openen tijdens een training.
struct ExerciseGuideSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        LabeledContent("Primair", value: exercise.primaryMuscle.title)
                        if !exercise.secondaryMuscles.isEmpty {
                            LabeledContent("Secundair", value: exercise.secondaryMuscles.map(\.title).joined(separator: ", "))
                        }
                    }
                    if let guide = ExerciseGuide.guide(for: exercise.slug) {
                        ExerciseGuideSection(exercise: exercise, guide: guide)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klaar") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
