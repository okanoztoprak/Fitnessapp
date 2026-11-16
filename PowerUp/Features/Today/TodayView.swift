import Charts
import PowerCore
import SwiftData
import SwiftUI

struct TodayView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \PowerLevelSnapshot.date, order: .reverse) private var snapshots: [PowerLevelSnapshot]
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var xpEvents: [XPEvent]
    @State private var showWeightSheet = false

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }
    private var active: Workout? { workouts.first { $0.endedAt == nil } }
    private var trainedToday: Bool {
        finished.contains { Calendar.current.isDateInToday($0.startedAt) }
    }
    private var nextDay: TemplateDay? {
        let days = StarterTemplates.days(for: profile)
        return days.isEmpty ? nil : days[finished.count % days.count]
    }
    private var streak: Int {
        StreakCalculator.current(activeDays: xpEvents.map(\.date), today: Date(), calendar: .current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mentorCard
                    PowerLevelCard(snapshot: snapshots.first)
                    workoutCard
                    LevelCard(totalXP: xpEvents.reduce(0) { $0 + $1.amount }, streak: streak)
                    if !profile.hideCalories { caloriesCard }
                    weightCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Vandaag")
            .sheet(isPresented: $showWeightSheet) {
                LogWeightSheet(profile: profile)
            }
        }
    }

    private var mentorCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "figure.martial.arts")
                .font(.title)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Mentor.name).font(.caption).foregroundStyle(.secondary)
                Text(Mentor.line(trainedToday ? .workoutDone : .greeting, tone: profile.mentorTone))
                    .font(.callout.weight(.semibold))
            }
        }
        .comicCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training van vandaag")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if let active {
                Text(active.name).font(Theme.display(.title2))
                Text("Bezig sinds \(active.startedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Ga verder") { router.presentedWorkout = active }
                    .buttonStyle(ComicButtonStyle())
            } else if trainedToday {
                Label("Training afgerond", systemImage: "checkmark.seal.fill")
                    .font(Theme.display(.title3))
                Text("Herstel hoort bij het plan. Tot de volgende sessie.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if let nextDay {
                Text(nextDay.name).font(Theme.display(.title2))
                Text("\(nextDay.slugs.count) oefeningen")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Start training") {
                    router.presentedWorkout = WorkoutFactory.start(name: nextDay.name, slugs: nextDay.slugs, in: context)
                }
                .buttonStyle(ComicButtonStyle())
            }
        }
        .comicCard(tint: Theme.accent)
    }

    private var caloriesCard: some View {
        let weightKg = weights.last?.kg ?? 75
        let target = EnergyCalculator.target(profile.energyInput(weightKg: weightKg), goal: profile.goal)
        let macros = EnergyCalculator.macros(kcal: target.kcal, weightKg: weightKg, goal: profile.goal,
                                             bodyFatPercent: profile.bodyFatPercent)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Doel voor vandaag")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack {
                StatView(value: "\(Int(target.kcal.rounded()))", label: "kcal")
                StatView(value: "\(Int(macros.proteinG.rounded())) g", label: String(localized: "Eiwit"))
                StatView(value: "\(Int(macros.carbsG.rounded())) g", label: String(localized: "Koolh."))
                StatView(value: "\(Int(macros.fatG.rounded())) g", label: String(localized: "Vet"))
            }
        }
        .comicCard()
    }

    private var weightCard: some View {
        let trend = WeightTrend.ema(weights.map { WeightPoint(date: $0.date, kg: $0.kg) })
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Gewichtstrend")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Weeg in", systemImage: "plus.circle.fill") { showWeightSheet = true }
                    .font(.subheadline.weight(.semibold))
            }
            if profile.hideWeight {
                Text("Gewicht is verborgen. Je kunt wel gewoon blijven loggen.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if let last = trend.last {
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.units.weightText(last.kg))
                        .font(Theme.display(.title2))
                    if let rate = WeightTrend.weeklyRate(trend: trend) {
                        Text("\(rate >= 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(rate), digits: 2)) \(profile.units.weightUnit) per week")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if trend.count > 1 {
                    Chart(trend, id: \.date) { point in
                        LineMark(x: .value("Datum", point.date),
                                 y: .value("Trend", profile.units.displayWeight(point.kg)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.accent)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis(.hidden)
                    .frame(height: 70)
                    .accessibilityLabel("Grafiek van je gewichtstrend")
                }
            } else {
                Text("Nog geen wegingen.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .comicCard()
    }
}

struct PowerLevelCard: View {
    let snapshot: PowerLevelSnapshot?

    var body: some View {
        let total = snapshot?.total ?? 0
        let stage = Stage.stage(forPowerLevel: total)
        VStack(spacing: 6) {
            ZStack {
                AuraView(color: stage.auraColor)
                VStack(spacing: 0) {
                    Text("POWER LEVEL")
                        .font(.caption.weight(.heavy))
                        .tracking(2)
                    ScannerNumber(value: total)
                        .font(.system(size: 60, weight: .black, design: .rounded).italic())
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 170)
            Text(stage.title)
                .font(Theme.display(.title3))
                .foregroundStyle(stage.auraColor)
            if let next = stage.next {
                let span = Double(next.threshold - stage.threshold)
                EnergyBar(fraction: Double(total - stage.threshold) / span, color: stage.auraColor)
                Text("Nog \(next.threshold - total) tot \(next.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .comicCard()
        .accessibilityElement(children: .combine)
    }
}

struct LevelCard: View {
    let totalXP: Int
    let streak: Int

    var body: some View {
        let progress = LevelCurve.progress(totalXP: totalXP)
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Level \(progress.level)")
                    .font(Theme.display(.title3))
                EnergyBar(fraction: progress.fraction, color: Theme.energy)
                Text("\(progress.xpIntoLevel) / \(progress.xpForNextLevel) XP")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(streak > 0 ? Theme.accent : Color.secondary)
                Text("\(streak)")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                Text("dagen")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Streak: \(streak) dagen")
        }
        .comicCard()
    }
}

struct LogWeightSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights: [BodyWeightEntry]
    @State private var value = 0.0
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Gewicht (\(profile.units.weightUnit))") {
                    NumberField(value: $value).frame(width: 100)
                }
                DatePicker("Datum", selection: $date, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("Weging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") { save() }
                        .disabled(!(20...400).contains(profile.units.kg(fromDisplay: value)))
                }
            }
            .onAppear {
                if let last = weights.first, !profile.hideWeight {
                    value = (profile.units.displayWeight(last.kg) * 10).rounded() / 10
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        context.insert(BodyWeightEntry(date: date, kg: profile.units.kg(fromDisplay: value)))
        if Calendar.current.isDateInToday(date) {
            GameService.award(.weighIn, in: context)
        }
        GameService.refreshPowerLevel(in: context)
        Haptics.tap()
        dismiss()
    }
}
