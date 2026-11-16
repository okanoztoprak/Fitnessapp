import PowerCore
import SwiftData
import SwiftUI

@MainActor
@Observable
final class OnboardingModel {
    var step = 0
    var usesMetric = true
    var age = 30.0
    var sex = Sex.male
    var height = 178.0
    var weight = 78.0
    var bodyFat = 0.0
    var activity = ActivityLevel.moderate
    var goal = Goal.maintain
    var experience = Experience.beginner
    var daysPerWeek = 3
    var equipment = Equipment.gym
    var tone = MentorTone.hype
    var acceptedDisclaimer = false

    static let lastStep = 5

    var units: UnitFormatter { UnitFormatter(metric: usesMetric) }
    var weightKg: Double { units.kg(fromDisplay: weight) }
    var heightCm: Double { units.cm(fromDisplay: height) }

    var canContinue: Bool {
        switch step {
        case 0: acceptedDisclaimer
        case 1: (13...100).contains(Int(age)) && (100...250).contains(heightCm) && (30...350).contains(weightKg)
            && (bodyFat == 0 || (3...60).contains(bodyFat))
        default: true
        }
    }

    var plan: StarterPlan { .recommend(daysPerWeek: daysPerWeek) }

    var energyInput: EnergyInput {
        EnergyInput(weightKg: weightKg, heightCm: heightCm, age: Int(age), sex: sex,
                    bodyFatPercent: bodyFat > 0 ? bodyFat : nil, activity: activity)
    }

    var powerLevel: PowerLevelResult {
        PowerLevelCalculator.calculate(PowerLevelInput(
            bodyWeightKg: weightKg, sex: sex, experience: experience, plannedSessionsPerWeek: daysPerWeek))
    }

    /// Wissel van eenheden en reken de ingevulde waarden om.
    func setMetric(_ metric: Bool) {
        guard metric != usesMetric else { return }
        let kg = weightKg, cm = heightCm
        usesMetric = metric
        weight = (units.displayWeight(kg) * 10).rounded() / 10
        height = units.displayHeight(cm).rounded()
    }

    func finish(in context: ModelContext) {
        let profile = UserProfile()
        profile.birthDate = Calendar.current.date(byAdding: .year, value: -Int(age), to: Date()) ?? Date()
        profile.sex = sex
        profile.heightCm = heightCm
        profile.bodyFatPercent = bodyFat > 0 ? bodyFat : nil
        profile.activity = activity
        profile.goal = goal
        profile.experience = experience
        profile.trainingDaysPerWeek = daysPerWeek
        profile.equipment = equipment
        profile.usesMetric = usesMetric
        profile.mentorTone = tone
        context.insert(profile)
        context.insert(BodyWeightEntry(kg: weightKg))
        context.insert(PowerLevelSnapshot(result: powerLevel))
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var model = OnboardingModel()

    var body: some View {
        NavigationStack {
            Form {
                switch model.step {
                case 0: WelcomeStep(model: model)
                case 1: BodyStep(model: model)
                case 2: GoalStep(model: model)
                case 3: ScheduleStep(model: model)
                case 4: MentorStep(model: model)
                default: ResultStep(model: model)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("POWER UP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Terug") { model.step -= 1 }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    EnergyBar(fraction: Double(model.step + 1) / Double(OnboardingModel.lastStep + 1))
                        .animation(.snappy, value: model.step)
                    Button {
                        hideKeyboard()
                        if model.step == OnboardingModel.lastStep {
                            model.finish(in: context)
                        } else {
                            model.step += 1
                        }
                    } label: {
                        if model.step == OnboardingModel.lastStep {
                            Text("Begin je trainingsarc")
                        } else {
                            Text("Verder")
                        }
                    }
                    .buttonStyle(ComicButtonStyle())
                    .disabled(!model.canContinue)
                    .opacity(model.canContinue ? 1 : 0.5)
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

private struct WelcomeStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    AuraView(color: Theme.accent)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 72, weight: .black))
                        .foregroundStyle(Theme.energy)
                }
                .frame(height: 200)
                Text("Welkom bij POWER UP")
                    .font(Theme.display(.title))
                Text("Log je trainingen, gewicht en voeding, en zie je power level groeien.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
        Section("Goed om te weten") {
            Text("Deze app geeft geen medisch advies. Overleg bij twijfel, klachten of een medische aandoening met een arts voordat je je training of voeding aanpast.")
                .font(.callout)
            Toggle("Ik heb dit gelezen en begrepen", isOn: $model.acceptedDisclaimer)
        }
    }
}

private struct BodyStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Section("Over jou") {
            Picker("Eenheden", selection: Binding(get: { model.usesMetric }, set: { model.setMetric($0) })) {
                Text("kg / cm").tag(true)
                Text("lb / inch").tag(false)
            }
            .pickerStyle(.segmented)
            Picker("Geslacht", selection: $model.sex) {
                ForEach(Sex.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            LabeledContent("Leeftijd") {
                NumberField(value: $model.age, allowsDecimal: false).frame(width: 90)
            }
            LabeledContent("Lengte (\(model.units.heightUnit))") {
                NumberField(value: $model.height).frame(width: 90)
            }
            LabeledContent("Gewicht (\(model.units.weightUnit))") {
                NumberField(value: $model.weight).frame(width: 90)
            }
        }
        Section {
            LabeledContent("Vetpercentage (%)") {
                NumberField(value: $model.bodyFat, placeholder: "–").frame(width: 90)
            }
        } footer: {
            Text("Optioneel. Als je het weet, rekenen we nauwkeuriger met je vetvrije massa.")
        }
    }
}

private struct GoalStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Section("Je doel") {
            Picker("Doel", selection: $model.goal) {
                ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        Section {
            Picker("Activiteit", selection: $model.activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Dagelijkse activiteit")
        } footer: {
            Text("Je werk en dagelijks leven, zonder je trainingen.")
        }
        Section("Trainingservaring") {
            Picker("Ervaring", selection: $model.experience) {
                ForEach(Experience.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct ScheduleStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Section("Hoe vaak train je?") {
            Stepper("\(model.daysPerWeek) dagen per week", value: $model.daysPerWeek, in: 2...6)
        }
        Section("Waar train je?") {
            Picker("Apparatuur", selection: $model.equipment) {
                ForEach(Equipment.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
}

private struct MentorStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Section {
            Picker("Toon", selection: $model.tone) {
                ForEach(MentorTone.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.martial.arts")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Mentor.name).font(.headline)
                    Text(Mentor.line(.greeting, tone: model.tone))
                }
            }
        } header: {
            Text("Kies je mentor-toon")
        } footer: {
            Text("Je kunt dit later aanpassen in de instellingen.")
        }
    }
}

private struct ResultStep: View {
    let model: OnboardingModel

    var body: some View {
        let power = model.powerLevel
        let target = EnergyCalculator.target(model.energyInput, goal: model.goal)
        Section {
            VStack(spacing: 4) {
                ZStack {
                    AuraView(color: power.stage.auraColor)
                    ScannerNumber(value: power.total)
                        .font(.system(size: 64, weight: .black, design: .rounded).italic())
                }
                .frame(height: 190)
                Text("Je eerste power level")
                    .font(.headline)
                Text(power.stage.title)
                    .font(Theme.display(.title2))
                    .foregroundStyle(power.stage.auraColor)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
        Section("Je startplan") {
            LabeledContent("Programma", value: model.plan.title)
            LabeledContent("Dagen per week", value: "\(model.daysPerWeek)")
            LabeledContent("Caloriedoel", value: "\(Int(target.kcal.rounded())) kcal")
            if target.wasFloored {
                Label("Je doel is verhoogd naar je rustverbranding. Lager gaan we niet.", systemImage: "shield.fill")
                    .font(.footnote)
            }
        }
    }
}
