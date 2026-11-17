import PowerCore
import SwiftData
import SwiftUI

/// Dagdoel en verbruik. De koppeling met Apple Health (MyFitnessPal) volgt in fase 2.
struct NutritionView: View {
    @Bindable var profile: UserProfile
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights: [BodyWeightEntry]

    var body: some View {
        let weightKg = weights.first?.kg ?? 75
        let target = EnergyCalculator.target(profile.energyInput(weightKg: weightKg), goal: profile.goal)
        let macros = EnergyCalculator.macros(kcal: target.kcal, weightKg: weightKg, goal: profile.goal,
                                             bodyFatPercent: profile.bodyFatPercent)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if profile.hideCalories {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calorieën zijn verborgen. Je ziet hieronder alleen je eiwitdoel.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(Int(macros.proteinG.rounded()))").font(Theme.number(.largeTitle))
                                Text("g eiwit per dag").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .card()
                    } else {
                        targetCard(target: target, macros: macros)
                        warnings(target: target)
                        expenditureCard(target: target)
                    }
                    settingsCard
                    Label("Koppeling met MyFitnessPal via Apple Health komt in de volgende fase.",
                          systemImage: "heart.text.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Voeding")
        }
    }

    private func targetCard(target: CalorieTarget, macros: MacroTarget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dagdoel")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CountUp(value: Int(target.kcal.rounded()))
                    .font(Theme.number(.largeTitle))
                Text("kcal").font(.title3).foregroundStyle(.secondary)
            }
            MacroBar(macros: macros)
            if abs(target.expectedWeeklyChangeKg) > 0.01 {
                Divider()
                HStack {
                    Text("Verwacht per week").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(target.expectedWeeklyChangeKg > 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(target.expectedWeeklyChangeKg), digits: 2)) \(profile.units.weightUnit)")
                        .font(Theme.number(.subheadline))
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private func warnings(target: CalorieTarget) -> some View {
        if target.wasFloored {
            Label("Je doel is verhoogd naar je rustverbranding. Lager gaan we niet.", systemImage: "shield.fill")
                .font(.footnote)
                .card(padding: 14)
        }
        if target.exceedsSafeLossRate {
            Label("Dit tempo is meer dan 1% van je lichaamsgewicht per week. Dat is moeilijk vol te houden en kost spiermassa.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.warn)
                .card(padding: 14)
        }
    }

    private func expenditureCard(target: CalorieTarget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Je verbruik").font(.headline)
            HStack {
                StatTile(value: "\(Int(target.bmr.rounded()))", label: String(localized: "Rustverbranding (BMR)"),
                         symbol: "bed.double.fill", tint: Theme.violet)
                StatTile(value: "\(Int(target.tdee.rounded()))", label: String(localized: "Dagverbruik (TDEE)"),
                         symbol: "flame.fill", tint: Theme.warn)
            }
            Text("Geschat met \(target.formula == .katchMcArdle ? "Katch-McArdle" : "Mifflin-St Jeor"). Vanaf fase 2 berekent de app je echte verbruik uit je inname en gewichtstrend.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Doel")
                Spacer()
                Picker("Doel", selection: $profile.goal) {
                    ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
            }
            .padding(.vertical, 4)
            Divider()
            HStack {
                Text("Activiteit")
                Spacer()
                Picker("Activiteit", selection: $profile.activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
            }
            .padding(.vertical, 4)
        }
        .card(padding: 14)
    }
}
