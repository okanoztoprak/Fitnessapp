import PowerCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section("Weergave") {
                Picker("Weergave", selection: $profile.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
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
                Picker("Schema", selection: $profile.preferredPlan) {
                    Text("Automatisch").tag(StarterPlan?.none)
                    ForEach(StarterPlan.allCases, id: \.self) { Text($0.title).tag(StarterPlan?.some($0)) }
                }
                Picker("Apparatuur", selection: $profile.equipment) {
                    ForEach(Equipment.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Stepper("Rusttijd: \(profile.restSeconds) s", value: $profile.restSeconds, in: 30...600, step: 15)
                Picker("1RM-formule", selection: $profile.e1rmFormula) {
                    Text("Epley").tag(OneRepMax.Formula.epley)
                    Text("Brzycki").tag(OneRepMax.Formula.brzycki)
                }
                Toggle("Records vieren", isOn: $profile.celebratePRs)
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
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Instellingen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
