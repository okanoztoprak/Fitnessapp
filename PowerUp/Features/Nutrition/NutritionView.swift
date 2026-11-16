import PowerCore
import SwiftData
import SwiftUI

/// Fase 1: TDEE-calculator en doelen. De Apple Health-koppeling (MyFitnessPal) volgt in fase 2.
struct NutritionView: View {
    @Bindable var profile: UserProfile
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights: [BodyWeightEntry]

    var body: some View {
        let weightKg = weights.first?.kg ?? 75
        let target = EnergyCalculator.target(profile.energyInput(weightKg: weightKg), goal: profile.goal)
        let macros = EnergyCalculator.macros(kcal: target.kcal, weightKg: weightKg, goal: profile.goal,
                                             bodyFatPercent: profile.bodyFatPercent)
        NavigationStack {
            List {
                Section("Instellingen") {
                    Picker("Doel", selection: $profile.goal) {
                        ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Activiteit", selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                if profile.hideCalories {
                    Section {
                        Text("Calorieën zijn verborgen. Je ziet hieronder alleen je eiwitdoel.")
                            .foregroundStyle(.secondary)
                        LabeledContent("Eiwit", value: "\(Int(macros.proteinG.rounded())) g")
                    }
                } else {
                    Section {
                        LabeledContent("Rustverbranding (BMR)", value: "\(Int(target.bmr.rounded())) kcal")
                        LabeledContent("Dagverbruik (TDEE)", value: "\(Int(target.tdee.rounded())) kcal")
                        LabeledContent("Formule",
                                       value: target.formula == .katchMcArdle ? "Katch-McArdle" : "Mifflin-St Jeor")
                    } header: {
                        Text("Je verbruik")
                    } footer: {
                        Text("Dit is een schatting. Vanaf fase 2 berekent de app je echte verbruik uit je inname en gewichtstrend.")
                    }
                    Section("Dagdoel") {
                        HStack {
                            StatView(value: "\(Int(target.kcal.rounded()))", label: "kcal")
                            StatView(value: "\(Int(macros.proteinG.rounded())) g", label: String(localized: "Eiwit"))
                            StatView(value: "\(Int(macros.carbsG.rounded())) g", label: String(localized: "Koolh."))
                            StatView(value: "\(Int(macros.fatG.rounded())) g", label: String(localized: "Vet"))
                        }
                        if abs(target.expectedWeeklyChangeKg) > 0.01 {
                            LabeledContent("Verwacht per week",
                                           value: "\(target.expectedWeeklyChangeKg > 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(target.expectedWeeklyChangeKg), digits: 2)) \(profile.units.weightUnit)")
                        }
                        if target.wasFloored {
                            Label("Je doel is verhoogd naar je rustverbranding. Lager gaan we niet.",
                                  systemImage: "shield.fill")
                                .font(.footnote)
                        }
                        if target.exceedsSafeLossRate {
                            Label("Dit tempo is meer dan 1% van je lichaamsgewicht per week. Dat is moeilijk vol te houden en kost spiermassa.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Section {
                    Label("Koppeling met MyFitnessPal via Apple Health komt in de volgende fase.",
                          systemImage: "heart.text.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Voeding")
        }
    }
}
