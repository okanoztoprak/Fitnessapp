import PowerCore
import SwiftData
import SwiftUI

/// Haalt alles op wat het weekoverzicht en de uitdagingen nodig hebben.
struct MotivationQuery<Content: View>: View {
    let profile: UserProfile
    @ViewBuilder let content: (MotivationData) -> Content
    @Query(sort: \Workout.startedAt) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]
    @Query(sort: \NutritionEntry.date) private var nutrition: [NutritionEntry]
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query private var programs: [TrainingProgram]

    var body: some View {
        content(MotivationData(profile: profile, finished: workouts.filter { $0.endedAt != nil }, records: records,
                               nutrition: nutrition, weights: weights, program: ProgramStatus.active(programs)))
    }
}

// MARK: - Weekoverzicht

/// Uitnodiging bovenaan Vandaag zodra het overzicht van vorige week klaarstaat.
struct RecapBanner: View {
    let data: MotivationData
    let weekStart: Date
    @State private var showRecap = false

    var body: some View {
        let review = data.review(weekStart: weekStart).review
        Button {
            showRecap = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Ring(progress: Double(review.score) / 100, lineWidth: 6, color: Theme.accent)
                    Text("\(review.score)").font(Theme.number(.subheadline))
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Je week in cijfers").font(.headline)
                    Text(MotivationText.weekTitle(weekStart)).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .card(padding: 14)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.accentText.opacity(0.5), lineWidth: 1.5)
            }
        }
        .buttonStyle(PressableStyle())
        // Pas bij sluiten als gezien markeren; anders verdwijnt de banner en sluit de sheet direct.
        .sheet(isPresented: $showRecap, onDismiss: { data.profile.lastRecapSeen = Date() }) {
            WeeklyRecapView(data: data, weekStart: weekStart)
        }
    }
}

struct WeeklyRecapView: View {
    let data: MotivationData
    let weekStart: Date
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    var body: some View {
        let result = data.review(weekStart: weekStart)
        let summary = result.summary
        let review = result.review
        let units = data.profile.units
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 10) {
                        Text(MotivationText.weekTitle(weekStart))
                            .font(.footnote.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
                        ZStack {
                            Ring(progress: Double(review.score) / 100, lineWidth: 16, color: Theme.accent)
                            VStack(spacing: -2) {
                                CountUp(value: review.score).font(.system(size: 52, weight: .bold, design: .rounded))
                                Text("weekscore").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 170, height: 170)
                        Text(MotivationText.scoreLabel(review.score)).font(.title2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    scoreBreakdown(review)

                    if !review.highlights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hoogtepunten").font(.headline)
                            ForEach(Array(review.highlights.enumerated()), id: \.offset) { _, highlight in
                                let item = MotivationText.highlight(highlight)
                                HStack(spacing: 12) {
                                    Image(systemName: item.symbol)
                                        .foregroundStyle(Theme.onAccent)
                                        .frame(width: 32, height: 32)
                                        .background(Theme.accent, in: Circle())
                                        .accessibilityHidden(true)
                                    Text(item.text).font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Training").font(.headline)
                        HStack {
                            StatTile(value: "\(summary.workouts)/\(summary.plannedWorkouts)", label: String(localized: "Trainingen"),
                                     symbol: "dumbbell.fill")
                            StatTile(value: "\(summary.hardSets)", label: String(localized: "Harde sets"),
                                     symbol: "flame.fill", tint: Theme.warn)
                            StatTile(value: units.weightText(summary.volumeKg, digits: 0), label: String(localized: "Volume"),
                                     symbol: "scalemass.fill", tint: Theme.cool)
                        }
                        if let change = review.volumeChange {
                            Text("\(change >= 0 ? "+" : "")\(Int((change * 100).rounded()))% volume ten opzichte van de week ervoor")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .card()

                    if data.tracksNutrition {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voeding").font(.headline)
                            HStack {
                                StatTile(value: "\(summary.loggedFoodDays)/7", label: String(localized: "Dagen gelogd"),
                                         symbol: "list.bullet.clipboard.fill", tint: Theme.cool)
                                StatTile(value: "\(summary.daysOnTarget)", label: String(localized: "Op doel"),
                                         symbol: "target", tint: Theme.good)
                                StatTile(value: "\(summary.proteinDays)", label: String(localized: "Eiwitdagen"),
                                         symbol: "fork.knife", tint: Theme.violet)
                            }
                        }
                        .card()
                    }

                    if let change = summary.trendChangeKg, !data.profile.hideWeight {
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass.fill").foregroundStyle(Theme.violet).accessibilityHidden(true)
                            Text("Trendgewicht: \(change >= 0 ? "+" : "")\(UnitFormatter.number(units.displayWeight(change), digits: 2)) \(units.weightUnit) deze week")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .card()
                    }

                    let focus = MotivationText.focus(review.focus)
                    VStack(alignment: .leading, spacing: 6) {
                        Tag(text: String(localized: "Focus volgende week"), color: Theme.cool, filled: true)
                        Text(focus.title).font(.title3.weight(.bold))
                        Text(focus.text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .card()
                }
                .padding()
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(MotivationText.weekTitle(weekStart), image: shareImage)) {
                        Label("Deel je week", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                    .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
            }
            .task { renderShareImage(summary: summary, review: review) }
        }
    }

    private func scoreBreakdown(_ review: WeeklyReview) -> some View {
        VStack(spacing: 12) {
            breakdownRow(String(localized: "Training"), value: review.training, color: Theme.accentText)
            if let nutrition = review.nutrition {
                breakdownRow(String(localized: "Voeding"), value: nutrition, color: Theme.cool)
            }
            breakdownRow(String(localized: "Wegen"), value: review.weighIns, color: Theme.violet)
        }
        .card()
    }

    private func breakdownRow(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(label).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int((value * 100).rounded()))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressBar(fraction: value, color: color)
        }
        .accessibilityElement(children: .combine)
    }

    private func renderShareImage(summary: WeekSummary, review: WeeklyReview) {
        let card = RecapShareCard(title: MotivationText.weekTitle(weekStart), score: review.score,
                                  label: MotivationText.scoreLabel(review.score), summary: summary,
                                  volume: data.profile.units.weightText(summary.volumeKg, digits: 0))
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }
}

/// Afbeelding om te delen; altijd donker, vaste maat.
private struct RecapShareCard: View {
    let title: String
    let score: Int
    let label: String
    let summary: WeekSummary
    let volume: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("POWER UP").font(.caption.weight(.heavy)).tracking(2).foregroundStyle(Theme.accent)
                Spacer()
                Text(title).font(.caption).foregroundStyle(Theme.Share.muted)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(score)").font(.system(size: 72, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
                Text(label).font(.title2.weight(.bold)).foregroundStyle(Theme.Share.text)
            }
            HStack(spacing: 22) {
                stat("\(summary.workouts)/\(summary.plannedWorkouts)", String(localized: "Trainingen"))
                stat("\(summary.hardSets)", String(localized: "Sets"))
                stat(volume, String(localized: "Volume"))
                if summary.records > 0 { stat("\(summary.records)", String(localized: "Records")) }
            }
        }
        .padding(28)
        .frame(width: 360, height: 420)
        .background(Theme.Share.background)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.Share.text)
            Text(label).font(.caption).foregroundStyle(Theme.Share.muted)
        }
    }
}

/// Eerdere weken in Voortgang.
struct RecapHistoryCard: View {
    let data: MotivationData
    @State private var selected: RecapWeek?

    struct RecapWeek: Identifiable {
        let start: Date
        var id: Date { start }
    }

    var body: some View {
        let weeks = data.recentWeeks()
        if !weeks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekoverzichten").font(.headline)
                ForEach(weeks, id: \.self) { start in
                    let review = data.review(weekStart: start).review
                    Button {
                        selected = RecapWeek(start: start)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Ring(progress: Double(review.score) / 100, lineWidth: 4, color: Theme.accent)
                                Text("\(review.score)").font(Theme.number(.caption))
                            }
                            .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MotivationText.weekTitle(start)).font(.subheadline.weight(.semibold))
                                Text(MotivationText.scoreLabel(review.score)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
            .sheet(item: $selected) { week in WeeklyRecapView(data: data, weekStart: week.start) }
        }
    }
}

// MARK: - Uitdagingen

struct ChallengesCard: View {
    let data: MotivationData
    @State private var showAll = false

    var body: some View {
        let challenges = data.currentChallenges()
        let weekly = challenges.filter { $0.period == .week }
        Button {
            showAll = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Uitdagingen").font(.headline)
                    Spacer()
                    let done = weekly.filter { data.progress(of: $0) >= Double($0.target) }.count
                    Text("\(done) van \(weekly.count)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                HStack(alignment: .top, spacing: 10) {
                    ForEach(weekly) { challenge in
                        ChallengeRing(challenge: challenge, value: data.progress(of: challenge))
                    }
                }
                if let monthly = challenges.first(where: { $0.period == .month }) {
                    let value = data.progress(of: monthly)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(MotivationText.title(monthly.kind, target: monthly.target, period: .month))
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(Int(value))/\(monthly.target)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ProgressBar(fraction: ChallengeGenerator.fraction(value: value, target: monthly.target))
                    }
                }
            }
            .foregroundStyle(.primary)
            .card()
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showAll) { ChallengesSheet(data: data) }
    }
}

private struct ChallengeRing: View {
    let challenge: ChallengeDefinition
    let value: Double

    var body: some View {
        let fraction = ChallengeGenerator.fraction(value: value, target: challenge.target)
        let color = MotivationText.color(challenge.kind)
        VStack(spacing: 8) {
            ZStack {
                Ring(progress: fraction, lineWidth: 6, color: color)
                Image(systemName: fraction >= 1 ? "checkmark" : MotivationText.symbol(challenge.kind))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 52, height: 52)
            Text(MotivationText.title(challenge.kind, target: challenge.target, period: challenge.period))
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("\(Int(min(value, Double(challenge.target))))/\(challenge.target)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ChallengesSheet: View {
    let data: MotivationData
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ChallengeRecord.completedAt, order: .reverse) private var completed: [ChallengeRecord]

    var body: some View {
        let challenges = data.currentChallenges()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Uitdagingen belonen wat je al van plan was: nooit meer trainingen dan je schema, en volume hooguit 10% meer dan normaal.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(challenges) { challenge in
                        let value = data.progress(of: challenge)
                        let fraction = ChallengeGenerator.fraction(value: value, target: challenge.target)
                        HStack(spacing: 14) {
                            ZStack {
                                Ring(progress: fraction, lineWidth: 6, color: MotivationText.color(challenge.kind))
                                Image(systemName: fraction >= 1 ? "checkmark" : MotivationText.symbol(challenge.kind))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MotivationText.color(challenge.kind))
                            }
                            .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(MotivationText.title(challenge.kind, target: challenge.target, period: challenge.period))
                                    .font(.headline)
                                Text(challenge.period == .week ? String(localized: "Deze week") : String(localized: "Deze maand"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(min(value, Double(challenge.target))))/\(challenge.target)")
                                .font(Theme.number(.headline)).monospacedDigit()
                        }
                        .card(padding: 14)
                        .accessibilityElement(children: .combine)
                    }
                    if !completed.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Badges").font(.headline)
                                Spacer()
                                Text("\(completed.count) behaald").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 14) {
                                ForEach(completed.prefix(24)) { record in
                                    VStack(spacing: 6) {
                                        Image(systemName: MotivationText.symbol(record.kind))
                                            .font(.title3)
                                            .foregroundStyle(Theme.onAccent)
                                            .frame(width: 52, height: 52)
                                            .background(MotivationText.badgeFill(record.kind), in: Circle())
                                        Text(record.completedAt, format: .dateTime.day().month())
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(MotivationText.title(record.kind, target: record.target, period: record.period))
                                }
                            }
                        }
                        .card()
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Uitdagingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
            }
        }
    }
}

/// Legt nieuw voltooide uitdagingen vast en geeft ze terug voor een felicitatie.
@MainActor
enum ChallengeTracker {
    static func newlyCompleted(data: MotivationData, in context: ModelContext) -> [ChallengeDefinition] {
        let known = Set(((try? context.fetch(FetchDescriptor<ChallengeRecord>())) ?? []).map(\.challengeID))
        let done = data.currentChallenges().filter { !known.contains($0.id) && data.progress(of: $0) >= Double($0.target) }
        for challenge in done { context.insert(ChallengeRecord(definition: challenge)) }
        if !done.isEmpty { context.saveOrLog() }
        return done
    }
}
