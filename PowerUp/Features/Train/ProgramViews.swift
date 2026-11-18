import PowerCore
import SwiftData
import SwiftUI

// MARK: - Programmakaart

/// Waar je staat in je blok, met de weken als tijdlijn.
struct ProgramCard: View {
    let status: ProgramStatus
    @State private var showDetail = false

    var body: some View {
        let program = status.program
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Tag(text: String(localized: "Programma"), filled: true)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProgramCoach.programName(program)).font(.title2.weight(.bold))
                    Text(status.position.isFinished ? String(localized: "Blok afgerond")
                         : ProgramCoach.weekLine(status.weekPlan))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(status.weekPlan.isDeload ? Theme.cool : Theme.accentText)
                }
                WeekTimeline(program: program, current: status.position.isFinished ? nil : status.weekPlan.week)
                if status.position.isFinished {
                    Text("Je hebt alle \(program.totalWeeks) weken afgerond. Start een nieuw blok; je gewichten gaan mee.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    HStack(spacing: 10) {
                        WeekDots(done: status.position.sessionInWeek, planned: program.daysPerWeek)
                        Text("\(status.position.sessionInWeek) van \(program.daysPerWeek) deze programmaweek")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(ProgramCoach.weekExplanation(status.weekPlan, goal: program.goal))
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(.primary)
            .card()
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showDetail) { ProgramDetailView(status: status) }
    }
}

/// Eén blokje per week; de deloadweek heeft een maantje.
struct WeekTimeline: View {
    let program: TrainingProgram
    let current: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(program.totalWeeks, 1), id: \.self) { week in
                let plan = Mesocycle.plan(week: week, totalWeeks: program.totalWeeks, goal: program.goal)
                let isPast = current.map { week < $0 } ?? true
                let isCurrent = week == current
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isCurrent ? Theme.accent : (isPast ? Theme.accentText.opacity(0.45) : Theme.raised))
                        if plan.isDeload {
                            Image(systemName: "moon.fill")
                                .font(.caption)
                                .foregroundStyle(isCurrent ? Theme.onAccent : Theme.cool)
                        }
                    }
                    .frame(height: 22)
                    Text("W\(week)")
                        .font(.caption.weight(isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current.map { "Week \($0) van \(program.totalWeeks)" } ?? String(localized: "Blok afgerond"))
    }
}

/// Uitnodiging om een programma te starten.
struct StartProgramCard: View {
    @State private var showBuilder = false
    @State private var paywall: ProFeature?
    let profile: UserProfile

    var body: some View {
        Button {
            if ProStore.shared.isPro { showBuilder = true } else { paywall = .programs }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 52, height: 52)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Start een programma").font(.headline)
                        if !ProStore.shared.isPro { Tag(text: String(localized: "Pro"), filled: true) }
                    }
                    Text("Een blok van 4 tot 6 weken dat elke week iets zwaarder wordt, met een deloadweek aan het eind.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .card()
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showBuilder) { ProgramBuilderSheet(profile: profile) }
        .paywall(for: $paywall)
    }
}

// MARK: - Samenstellen

struct ProgramBuilderSheet: View {
    @Bindable var profile: UserProfile
    var previous: TrainingProgram?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var programs: [TrainingProgram]
    @State private var goal: ProgramGoal
    @State private var days: Int
    @State private var weeks: Int
    @State private var plan: StarterPlan

    init(profile: UserProfile, previous: TrainingProgram? = nil) {
        self.profile = profile
        self.previous = previous
        let days = previous?.daysPerWeek ?? profile.trainingDaysPerWeek
        _goal = State(initialValue: previous?.goal ?? .hypertrophy)
        _days = State(initialValue: days)
        _weeks = State(initialValue: previous?.totalWeeks ?? 5)
        _plan = State(initialValue: previous?.plan ?? profile.preferredPlan ?? .recommend(daysPerWeek: days))
    }

    var body: some View {
        let templateDays = StarterTemplates.days(plan: plan, equipment: profile.equipment)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(previous == nil ? "Nieuw programma" : "Volgend blok").font(.largeTitle.weight(.bold))
                        Text("Elke week een stap zwaarder, en daarna een week om te herstellen. Zo blijf je vooruitgaan zonder vast te lopen.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 10) {
                        ForEach(ProgramGoal.allCases, id: \.self) { option in
                            choice(title: ProgramCoach.goalTitle(option), detail: ProgramCoach.goalDetail(option),
                                   symbol: option == .hypertrophy ? "figure.strengthtraining.traditional" : "scalemass.fill",
                                   selected: goal == option) { goal = option }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dagen per week").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        chips(values: Array(2...6), selected: days) { value in
                            days = value
                            plan = .recommend(daysPerWeek: value)
                        }
                        Text("Lengte van het blok").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.top, 4)
                        chips(values: Mesocycle.lengths, selected: weeks, suffix: String(localized: " wkn")) { weeks = $0 }
                        Picker("Schema", selection: $plan) {
                            ForEach(StarterPlan.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 4)
                    }
                    .card()
                    weekPreview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Je trainingsdagen").font(.headline)
                        ForEach(templateDays) { day in
                            let exercises = Coach.exercises(slugs: day.slugs, in: context)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.name).font(.subheadline.weight(.bold))
                                Text(exercises.map(\.name).joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .card()
                }
                .padding()
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button("Start programma") { start() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
            }
        }
    }

    private var weekPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zo loopt het blok").font(.headline)
            ForEach(1...weeks, id: \.self) { week in
                let plan = Mesocycle.plan(week: week, totalWeeks: weeks, goal: goal)
                HStack(spacing: 12) {
                    Text("W\(week)")
                        .font(Theme.number(.subheadline))
                        .frame(width: 40, height: 30)
                        .background(plan.isDeload ? Theme.cool.opacity(0.25) : Theme.raised,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(plan.isDeload ? String(localized: "Deload · minder sets, 90% gewicht")
                         : String(localized: "\(Mesocycle.sets(plan: plan)) sets per oefening · RIR \(plan.targetRIR)"))
                        .font(.subheadline)
                    Spacer()
                    // Inspanning als balk: hoe dichter bij falen, hoe voller.
                    ProgressBar(fraction: plan.isDeload ? 0.2 : Double(4 - plan.targetRIR) / 3,
                                color: plan.isDeload ? Theme.cool : Theme.accentText, height: 6)
                        .frame(width: 60)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private func choice(title: String, detail: String, symbol: String, selected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .foregroundStyle(selected ? Theme.onAccent : Theme.accentText)
                    .frame(width: 40, height: 40)
                    .background(selected ? Theme.accent : Theme.raised, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.accentText : Color.secondary.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .card(padding: 14)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(selected ? Theme.accentText : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chips(values: [Int], selected: Int, suffix: String = "",
                       action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isOn = value == selected
                Button {
                    action(value)
                    Haptics.tap()
                } label: {
                    Text("\(value)\(suffix)")
                        .font(Theme.number(.headline))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(isOn ? Theme.accent : Theme.raised,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func start() {
        for program in programs where program.isActive { program.endedAt = Date() }
        context.insert(TrainingProgram(goal: goal, plan: plan, equipment: profile.equipment,
                                       daysPerWeek: days, totalWeeks: weeks))
        profile.trainingDaysPerWeek = days
        profile.preferredPlan = plan
        profile.deloadUntil = nil
        context.saveOrLog()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Details

struct ProgramDetailView: View {
    let status: ProgramStatus
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var confirmStop = false
    @State private var showNext = false

    var body: some View {
        let program = status.program
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ProgramCoach.programName(program)).font(.largeTitle.weight(.bold))
                        Text("Gestart \(program.startedAt.formatted(date: .abbreviated, time: .omitted)) · \(program.daysPerWeek) dagen per week")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        WeekTimeline(program: program, current: status.position.isFinished ? nil : status.weekPlan.week)
                        ProgressBar(fraction: status.progress)
                        Text("\(status.completed) van \(program.daysPerWeek * program.totalWeeks) trainingen gedaan")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weken").font(.headline)
                        ForEach(1...program.totalWeeks, id: \.self) { week in
                            let plan = Mesocycle.plan(week: week, totalWeeks: program.totalWeeks, goal: program.goal)
                            HStack {
                                Text(ProgramCoach.weekLine(plan)).font(.subheadline.weight(week == status.weekPlan.week ? .bold : .regular))
                                Spacer()
                                if !plan.isDeload {
                                    Text("\(Mesocycle.sets(plan: plan)) sets").font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .card()
                    ForEach(status.days) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(day.name).font(.headline)
                                Spacer()
                                if day == status.nextDay { Tag(text: String(localized: "Aan de beurt"), filled: true) }
                            }
                            ForEach(Coach.exercises(slugs: day.slugs, in: context)) { exercise in
                                let range = Coach.repRange(for: exercise, goal: program.goal)
                                HStack {
                                    Text(exercise.name).font(.subheadline)
                                    Spacer()
                                    Text("\(Mesocycle.sets(plan: status.weekPlan)) × \(range.lowerBound)–\(range.upperBound)")
                                        .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .card()
                    }
                    if let profile = profiles.first {
                        Button("Nieuw blok met deze instellingen") { showNext = true }
                            .buttonStyle(SoftButtonStyle())
                            .sheet(isPresented: $showNext) {
                                ProgramBuilderSheet(profile: profile, previous: program)
                            }
                    }
                    Button("Stop programma", role: .destructive) { confirmStop = true }
                        .buttonStyle(SoftButtonStyle())
                        .foregroundStyle(Theme.bad)
                }
                .padding()
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
            }
            .confirmationDialog("Programma stoppen?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Stop programma", role: .destructive) {
                    program.endedAt = Date()
                    context.saveOrLog()
                    dismiss()
                }
            } message: {
                Text("Je trainingen blijven bewaard. Daarna train je weer vrij met je schema.")
            }
        }
    }
}

// MARK: - Volume

/// Harde sets per spiergroep deze week, tegen het streefbereik.
struct WeeklyVolumeCard: View {
    let volumes: [ProgramCoach.MuscleVolume]
    let onSelect: (MuscleGroup) -> Void
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Volume deze week").font(.headline)
                Spacer()
                Button("Uitleg", systemImage: "info.circle") { showInfo.toggle() }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            }
            if showInfo {
                Text("Harde sets per spiergroep sinds maandag; een oefening telt half mee voor de spieren die meehelpen. In het streefbereik groei je het best. Tik op een spiergroep voor een focus-training.")
                    .font(.caption).foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            ForEach(volumes) { volume in
                Button {
                    onSelect(volume.muscle)
                } label: {
                    VolumeRow(volume: volume)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
        .animation(.snappy, value: showInfo)
    }
}

private struct VolumeRow: View {
    let volume: ProgramCoach.MuscleVolume

    var body: some View {
        let scale = Double(volume.landmarks.mrv)
        let color = ProgramCoach.color(for: volume.status)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(volume.muscle.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(UnitFormatter.number(volume.sets, digits: 1)) / \(volume.target.lowerBound)–\(volume.target.upperBound)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.raised)
                    // Streefbereik als lichte band.
                    Capsule()
                        .fill(Theme.good.opacity(0.22))
                        .frame(width: width * Double(volume.target.upperBound - volume.target.lowerBound) / scale)
                        .offset(x: width * Double(volume.target.lowerBound) / scale)
                    Capsule().fill(color)
                        .frame(width: max(6, width * min(volume.sets, scale) / scale))
                }
            }
            .frame(height: 8)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(volume.muscle.title): \(UnitFormatter.number(volume.sets, digits: 1)) sets, doel \(volume.target.lowerBound) tot \(volume.target.upperBound)")
    }
}

// MARK: - Coach

/// Deload-advies, een lopende deloadweek en oefeningen die stilstaan.
struct CoachNotesCard: View {
    @Bindable var profile: UserProfile
    let advice: DeloadAdvice?
    let stalled: [Exercise]

    var body: some View {
        if profile.isDeloading || advice != nil || !stalled.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Coach").font(.headline)
                if let until = profile.deloadUntil, profile.isDeloading {
                    note(symbol: "moon.zzz.fill", tint: Theme.cool,
                         title: String(localized: "Deloadweek tot \(until.formatted(.dateTime.weekday(.wide)))"),
                         text: String(localized: "Je trainingen starten met minder sets en 90% van je gewicht.")) {
                        Button("Stop deload") { profile.deloadUntil = nil }
                            .font(.subheadline.weight(.semibold))
                    }
                } else if let advice {
                    note(symbol: "battery.25percent", tint: Theme.warn,
                         title: String(localized: "Tijd voor een deload"), text: ProgramCoach.adviceText(advice)) {
                        Button("Start deloadweek") {
                            profile.deloadUntil = Calendar.current.date(byAdding: .day, value: 7, to: Date())
                            Haptics.success()
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
                ForEach(stalled.prefix(3)) { exercise in
                    note(symbol: "chart.line.flattrend.xyaxis", tint: Theme.warn,
                         title: String(localized: "\(exercise.name) staat stil"),
                         text: String(localized: "Drie trainingen zonder vooruitgang. Probeer een ander rep-bereik, vervang de oefening tijdelijk of neem een deload.")) {
                        EmptyView()
                    }
                }
            }
            .card()
        }
    }

    private func note(symbol: String, tint: Color, title: String, text: String,
                      @ViewBuilder action: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                action()
            }
        }
    }
}
