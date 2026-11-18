import PowerCore
import SwiftData
import SwiftUI

/// Samenvatting direct na het afronden: cijfers, vergelijking met de vorige keer, records en delen.
struct WorkoutSummaryView: View {
    let workout: Workout
    let profile: UserProfile
    let onDone: () -> Void
    @Query(sort: \Workout.startedAt) private var allWorkouts: [Workout]
    @Query(sort: \PersonalRecord.date) private var allRecords: [PersonalRecord]
    @State private var shareImage: Image?

    private var finished: [Workout] { allWorkouts.filter { $0.endedAt != nil } }
    private var records: [PersonalRecord] { allRecords.filter { $0.date >= workout.startedAt } }
    private var minutes: Int { max(1, Int((workout.duration ?? 0) / 60)) }

    var body: some View {
        let change = Insights.volumeChange(of: workout, among: finished)
        let streak = Insights.weekStreak(finished: finished)
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.accentText)
                        .symbolEffect(.bounce, value: workout.endedAt)
                        .accessibilityHidden(true)
                    Text("Training voltooid")
                        .font(.largeTitle.weight(.bold))
                    Text(workout.name)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    StatTile(value: "\(minutes) min", label: String(localized: "Duur"), symbol: "clock.fill").card()
                    StatTile(value: profile.units.weightText(workout.volumeKg, digits: 0),
                             label: String(localized: "Volume"), symbol: "scalemass.fill").card()
                    StatTile(value: "\(workout.doneSets.count)", label: String(localized: "Sets"),
                             symbol: "checkmark.circle.fill").card()
                    if records.isEmpty {
                        StatTile(value: "\(Insights.exercisesDone(in: workout))", label: String(localized: "Oefeningen"),
                                 symbol: "list.bullet", tint: Theme.cool).card()
                    } else {
                        StatTile(value: "\(Set(records.map(\.exerciseSlug)).count)", label: String(localized: "Records"),
                                 symbol: "trophy.fill", tint: Theme.warn).card()
                    }
                }

                if let change, change >= 0.01 {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.good)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("+\(Int((change * 100).rounded()))% volume")
                                .font(.headline)
                            Text("Vergeleken met je vorige \(workout.name)")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .card()
                    .accessibilityElement(children: .combine)
                }

                if streak > 1 {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.title2).foregroundStyle(Theme.warn).accessibilityHidden(true)
                        Text("\(streak) weken op rij getraind")
                            .font(.headline)
                        Spacer(minLength: 0)
                    }
                    .card()
                }

                let muscles = Insights.muscles(in: workout)
                if !muscles.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Getrainde spiergroepen")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        MuscleTags(muscles: muscles)
                    }
                    .card()
                }

                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nieuwe records")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(records) { record in
                            HStack {
                                Image(systemName: "trophy.fill").foregroundStyle(Theme.warn).accessibilityHidden(true)
                                Text(record.exerciseName).font(.body.weight(.semibold))
                                Spacer()
                                Text("\(record.kind.title) · \(profile.units.weightText(record.weightKg, digits: 2)) × \(record.reps)")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .card()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let shareImage {
                    ShareLink(item: shareImage,
                              preview: SharePreview(workout.name, image: shareImage)) {
                        Label("Deel samenvatting", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                Button("Klaar", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .background(.bar)
        }
        .overlay {
            if !records.isEmpty, profile.celebratePRs { ConfettiView() }
        }
        .task { renderShareImage() }
    }

    private func renderShareImage() {
        let card = ShareCard(name: workout.name, date: workout.startedAt, minutes: minutes,
                             volume: profile.units.weightText(workout.volumeKg, digits: 0),
                             sets: workout.doneSets.count,
                             records: Set(records.map(\.exerciseSlug)).count)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }
}

/// Afbeelding om te delen: altijd donker, vaste maat.
private struct ShareCard: View {
    let name: String
    let date: Date
    let minutes: Int
    let volume: String
    let sets: Int
    let records: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("RIVO")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(date, format: .dateTime.day().month(.wide).year())
                    .font(.caption).foregroundStyle(Theme.Share.muted)
            }
            Spacer()
            Text(name)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.Share.text)
            HStack(spacing: 22) {
                stat("\(minutes) min", String(localized: "Duur"))
                stat(volume, String(localized: "Volume"))
                stat("\(sets)", String(localized: "Sets"))
                if records > 0 { stat("\(records)", String(localized: "Records")) }
            }
        }
        .padding(28)
        .frame(width: 360, height: 420)
        .background(
            Theme.Share.background)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Share.text)
            Text(label).font(.caption).foregroundStyle(Theme.Share.muted)
        }
    }
}
