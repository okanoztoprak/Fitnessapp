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
    @State private var showWeightSheet = false
    @State private var showReadiness = false
    @Environment(\.dynamicTypeSize) private var typeSize

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
                    readinessCard
                    if let active {
                        ActiveWorkoutCard(workout: active)
                    } else {
                        NextWorkoutCard(recommendation: Coach.recommendation(profile: profile, finished: finished),
                                        profile: profile)
                        quickActions
                    }
                    weightCard
                    if !profile.hideCalories { nutritionCard }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWeightSheet) { LogWeightSheet(profile: profile) }
            .sheet(isPresented: $showReadiness) { ReadinessSheet(finished: finished) }
        }
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

    // MARK: Gereedheid

    private var readinessCard: some View {
        let readiness = Coach.readiness(finished: finished)
        let hasHistory = !finished.isEmpty
        let color = Coach.color(for: readiness.band)
        let load = TrainingLoad.status(ratio: Insights.loadRatio(finished: finished))
        let streak = Insights.weekStreak(finished: finished)
        return Button {
            showReadiness = true
        } label: {
            let stacked = typeSize.isAccessibilitySize
            let mainLayout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(spacing: 18))
            let statsLayout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 0))
            VStack(spacing: 18) {
                mainLayout {
                    ZStack {
                        Ring(progress: Double(readiness.score) / 100, lineWidth: 13, color: color)
                        VStack(spacing: -2) {
                            CountUp(value: readiness.score)
                                .font(Theme.number(.largeTitle))
                            Text("van 100").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 124, height: 124)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Gereedheid")
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        Text(Coach.title(for: readiness, hasHistory: hasHistory,
                                         trainedToday: Coach.trainedToday(finished)))
                            .font(.title3.weight(.bold))
                        Text(Coach.advice(for: readiness, hasHistory: hasHistory, finished: finished))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                statsLayout {
                    miniStat(value: "\(streak)", label: String(localized: "Weken op rij"), symbol: "flame.fill",
                             tint: streak > 0 ? Theme.warn : .secondary)
                    if !stacked { Divider().frame(height: 34) }
                    miniStat(value: Coach.loadText(load), label: String(localized: "Belasting"),
                             symbol: "waveform.path.ecg", tint: load == .high ? Theme.bad : Theme.cool)
                    if !stacked { Divider().frame(height: 34) }
                    miniStat(value: "\(finished.count)", label: String(localized: "Trainingen"),
                             symbol: "checkmark.circle.fill", tint: Theme.accentText)
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toont het herstel per spiergroep")
    }

    private func miniStat(value: String, label: String, symbol: String, tint: Color) -> some View {
        let stacked = typeSize.isAccessibilitySize
        return VStack(alignment: stacked ? .leading : .center, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.caption).foregroundStyle(tint).accessibilityHidden(true)
                Text(value)
                    .font(Theme.number(.headline))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: stacked ? .leading : .center)
    }

    // MARK: Snelle acties

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickAction(title: String(localized: "Slimme training"), symbol: "sparkles") {
                router.proposal = Coach.smartProposal(profile: profile, finished: finished, in: context)
            }
            QuickAction(title: String(localized: "Lege training"), symbol: "plus") {
                router.presentedWorkout = WorkoutFactory.start(name: String(localized: "Vrije training"), in: context)
            }
            QuickAction(title: String(localized: "Weeg in"), symbol: "scalemass.fill") {
                showWeightSheet = true
            }
        }
    }

    // MARK: Gewicht

    private var weightCard: some View {
        let trend = WeightTrend.ema(weights.map { WeightPoint(date: $0.date, kg: $0.kg) })
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
        let weightKg = weights.last?.kg ?? 75
        let target = EnergyCalculator.target(profile.energyInput(weightKg: weightKg), goal: profile.goal)
        let macros = EnergyCalculator.macros(kcal: target.kcal, weightKg: weightKg, goal: profile.goal,
                                             bodyFatPercent: profile.bodyFatPercent)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Dagdoel")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(target.kcal.rounded()))")
                    .font(Theme.number(.title))
                Text("kcal").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(profile.goal.title).font(.footnote).foregroundStyle(.secondary)
            }
            MacroBar(macros: macros)
        }
        .card()
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

/// Uitleg bij de gereedheidsscore met het herstel per spiergroep.
struct ReadinessSheet: View {
    let finished: [Workout]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let statuses = Coach.muscleStatuses(finished: finished).sorted { $0.recovery < $1.recovery }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Gereedheid schat hoe hersteld je bent op basis van je gelogde trainingen: het herstel per spiergroep en hoe zwaar deze week is vergeleken met je eigen gemiddelde. Slaap en hartslag uit Apple Health tellen later mee.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 14) {
                        ForEach(statuses) { status in
                            VStack(spacing: 6) {
                                HStack {
                                    Text(status.muscle.title).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(Int((status.recovery * 100).rounded()))%")
                                        .font(Theme.number(.subheadline))
                                        .monospacedDigit()
                                }
                                ProgressBar(fraction: status.recovery, color: Coach.color(forRecovery: status.recovery))
                                HStack {
                                    Text(Coach.statusText(status))
                                    Spacer()
                                    if status.lastTrained != nil { Text(Coach.relativeDay(status.lastTrained)) }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .card()
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Gereedheid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
            }
        }
        .presentationDetents([.large])
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
