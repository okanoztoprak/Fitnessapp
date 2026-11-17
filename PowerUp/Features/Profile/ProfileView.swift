import PowerCore
import SwiftData
import SwiftUI

/// Krachtniveau, totalen en mijlpalen.
struct ProfileView: View {
    let profile: UserProfile
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query(sort: \Workout.startedAt) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }
    /// Trendgewicht zonder uitschieters; een enkele tikfout verandert het krachtniveau niet.
    private var trendWeight: Double {
        let points = weights.map { WeightPoint(date: $0.date, kg: $0.kg) }
        return WeightTrend.ema(AdaptiveExpenditure.withoutOutliers(points)).last?.kg ?? 0
    }

    private struct LiftRow: Identifiable {
        let lift: MainLift
        let e1rm: Double
        let fraction: Double
        var id: String { lift.rawValue }
    }

    private var lifts: [LiftRow] {
        let best = Insights.bestLifts(finished: finished, formula: profile.e1rmFormula)
        let bodyWeight = trendWeight
        return MainLift.allCases.map { lift in
            let e1rm = best[lift] ?? 0
            return LiftRow(lift: lift, e1rm: e1rm,
                           fraction: StrengthStandards.fraction(e1rm: e1rm, bodyWeightKg: bodyWeight,
                                                                lift: lift, sex: profile.sex))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    strengthCard
                    totalsCard
                    milestonesCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Profiel")
            .toolbar {
                NavigationLink {
                    SettingsView(profile: profile)
                } label: {
                    Label("Instellingen", systemImage: "gearshape.fill")
                }
            }
        }
    }

    // MARK: Kracht

    private var strengthCard: some View {
        let logged = lifts.filter { $0.e1rm > 0 }
        let overall = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.fraction } / Double(logged.count)
        let level = StrengthStandards.level(fraction: overall)
        let bodyWeight = trendWeight
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Ring(progress: min(overall, 1), lineWidth: 10, color: Theme.accent)
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accentText)
                        .accessibilityHidden(true)
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Krachtniveau")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(logged.isEmpty ? String(localized: "Nog onbekend") : level.title)
                        .font(.title2.weight(.bold))
                    Text(logged.isEmpty
                         ? String(localized: "Log een squat, bankdruk, deadlift, overhead press of row om je niveau te zien.")
                         : logged.count == 1
                         ? String(localized: "Je geschatte 1RM ten opzichte van je lichaamsgewicht, op basis van 1 lift.")
                         : String(localized: "Je geschatte 1RM ten opzichte van je lichaamsgewicht, over \(logged.count) lifts."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            ForEach(lifts) { row in
                let rowLevel = StrengthStandards.level(fraction: row.fraction)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.lift.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(row.e1rm > 0 ? profile.units.weightText(row.e1rm, digits: 0) : "–")
                            .font(Theme.number(.subheadline))
                            .monospacedDigit()
                    }
                    ProgressBar(fraction: min(row.fraction, 1),
                                color: row.e1rm > 0 ? Theme.accentText : Color.secondary)
                    HStack {
                        Text(row.e1rm > 0 ? rowLevel.title : String(localized: "Nog niet gelogd"))
                        Spacer()
                        if row.e1rm > 0,
                           let next = rowLevel.next,
                           let target = StrengthStandards.nextTarget(fraction: row.fraction, bodyWeightKg: bodyWeight,
                                                                     lift: row.lift, sex: profile.sex) {
                            Text("\(next.title) vanaf \(profile.units.weightText(target, digits: 0))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    // MARK: Totalen

    private var totalsCard: some View {
        let hours = finished.reduce(0) { $0 + ($1.duration ?? 0) } / 3600
        let volume = finished.reduce(0) { $0 + $1.volumeKg }
        return HStack {
            StatTile(value: "\(finished.count)", label: String(localized: "Trainingen"), symbol: "checkmark.circle.fill")
            StatTile(value: hours < 1 ? "\(Int((hours * 60).rounded())) min" : String(localized: "\(UnitFormatter.number(hours, digits: 1)) u"),
                     label: String(localized: "Getraind"), symbol: "clock.fill", tint: Theme.cool)
            StatTile(value: profile.units.weightText(volume, digits: 0), label: String(localized: "Totaal volume"),
                     symbol: "scalemass.fill", tint: Theme.violet)
        }
        .card()
    }

    // MARK: Mijlpalen

    private var milestonesCard: some View {
        let milestones = Insights.milestones(finished: finished,
                                             recordCount: Set(records.map { "\($0.exerciseSlug)-\($0.weightKg)-\($0.reps)" }).count,
                                             streak: Insights.weekStreak(finished: finished))
        let achieved = milestones.filter(\.achieved).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mijlpalen").font(.headline)
                Spacer()
                Text("\(achieved) van \(milestones.count)")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 16) {
                ForEach(milestones) { milestone in
                    VStack(spacing: 8) {
                        ZStack {
                            if milestone.achieved {
                                Circle().fill(Theme.accent)
                            } else {
                                Ring(progress: milestone.progress, lineWidth: 4, color: Theme.accentText)
                            }
                            Image(systemName: milestone.symbol)
                                .font(.title3)
                                .foregroundStyle(milestone.achieved ? Theme.onAccent : Color.secondary)
                        }
                        .frame(width: 56, height: 56)
                        Text(milestone.title)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(milestone.achieved ? Color.primary : Color.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(milestone.title)
                    .accessibilityValue(milestone.achieved ? Text("Behaald") : Text("\(Int((min(milestone.progress, 1) * 100).rounded()))%"))
                }
            }
        }
        .card()
    }
}
