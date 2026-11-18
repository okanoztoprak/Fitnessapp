import Charts
import PowerCore
import SwiftData
import SwiftUI

struct TodayView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]
    @Query(sort: \NutritionEntry.date) private var nutrition: [NutritionEntry]
    @Query private var programs: [TrainingProgram]
    @State private var showWeightSheet = false
    @State private var celebration: String?

    private var workouts: [Workout] {
        allWorkouts.filter { $0.persistentModelID != router.discardedWorkoutID }
    }
    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }
    private var active: Workout? { workouts.first { $0.endedAt == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    MotivationQuery(profile: profile) { data in
                        if let week = data.pendingRecapWeek {
                            RecapBanner(data: data, weekStart: week)
                        }
                    }
                    StepsCard(profile: profile, weekStreak: Insights.weekStreak(finished: finished),
                              workoutCount: finished.count)
                    if let active {
                        ActiveWorkoutCard(workout: active)
                    } else {
                        let status = ProgramStatus.active(programs).map { ProgramStatus(program: $0, finished: finished) }
                        let recommendation = Coach.recommendation(profile: profile, finished: finished, program: status)
                        NextWorkoutCard(recommendation: recommendation, profile: profile)
                            .task(id: finished.count) { publishToWidgets(recommendation) }
                        quickActions
                    }
                    MotivationQuery(profile: profile) { data in
                        ChallengesCard(data: data)
                            .task(id: data.finished.count + data.records.count + data.weights.count + data.nutrition.count) {
                                let done = ChallengeTracker.newlyCompleted(data: data, in: context)
                                if let first = done.first {
                                    Haptics.success()
                                    withAnimation(.spring(duration: 0.4)) {
                                        celebration = MotivationText.title(first.kind, target: first.target, period: first.period)
                                    }
                                }
                            }
                    }
                    weightCard
                    nutritionCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWeightSheet) { LogWeightSheet(profile: profile) }
            .overlay(alignment: .top) {
                if let celebration {
                    RecordToast(title: String(localized: "Uitdaging voltooid"), detail: celebration)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.celebration = nil } }
                }
            }
            .overlay {
                if celebration != nil { ConfettiView().id(celebration) }
            }
            .task(id: celebration) {
                guard celebration != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { withAnimation { celebration = nil } }
            }
        }
    }

    /// Volgende training en reeks voor de widgets op het beginscherm.
    private func publishToWidgets(_ recommendation: Coach.Recommendation) {
        let done = recommendation.advice.sessionsThisWeek
        let detail = recommendation.isRest
            ? recommendation.day.map { String(localized: "Daarna: \($0.name)") }
            : String(localized: "\(done) van \(recommendation.plannedPerWeek) trainingen deze week")
        WidgetBridge.updateToday(nextWorkout: Coach.headline(recommendation), detail: detail,
                                 weekStreak: Insights.weekStreak(finished: finished),
                                 trainedToday: finished.contains { Calendar.current.isDateInToday($0.startedAt) })
    }

    // MARK: Kop

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(greeting)
                .font(.largeTitle.weight(.bold))
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: String(localized: "Goedemorgen")
        case 12..<18: String(localized: "Goedemiddag")
        default: String(localized: "Goedenavond")
        }
    }

    // MARK: Snelle acties

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickAction(title: String(localized: "Slimme training"), symbol: "sparkles") {
                var proposal = Coach.smartProposal(profile: profile, finished: finished, in: context)
                proposal.training = ProgramCoach.freeContext(profile: profile)
                router.proposal = proposal
            }
            QuickAction(title: String(localized: "Lege training"), symbol: "plus") {
                router.presentedWorkout = WorkoutFactory.start(name: String(localized: "Vrije training"), in: context,
                                                               training: ProgramCoach.freeContext(profile: profile))
            }
            QuickAction(title: String(localized: "Weeg in"), symbol: "scalemass.fill") {
                showWeightSheet = true
            }
        }
    }

    // MARK: Gewicht

    private var weightCard: some View {
        let trend = WeightTrend.ema(AdaptiveExpenditure.withoutOutliers(weights.map { WeightPoint(date: $0.date, kg: $0.kg) }))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Gewichtstrend")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Weeg in", systemImage: "plus") { showWeightSheet = true }
                    .font(.subheadline.weight(.semibold))
            }
            if profile.hideWeight {
                Text("Gewicht is verborgen. Je kunt wel gewoon blijven loggen.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if let last = trend.last {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.units.weightText(last.kg))
                        .font(Theme.number(.title))
                    if let rate = WeightTrend.weeklyRate(trend: trend) {
                        Text("\(rate >= 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(rate), digits: 2)) \(profile.units.weightUnit) per week")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if trend.count > 1 {
                    Chart(trend, id: \.date) { point in
                        AreaMark(x: .value("Datum", point.date),
                                 y: .value("Trend", profile.units.displayWeight(point.kg)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [Theme.accentText.opacity(0.3), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Datum", point.date),
                                 y: .value("Trend", profile.units.displayWeight(point.kg)))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(Theme.accentText)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 64)
                    .accessibilityLabel("Grafiek van je gewichtstrend")
                } else {
                    Text("Weeg je een paar keer per week; de trend filtert dagelijkse schommelingen eruit.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("Nog geen wegingen.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: Voeding

    private var nutritionCard: some View {
        let plan = NutritionPlan(profile: profile, weights: weights, entries: nutrition)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Voeding vandaag").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !profile.hideCalories {
                    Text("Doel \(Int(plan.targetKcal.rounded())) kcal")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            TodayIntakeCard(plan: plan, hideCalories: profile.hideCalories, compact: true)
        }
    }
}

struct QuickAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(height: 24)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Verdeling van eiwit, koolhydraten en vet als één balk met legenda.
struct MacroBar: View {
    let macros: MacroTarget

    private var parts: [(label: String, grams: Double, kcal: Double, color: Color)] {
        [
            (String(localized: "Eiwit"), macros.proteinG, macros.proteinG * 4, Theme.cool),
            (String(localized: "Koolh."), macros.carbsG, macros.carbsG * 4, Theme.accent),
            (String(localized: "Vet"), macros.fatG, macros.fatG * 9, Theme.warn),
        ]
    }

    var body: some View {
        let total = max(parts.reduce(0) { $0 + $1.kcal }, 1)
        VStack(spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(parts, id: \.label) { part in
                        Capsule().fill(part.color)
                            .frame(width: max(4, (proxy.size.width - 6) * part.kcal / total))
                    }
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            HStack {
                ForEach(parts, id: \.label) { part in
                    HStack(spacing: 6) {
                        Circle().fill(part.color).frame(width: 8, height: 8).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(part.grams.rounded())) g")
                                .font(Theme.number(.subheadline))
                            Text(part.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
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
        Haptics.tap()
        dismiss()
    }
}
