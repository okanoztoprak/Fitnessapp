import PowerCore
import SwiftData
import SwiftUI

/// Wekelijkse check-in: wat er gebeurde, wat je verbruik is, en een voorstel voor je nieuwe doel.
struct CheckInSheet: View {
    @Bindable var profile: UserProfile
    let plan: NutritionPlan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let estimate = plan.expenditure
        let proposal = plan.proposal(goal: profile.goal)
        let newMacros = EnergyCalculator.macros(kcal: proposal.targetKcal, weightKg: plan.weightKg, goal: profile.goal,
                                                bodyFatPercent: profile.bodyFatPercent,
                                                proteinPerKg: profile.proteinPerKg, fatShare: profile.fatShare)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wekelijkse check-in").font(.largeTitle.weight(.bold))
                        Text("De afgelopen \(AdaptiveExpenditure.windowDays) dagen, tot en met gisteren.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        StatTile(value: estimate.averageIntake.map { "\(Int($0.rounded()))" } ?? "–",
                                 label: String(localized: "Gem. inname (kcal)"), symbol: "fork.knife").card()
                        StatTile(value: estimate.trendRatePerWeek.map {
                                     "\($0 >= 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight($0), digits: 2)) \(profile.units.weightUnit)"
                                 } ?? "–",
                                 label: String(localized: "Trendgewicht per week"), symbol: "scalemass.fill",
                                 tint: Theme.cool).card()
                        StatTile(value: "\(Int(estimate.kcal.rounded()))", label: String(localized: "Verbruik (kcal)"),
                                 symbol: "flame.fill", tint: Theme.warn).card()
                        StatTile(value: "\(estimate.loggedDays)", label: String(localized: "Dagen gelogd"),
                                 symbol: "checkmark.circle.fill", tint: Theme.good).card()
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Je nieuwe dagdoel")
                            .font(.caption.weight(.bold)).textCase(.uppercase).tracking(0.8)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(Int(proposal.previousKcal.rounded()))")
                                .font(Theme.number(.title2))
                                .foregroundStyle(.secondary)
                                .strikethrough(abs(proposal.change) >= 10)
                            Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
                            CountUp(value: Int(proposal.targetKcal)).font(Theme.number(.largeTitle))
                            Text("kcal").foregroundStyle(.secondary)
                        }
                        if abs(proposal.change) >= 10 {
                            Tag(text: "\(proposal.change > 0 ? "+" : "−")\(Int(abs(proposal.change))) kcal",
                                color: proposal.change > 0 ? Theme.good : Theme.cool, filled: true, uppercase: false)
                        }
                        Text(reason(proposal: proposal, estimate: estimate))
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        MacroBar(macros: newMacros)
                    }
                    .card()

                    if estimate.confidence < 1 {
                        Label("Nog niet alle data is binnen, dus de formule telt nog mee. Blijf loggen en wegen voor een scherper verbruik.",
                              systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                            .card(padding: 14)
                    }
                }
                .padding()
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button("Nieuw doel overnemen") { finish(proposal: proposal, estimate: estimate, accept: true) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Huidig doel houden") { finish(proposal: proposal, estimate: estimate, accept: false) }
                        .buttonStyle(SoftButtonStyle())
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } }
            }
        }
    }

    private func reason(proposal: CheckInProposal, estimate: ExpenditureEstimate) -> String {
        if proposal.wasFloored {
            return String(localized: "Je doel staat op je rustverbranding. Lager gaan we niet, ook niet als je sneller wilt.")
        }
        if proposal.wasRateLimited {
            return String(localized: "Begrensd zodat je niet meer dan 1% van je lichaamsgewicht per week verliest.")
        }
        if proposal.wasStepLimited {
            return String(localized: "Je verbruik wijkt flink af van je doel. We passen het stap voor stap aan, zodat je kunt wennen.")
        }
        if abs(proposal.change) < 10 {
            return String(localized: "Je doel past bij je verbruik. Ga zo door.")
        }
        return proposal.change > 0
            ? String(localized: "Je verbruikt meer dan gedacht. Met meer eten blijf je op koers voor je doel.")
            : String(localized: "Je verbruikt minder dan gedacht. Met iets minder eten blijf je op koers voor je doel.")
    }

    private func finish(proposal: CheckInProposal, estimate: ExpenditureEstimate, accept: Bool) {
        context.insert(CheckIn(estimate: estimate, proposal: proposal, accepted: accept))
        if accept { profile.calorieTargetKcal = proposal.targetKcal }
        context.saveOrLog()
        Haptics.success()
        dismiss()
    }
}
