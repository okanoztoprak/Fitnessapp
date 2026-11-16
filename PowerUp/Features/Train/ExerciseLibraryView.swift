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
        .searchable(text: $search, prompt: "Zoek een oefening")
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Theme.accent : Color(.tertiarySystemFill), in: Capsule())
                .foregroundStyle(selected ? Color.black : Color.primary)
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
            Section {
                LabeledContent("Primair", value: exercise.primaryMuscle.title)
                if !exercise.secondaryMuscles.isEmpty {
                    LabeledContent("Secundair",
                                   value: exercise.secondaryMuscles.map(\.title).joined(separator: ", "))
                }
                LabeledContent("Materiaal", value: GearLabel.title(exercise.gearRaw))
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
                                .foregroundStyle(Theme.accent)
                            PointMark(x: .value("Datum", point.date),
                                      y: .value("e1RM", profile.units.displayWeight(point.value)))
                                .foregroundStyle(Theme.accent)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                    }
                    if let best = series.map(\.value).max() {
                        LabeledContent("Beste e1RM", value: profile.units.weightText(best))
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
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
