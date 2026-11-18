import Charts
import PowerCore
import SwiftData
import SwiftUI

struct NutritionView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query(sort: \NutritionEntry.date) private var entries: [NutritionEntry]
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @State private var showQuickAdd = false
    @State private var showMacros = false
    @State private var showCheckIn = false
    @State private var paywall: ProFeature?
    @State private var syncing = false
    @State private var syncError: String?

    var body: some View {
        let plan = NutritionPlan(profile: profile, weights: weights, entries: entries)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TodayIntakeCard(plan: plan, hideCalories: profile.hideCalories)
                    actionRow
                    if !profile.healthSyncEnabled { HealthConnectCard(profile: profile) }
                    if !profile.hideCalories {
                        checkInCard(plan)
                        weekCard(plan)
                        expenditureCard(plan)
                        warnings(plan)
                    }
                    goalsCard(plan)
                    entriesCard
                    if profile.healthSyncEnabled { sourceCard }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .refreshable { await sync() }
            .screenBackground()
            .navigationTitle("Voeding")
            .brandToolbar()
            .sheet(isPresented: $showQuickAdd) { QuickAddSheet() }
            .sheet(isPresented: $showMacros) { MacroSettingsSheet(profile: profile, plan: plan) }
            .sheet(isPresented: $showCheckIn) { CheckInSheet(profile: profile, plan: plan) }
            .paywall(for: $paywall)
            .alert("Synchroniseren mislukt", isPresented: Binding(get: { syncError != nil }, set: { if !$0 { syncError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncError ?? "")
            }
        }
    }

    // MARK: Acties

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                showQuickAdd = true
            } label: {
                Label("Snel toevoegen", systemImage: "plus")
            }
            .buttonStyle(SoftButtonStyle())
            if profile.healthSyncEnabled {
                Button {
                    Task { await sync() }
                } label: {
                    if syncing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Synchroniseer", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(syncing)
            }
        }
    }

    private func sync() async {
        guard profile.healthSyncEnabled, !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            try await HealthSync.run(profile: profile, context: context)
            Haptics.tap()
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: Check-in

    @ViewBuilder
    private func checkInCard(_ plan: NutritionPlan) -> some View {
        let lastDate = checkIns.first?.date
        let remaining = WeeklyCheckIn.daysUntilDue(lastCheckIn: lastDate, firstLoggedDay: plan.firstLoggedDay, today: Date())
        if remaining == 0 {
            Button {
                if ProStore.shared.isPro { showCheckIn = true } else { paywall = .checkIn }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "checklist.checked")
                        .font(.title2)
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Theme.accent, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Wekelijkse check-in").font(.headline)
                        Text("Bekijk je week en je nieuwe caloriedoel.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .card()
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(Theme.accentText.opacity(0.6), lineWidth: 1.5)
                }
            }
            .buttonStyle(PressableStyle())
        } else if let remaining {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3).foregroundStyle(Theme.cool).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining == 1 ? String(localized: "Check-in morgen")
                         : String(localized: "Check-in over \(remaining) dagen"))
                        .font(.subheadline.weight(.semibold))
                    if let last = checkIns.first {
                        Text(last.accepted
                             ? String(localized: "Vorige keer: doel \(Int(last.proposedTargetKcal)) kcal")
                             : String(localized: "Vorige keer: doel ongewijzigd"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Log je eten een week lang; daarna stellen we je doel bij.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .card(padding: 14)
        }
    }

    // MARK: Week

    private func weekCard(_ plan: NutritionPlan) -> some View {
        let week = plan.lastWeek()
        let logged = week.filter { $0.kcal > 0 && $0.date < Calendar.current.startOfDay(for: Date()) }
        let average = logged.isEmpty ? nil : logged.reduce(0) { $0 + $1.kcal } / Double(logged.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Deze week").font(.headline)
                Spacer()
                if let average {
                    Text("Gem. \(Int(average.rounded())) kcal")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Chart {
                ForEach(week, id: \.date) { day in
                    BarMark(x: .value("Dag", day.date, unit: .day), y: .value("kcal", day.kcal))
                        .cornerRadius(5)
                        .foregroundStyle(barColor(day, target: plan.targetKcal))
                }
                RuleMark(y: .value("Doel", plan.targetKcal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Doel").font(.caption).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 150)
            .accessibilityLabel("Calorieën per dag deze week, met je doel als lijn")
        }
        .card()
    }

    private func barColor(_ day: DailyIntake, target: Double) -> Color {
        guard day.kcal > 0 else { return Theme.raised }
        let ratio = day.kcal / max(target, 1)
        if ratio > 1.1 { return Theme.warn }
        return ratio >= 0.9 ? Theme.accentText : Theme.cool
    }

    // MARK: Verbruik

    private func expenditureCard(_ plan: NutritionPlan) -> some View {
        let estimate = plan.expenditure
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Je verbruik").font(.headline)
                Spacer()
                Tag(text: estimate.confidence > 0 ? String(localized: "Adaptief") : String(localized: "Formule"),
                    color: estimate.confidence > 0 ? Theme.accent : Theme.Fill.cool, filled: true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CountUp(value: Int(estimate.kcal.rounded())).font(Theme.number(.largeTitle))
                Text("kcal per dag").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Zekerheid").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(estimate.loggedDays) van de laatste \(AdaptiveExpenditure.windowDays) dagen gelogd")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ProgressBar(fraction: estimate.confidence, color: Theme.accentText)
            }
            HStack {
                StatTile(value: "\(Int(plan.formula.bmr.rounded()))", label: String(localized: "Rustverbranding"),
                         symbol: "bed.double.fill", tint: Theme.violet)
                StatTile(value: "\(Int(plan.formula.tdee.rounded()))", label: String(localized: "Volgens formule"),
                         symbol: "function", tint: Theme.cool)
                if let rate = estimate.trendRatePerWeek {
                    StatTile(value: "\(rate >= 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(rate), digits: 2))",
                             label: String(localized: "\(profile.units.weightUnit) per week"),
                             symbol: "chart.line.downtrend.xyaxis", tint: Theme.warn)
                }
            }
            Text(explanation(estimate))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func explanation(_ estimate: ExpenditureEstimate) -> String {
        if estimate.confidence >= 1 {
            return String(localized: "Berekend uit wat je at en hoe je trendgewicht veranderde. Dat zegt meer dan een formule, omdat het je eigen stofwisseling meet.")
        }
        if estimate.confidence > 0 {
            return String(localized: "Een mix van de formule en je eigen data. Hoe meer dagen je logt en weegt, hoe meer je eigen data meetelt.")
        }
        return String(localized: "Nog een schatting met de formule. Log een week je eten en weeg je een paar keer; daarna rekent de app met je echte verbruik.")
    }

    @ViewBuilder
    private func warnings(_ plan: NutritionPlan) -> some View {
        if plan.isFloored {
            Label("Je doel staat op je rustverbranding. Lager gaan we niet.", systemImage: "shield.fill")
                .font(.footnote)
                .card(padding: 14)
        }
        if plan.exceedsSafeLossRate {
            Label("Dit tempo is meer dan 1% van je lichaamsgewicht per week. Dat is moeilijk vol te houden en kost spiermassa.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.warn)
                .card(padding: 14)
        }
    }

    // MARK: Doelen

    private func goalsCard(_ plan: NutritionPlan) -> some View {
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
            Divider()
            Button {
                showMacros = true
            } label: {
                HStack {
                    Text("Macroverdeling").foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(plan.macros.proteinG.rounded())) / \(Int(plan.macros.carbsG.rounded())) / \(Int(plan.macros.fatG.rounded())) g")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if plan.isFromCheckIn, !profile.hideCalories {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Caloriedoel uit check-in")
                        Text("\(Int(plan.targetKcal.rounded())) kcal · formule \(Int(plan.formula.kcal.rounded())) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Terugzetten") { profile.calorieTargetKcal = nil }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 10)
            }
        }
        .card(padding: 14)
    }

    // MARK: Vandaag gelogd

    @ViewBuilder
    private var entriesCard: some View {
        let start = Calendar.current.startOfDay(for: Date())
        let todayEntries = entries.filter { $0.date >= start }
        if !todayEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vandaag gelogd").font(.headline)
                ForEach(todayEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.isManual ? "hand.tap.fill" : "heart.fill")
                            .font(.footnote)
                            .foregroundStyle(entry.isManual ? Theme.accentText : Theme.bad)
                            .frame(width: 32, height: 32)
                            .background(Theme.raised, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.isManual ? (entry.note.isEmpty ? String(localized: "Snel toegevoegd") : entry.note)
                                 : String(localized: "Apple Health"))
                                .font(.subheadline.weight(.semibold))
                            Text("E \(Int(entry.proteinG)) · K \(Int(entry.carbsG)) · V \(Int(entry.fatG)) g")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !profile.hideCalories {
                            Text("\(Int(entry.kcal.rounded())) kcal").font(Theme.number(.subheadline))
                        }
                        if entry.isManual {
                            Button("Verwijder", systemImage: "trash", role: .destructive) {
                                context.delete(entry)
                            }
                            .labelStyle(.iconOnly)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Theme.onSignal)
                    .frame(width: 36, height: 36)
                    .background(Theme.bad, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health gekoppeld").font(.subheadline.weight(.semibold))
                    if let last = profile.lastHealthSync {
                        Text("Bijgewerkt \(last.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Ontkoppel") { profile.healthSyncEnabled = false }
                    .font(.footnote.weight(.semibold))
            }
            Text("Voeding uit MyFitnessPal komt binnen via Apple Health. Zet in MyFitnessPal onder Instellingen → Gekoppelde apps het delen van voeding met Apple Health aan.")
                .font(.caption).foregroundStyle(.secondary)
            #if DEBUG
            Button("Voorbeelddata in Apple Health zetten") {
                Task {
                    do {
                        try await HealthKitService.shared.writeSampleData()
                        await sync()
                    } catch {
                        syncError = error.localizedDescription
                    }
                }
            }
            .font(.caption.weight(.semibold))
            #endif
        }
        .card()
    }
}

// MARK: - Vandaag

/// Ring met wat je vandaag nog kunt eten, plus de voortgang per macro.
struct TodayIntakeCard: View {
    let plan: NutritionPlan
    let hideCalories: Bool
    var compact = false

    var body: some View {
        let eaten = plan.today
        let remaining = plan.targetKcal - eaten.kcal
        HStack(spacing: compact ? 16 : 20) {
            if !hideCalories {
                ZStack {
                    Ring(progress: eaten.kcal / max(plan.targetKcal, 1), lineWidth: compact ? 10 : 13,
                         color: remaining < -plan.targetKcal * 0.1 ? Theme.warn : Theme.accent)
                    VStack(spacing: -2) {
                        CountUp(value: Int(abs(remaining).rounded()))
                            .font(Theme.number(compact ? .title2 : .title))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(remaining >= 0 ? "kcal over" : "kcal te veel")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(compact ? 14 : 18)
                }
                .frame(width: compact ? 104 : 128, height: compact ? 104 : 128)
            }
            VStack(spacing: 10) {
                MacroProgress(label: String(localized: "Eiwit"), eaten: eaten.proteinG, target: plan.macros.proteinG, color: Theme.cool)
                MacroProgress(label: String(localized: "Koolh."), eaten: eaten.carbsG, target: plan.macros.carbsG, color: Theme.accent)
                MacroProgress(label: String(localized: "Vet"), eaten: eaten.fatG, target: plan.macros.fatG, color: Theme.warn)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct MacroProgress: View {
    let label: String
    let eaten: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(eaten.rounded())) / \(Int(target.rounded())) g")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressBar(fraction: eaten / max(target, 1), color: color, height: 6)
        }
    }
}

// MARK: - Koppelen

struct HealthConnectCard: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @State private var working = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.onSignal)
                    .frame(width: 44, height: 44)
                    .background(Theme.bad, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Koppel Apple Health").font(.headline)
                    Text("Voor MyFitnessPal, je weegschaal, je slaap en je stappen")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text("Wat je in MyFitnessPal logt, komt via Apple Health automatisch hier binnen. Met je gewicht erbij berekent de app je echte verbruik.")
                .font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await connect() }
            } label: {
                if working { ProgressView() } else { Text("Koppel") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || !HealthKitService.shared.isAvailable)
            if let error {
                Text(error).font(.caption).foregroundStyle(Theme.bad)
            }
        }
        .card()
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

// MARK: - Snel toevoegen

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var kcal = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var date = Date()

    /// Calorieën uit de macro's, als die zijn ingevuld.
    private var macroKcal: Double { protein * 4 + carbs * 4 + fat * 9 }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        TextField("Omschrijving (optioneel)", text: $note)
                        // De placeholder toont wat uit de macro's volgt; zo verspringt het formulier niet tijdens het typen.
                        LabeledContent("Calorieën (kcal)") {
                            NumberField(value: $kcal, placeholder: macroKcal > 0 ? "\(Int(macroKcal.rounded()))" : "0",
                                        allowsDecimal: false)
                                .frame(width: 100)
                        }
                    } footer: {
                        Text("Laat calorieën leeg om ze uit je macro's te berekenen.")
                    }
                    Section("Macro's") {
                        row(String(localized: "Eiwit (g)"), value: $protein)
                        row(String(localized: "Koolhydraten (g)"), value: $carbs)
                        row(String(localized: "Vet (g)"), value: $fat)
                    }
                    DatePicker("Dag", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Snel toevoegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") { save() }.disabled(kcal <= 0 && macroKcal <= 0)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func row(_ label: String, value: Binding<Double>, decimal: Bool = true) -> some View {
        LabeledContent(label) {
            NumberField(value: value, allowsDecimal: decimal).frame(width: 100)
        }
    }

    private func save() {
        context.insert(NutritionEntry(date: date, kcal: kcal > 0 ? kcal : macroKcal, proteinG: protein,
                                      carbsG: carbs, fatG: fat, note: note.trimmingCharacters(in: .whitespaces)))
        Haptics.tap()
        dismiss()
    }
}

// MARK: - Macro's

struct MacroSettingsSheet: View {
    @Bindable var profile: UserProfile
    let plan: NutritionPlan
    @Environment(\.dismiss) private var dismiss
    @State private var proteinPerKg: Double
    @State private var fatPercent: Double

    init(profile: UserProfile, plan: NutritionPlan) {
        self.profile = profile
        self.plan = plan
        _proteinPerKg = State(initialValue: profile.proteinPerKg ?? EnergyCalculator.defaultProteinPerKg(goal: profile.goal))
        _fatPercent = State(initialValue: (profile.fatShare * 100).rounded())
    }

    var body: some View {
        let preview = EnergyCalculator.macros(kcal: plan.targetKcal, weightKg: plan.weightKg, goal: profile.goal,
                                              proteinPerKg: proteinPerKg, fatShare: fatPercent / 100)
        NavigationStack {
            Form {
                Group {
                    Section {
                        MacroBar(macros: preview)
                            .padding(.vertical, 6)
                    }
                    Section {
                        VStack(alignment: .leading) {
                            LabeledContent("Eiwit", value: "\(UnitFormatter.number(proteinPerKg, digits: 1)) g per kg")
                            Slider(value: $proteinPerKg, in: 1.2...3.0, step: 0.1)
                                .accessibilityLabel("Eiwit per kilo lichaamsgewicht")
                        }
                        VStack(alignment: .leading) {
                            LabeledContent("Vet", value: String(localized: "\(Int(fatPercent))% van je calorieën"))
                            Slider(value: $fatPercent, in: 20...40, step: 1)
                                .accessibilityLabel("Vetpercentage van je calorieën")
                        }
                    } footer: {
                        Text("Koolhydraten vullen de rest aan. 1,6 tot 2,2 g eiwit per kg helpt spiermassa te behouden en op te bouwen; bij een cut is meer zinvol.")
                    }
                    Section {
                        Button("Standaard herstellen") {
                            proteinPerKg = EnergyCalculator.defaultProteinPerKg(goal: profile.goal)
                            fatPercent = 25
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Macroverdeling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        let standard = EnergyCalculator.defaultProteinPerKg(goal: profile.goal)
                        profile.proteinPerKg = abs(proteinPerKg - standard) < 0.05 ? nil : proteinPerKg
                        profile.fatShare = fatPercent / 100
                        dismiss()
                    }
                }
            }
        }
    }
}
