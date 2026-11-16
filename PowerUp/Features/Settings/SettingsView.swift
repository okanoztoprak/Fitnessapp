import PowerCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section("Eenheden") {
                Picker("Eenheden", selection: $profile.usesMetric) {
                    Text("kg / cm").tag(true)
                    Text("lb / inch").tag(false)
                }
                .pickerStyle(.segmented)
            }
            Section("Training") {
                Stepper("\(profile.trainingDaysPerWeek) dagen per week",
                        value: $profile.trainingDaysPerWeek, in: 2...6)
                Picker("Apparatuur", selection: $profile.equipment) {
                    ForEach(Equipment.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Stepper("Rusttijd: \(profile.restSeconds) s", value: $profile.restSeconds, in: 30...600, step: 15)
                Picker("1RM-formule", selection: $profile.e1rmFormula) {
                    Text("Epley").tag(OneRepMax.Formula.epley)
                    Text("Brzycki").tag(OneRepMax.Formula.brzycki)
                }
            }
            Section("Mentor") {
                Picker("Toon", selection: $profile.mentorTone) {
                    ForEach(MentorTone.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Recordmoment vieren", isOn: $profile.celebratePRs)
            }
            Section {
                Toggle("Calorieën verbergen", isOn: $profile.hideCalories)
                Toggle("Gewicht verbergen", isOn: $profile.hideWeight)
            } header: {
                Text("Welzijn")
            } footer: {
                Text("Verberg getallen als je merkt dat ze je geen goed doen. Loggen en je trend blijven op de achtergrond werken.")
            }
            Section("Over") {
                Text("POWER UP geeft geen medisch advies. Overleg bij twijfel, klachten of een medische aandoening met een arts.")
                    .font(.footnote)
                LabeledContent("Versie",
                               value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
            }
        }
        .navigationTitle("Instellingen")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profile.trainingDaysPerWeek) { GameService.refreshPowerLevel(in: context) }
    }
}
