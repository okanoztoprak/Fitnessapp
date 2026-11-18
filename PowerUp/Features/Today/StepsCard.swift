import Charts
import PowerCore
import SwiftData
import SwiftUI

/// Stappen van vandaag tegenover je doel, met de afgelopen week eronder. De stappen komen uit Apple Health.
struct StepsCard: View {
    let profile: UserProfile
    let weekStreak: Int
    let workoutCount: Int
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var samples: [DailySteps] = []
    @State private var loaded = false
    @State private var showGoal = false
    @State private var working = false
    @State private var error: String?

    private var week: StepWeek { StepGoal.week(samples, goal: profile.stepGoal, today: Date()) }

    var body: some View {
        Group {
            if profile.healthSyncEnabled {
                connected
            } else {
                connectPrompt
            }
        }
        .task(id: profile.healthSyncEnabled && scenePhase == .active) {
            guard profile.healthSyncEnabled, scenePhase == .active else { return }
            // Stappen lopen door terwijl de app open is; elke minuut bijwerken is ruim genoeg.
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .sheet(isPresented: $showGoal) { StepGoalSheet(profile: profile) }
        .onChange(of: profile.stepGoal) { _, goal in WidgetBridge.updateGoal(goal) }
    }

    // MARK: Gekoppeld

    private var connected: some View {
        let week = week
        let stacked = typeSize.isAccessibilitySize
        let mainLayout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 18))
        let statsLayout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 0))
        return Button {
            showGoal = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                mainLayout {
                    ring(week)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Stappen")
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        Text(title(week))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(detail(week))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if week.hasData {
                    chart(week)
                } else if loaded {
                    noDataHint
                }
                statsLayout {
                    stat(value: "\(week.daysHit)/7", label: String(localized: "Doel gehaald"),
                         symbol: "checkmark.circle.fill", tint: Theme.accentText)
                    if !stacked { Divider().frame(height: 34) }
                    stat(value: "\(weekStreak)", label: String(localized: "Weken op rij"), symbol: "flame.fill",
                         tint: weekStreak > 0 ? Theme.warn : .secondary)
                    if !stacked { Divider().frame(height: 34) }
                    if let sleep = profile.sleepHoursToday {
                        stat(value: String(localized: "\(UnitFormatter.number(sleep, digits: 1)) u"), label: String(localized: "Slaap"),
                             symbol: "bed.double.fill", tint: sleep < 7 ? Theme.warn : Theme.violet)
                    } else {
                        stat(value: "\(workoutCount)", label: String(localized: "Trainingen"),
                             symbol: "dumbbell.fill", tint: Theme.accentText)
                    }
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Pas je stappendoel aan")
    }

    private func ring(_ week: StepWeek) -> some View {
        ZStack {
            Ring(progress: week.progress, lineWidth: 13, color: week.goalReached ? Theme.good : Theme.accentText)
            VStack(spacing: -1) {
                if week.goalReached {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.good)
                        .accessibilityHidden(true)
                }
                CountUp(value: week.today)
                    .font(Theme.number(.title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("van \(profile.stepGoal.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 22)
        }
        // Bij grote tekst staat de ring op een eigen regel en mag hij groeien.
        .frame(width: typeSize.isAccessibilitySize ? 168 : 124, height: typeSize.isAccessibilitySize ? 168 : 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(week.today.formatted()) van \(profile.stepGoal.formatted()) stappen"))
    }

    private func title(_ week: StepWeek) -> String {
        if !week.hasData { return loaded ? String(localized: "Nog geen stappen") : String(localized: "Stappen ophalen") }
        if week.goalReached { return String(localized: "Doel gehaald") }
        return String(localized: "Nog \(week.remaining.formatted()) stappen")
    }

    private func detail(_ week: StepWeek) -> String {
        if week.goalReached {
            let over = week.today - week.goal
            return over > 0 ? String(localized: "\(over.formatted()) boven je doel. Lekker bezig.")
                : String(localized: "Precies je doel. Lekker bezig.")
        }
        if week.streak >= 2 {
            return String(localized: "\(week.streak) dagen op rij gehaald. Houd de reeks vast.")
        }
        if let average = week.average {
            return String(localized: "Gemiddeld \(average.formatted()) per dag de afgelopen week.")
        }
        return String(localized: "Je doel is \(week.goal.formatted()) stappen per dag.")
    }

    private func chart(_ week: StepWeek) -> some View {
        let top = Double(max(week.goal, week.days.map(\.count).max() ?? 0)) * 1.08
        let today = week.days.last?.date
        return Chart {
            ForEach(week.days, id: \.date) { day in
                BarMark(x: .value("Dag", day.date, unit: .day), y: .value("Stappen", day.count), width: .ratio(0.55))
                    .foregroundStyle(day.count >= week.goal ? Theme.accentText
                                     : (day.date == today ? Theme.cool : Color.secondary.opacity(0.35)))
                    .cornerRadius(4)
            }
            RuleMark(y: .value("Doel", week.goal))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .chartYScale(domain: 0...top)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .frame(height: 72)
        .accessibilityLabel("Stappen per dag, afgelopen week")
    }

    private var noDataHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Geen stappen gevonden. Controleer in de Gezondheid-app of POWER UP stappen mag lezen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            #if DEBUG
            Button("Voorbeeldstappen in Apple Health zetten") {
                Task {
                    try? await HealthKitService.shared.writeSampleSteps()
                    await load()
                }
            }
            .font(.caption.weight(.semibold))
            #endif
        }
    }

    private func stat(value: String, label: String, symbol: String, tint: Color) -> some View {
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
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: stacked ? .leading : .center)
    }

    // MARK: Niet gekoppeld

    private var connectPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(Theme.onSignal)
                    .frame(width: 36, height: 36)
                    .background(Theme.cool, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stappen").font(.headline)
                    Text("Doel: \(profile.stepGoal.formatted()) per dag")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Doel") { showGoal = true }
                    .font(.footnote.weight(.semibold))
            }
            Text("Koppel Apple Health om je stappen van vandaag en de afgelopen week hier te zien.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await connect() }
            } label: {
                if working { ProgressView() } else { Text("Koppel Apple Health") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || !HealthKitService.shared.isAvailable)
            if let error {
                Text(error).font(.caption).foregroundStyle(Theme.bad)
            }
        }
        .card()
    }

    // MARK: Ophalen

    private func load() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        do {
            try await HealthKitService.shared.requestAccessIfNeeded()
            samples = try await HealthKitService.shared.dailySteps(from: start, to: end)
            WidgetBridge.updateSteps(week.today, goal: profile.stepGoal)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func connect() async {
        working = true
        defer { working = false }
        do {
            try await HealthKitService.shared.requestAccess()
            profile.healthSyncEnabled = true
            try await HealthSync.run(profile: profile, context: context)
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Stappendoel kiezen, met een korte uitleg waar het getal vandaan komt.
struct StepGoalSheet: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    private let presets = [6_000, 8_000, 10_000, 12_000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 2) {
                        Text(profile.stepGoal, format: .number)
                            .font(Theme.number(.largeTitle))
                            .contentTransition(.numericText(value: Double(profile.stepGoal)))
                        Text("stappen per dag").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    HStack(spacing: 16) {
                        adjustButton(symbol: "minus", label: String(localized: "Minder"), delta: -StepGoal.step)
                        adjustButton(symbol: "plus", label: String(localized: "Meer"), delta: StepGoal.step)
                    }
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            let isOn = profile.stepGoal == preset
                            Button {
                                withAnimation(.snappy) { profile.stepGoal = preset }
                                Haptics.tap()
                            } label: {
                                Text(preset.formatted())
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(isOn ? Theme.accent : Theme.raised, in: Capsule())
                                    .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                    Text("In onderzoek vlakt de gezondheidswinst bij volwassenen af rond 8.000 tot 10.000 stappen per dag, bij 60-plussers rond 6.000 tot 8.000. Kies een doel dat je op de meeste dagen haalt; verhogen kan altijd.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .card()
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Stappendoel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func adjustButton(symbol: String, label: String, delta: Int) -> some View {
        Button {
            withAnimation(.snappy) { profile.stepGoal = StepGoal.clamp(profile.stepGoal + delta) }
            Haptics.tap()
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 56, height: 56)
                .background(Theme.raised, in: Circle())
                .foregroundStyle(.primary)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .disabled(delta < 0 ? profile.stepGoal <= StepGoal.range.lowerBound
                  : profile.stepGoal >= StepGoal.range.upperBound)
    }
}
