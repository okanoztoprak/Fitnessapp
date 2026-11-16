import PowerCore
import SwiftData
import SwiftUI

struct HeroView: View {
    let profile: UserProfile
    @Query(sort: \PowerLevelSnapshot.date, order: .reverse) private var snapshots: [PowerLevelSnapshot]
    @Query(sort: \XPEvent.date, order: .reverse) private var xpEvents: [XPEvent]

    var body: some View {
        let snapshot = snapshots.first
        let stage = Stage.stage(forPowerLevel: snapshot?.total ?? 0)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PowerLevelCard(snapshot: snapshot)
                    breakdownCard(snapshot)
                    LevelCard(totalXP: xpEvents.reduce(0) { $0 + $1.amount },
                              streak: StreakCalculator.current(activeDays: xpEvents.map(\.date),
                                                               today: Date(), calendar: .current))
                    stagesCard(current: stage)
                    xpCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Held")
            .toolbar {
                NavigationLink {
                    SettingsView(profile: profile)
                } label: {
                    Label("Instellingen", systemImage: "gearshape.fill")
                }
            }
        }
    }

    private func breakdownCard(_ snapshot: PowerLevelSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Opbouw")
                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            component(String(localized: "Kracht"), value: snapshot?.strength ?? 0,
                      maximum: PowerLevelCalculator.maxStrength, color: Stage.limitBreaker.auraColor)
            component(String(localized: "Consistentie"), value: snapshot?.consistency ?? 0,
                      maximum: PowerLevelCalculator.maxConsistency, color: Stage.awakened.auraColor)
            component(String(localized: "Conditie"), value: snapshot?.conditioning ?? 0,
                      maximum: PowerLevelCalculator.maxConditioning, color: Stage.ascended.auraColor)
            Text("Kracht telt je beste geschatte 1RM ten opzichte van je lichaamsgewicht. Consistentie telt alleen tot je geplande aantal trainingen: meer trainen dan gepland levert niets extra's op.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .comicCard()
    }

    private func component(_ title: String, value: Int, maximum: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value)").font(.subheadline.monospacedDigit())
            }
            EnergyBar(fraction: Double(value) / maximum, color: color)
        }
        .accessibilityElement(children: .combine)
    }

    private func stagesCard(current: Stage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transformaties")
                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(Stage.allCases, id: \.self) { stage in
                let unlocked = stage.threshold <= current.threshold
                HStack {
                    Image(systemName: unlocked ? "flame.fill" : "lock.fill")
                        .foregroundStyle(unlocked ? stage.auraColor : Color.secondary)
                        .frame(width: 24)
                    Text(stage.title)
                        .font(stage == current ? Theme.display(.headline) : .body)
                    Spacer()
                    Text("\(stage.threshold)")
                        .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
                .opacity(unlocked ? 1 : 0.55)
                .accessibilityElement(children: .combine)
            }
        }
        .comicCard()
    }

    private var xpCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recente XP")
                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if xpEvents.isEmpty {
                Text("Train, weeg jezelf en verbeter je records om XP te verdienen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(xpEvents.prefix(8)) { event in
                HStack {
                    Text(event.source.title)
                    Spacer()
                    Text(event.date, format: .dateTime.day().month())
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("+\(event.amount) XP")
                        .font(.subheadline.weight(.heavy)).foregroundStyle(Theme.accent)
                }
            }
        }
        .comicCard()
    }
}
