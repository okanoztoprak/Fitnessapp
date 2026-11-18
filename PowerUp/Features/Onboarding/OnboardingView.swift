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
    var daysPerWeek = 3
    var equipment = Equipment.gym
    var acceptedDisclaimer = false

    static let lastStep = 4

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
        profile.trainingDaysPerWeek = daysPerWeek
        profile.equipment = equipment
        profile.usesMetric = usesMetric
        context.insert(profile)
        context.insert(BodyWeightEntry(kg: weightKg))
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var model = OnboardingModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    model.step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .background(Theme.card, in: Circle())
                }
                .foregroundStyle(.primary)
                .opacity(model.step > 0 ? 1 : 0)
                .disabled(model.step == 0)
                .accessibilityLabel("Terug")
                HStack(spacing: 5) {
                    ForEach(0...OnboardingModel.lastStep, id: \.self) { index in
                        Capsule()
                            .fill(index <= model.step ? Theme.accentText : Color.primary.opacity(0.15))
                            .frame(height: 5)
                    }
                }
                .animation(.snappy, value: model.step)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Stap \(model.step + 1) van \(OnboardingModel.lastStep + 1)")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch model.step {
                    case 0: WelcomeStep(model: model)
                    case 1: BodyStep(model: model)
                    case 2: GoalStep(model: model)
                    case 3: ScheduleStep(model: model)
                    default: SummaryStep(model: model)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                hideKeyboard()
                if model.step == OnboardingModel.lastStep {
                    model.finish(in: context)
                } else {
                    model.step += 1
                }
            } label: {
                Text(model.step == OnboardingModel.lastStep ? "Aan de slag" : "Verder")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.canContinue)
            .padding()
        }
        .screenBackground()
    }
}

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.weight(.bold))
            Text(subtitle).font(.body).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct WelcomeStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        ZStack {
            Ring(progress: 0.82, lineWidth: 16, color: Theme.accent)
            Ring(progress: 0.64, lineWidth: 16, color: Theme.cool).padding(22)
            Ring(progress: 0.46, lineWidth: 16, color: Theme.violet).padding(44)
        }
        .frame(width: 190, height: 190)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)

        StepTitle(title: String(localized: "Train slimmer."),
                  subtitle: String(localized: "POWER UP volgt je herstel, stelt je volgende training voor en laat zien dat je sterker wordt."))

        VStack(alignment: .leading, spacing: 16) {
            feature("gauge.with.needle.fill", String(localized: "Elke dag een gereedheidsscore"),
                    String(localized: "Weet of je vol gas kunt of beter herstelt."))
            feature("sparkles", String(localized: "Trainingen die zich aanpassen"),
                    String(localized: "Een doel per oefening en workouts op basis van je herstel."))
            feature("chart.xyaxis.line", String(localized: "Voortgang die je ziet"),
                    String(localized: "Krachtniveau, records, volume en je gewichtstrend."))
        }
        .card()

        VStack(alignment: .leading, spacing: 12) {
            Text("Deze app geeft geen medisch advies. Overleg bij twijfel, klachten of een medische aandoening met een arts voordat je je training of voeding aanpast.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle("Ik heb dit gelezen en begrepen", isOn: $model.acceptedDisclaimer)
                .font(.subheadline.weight(.semibold))
                .tint(Theme.good)
        }
        .card()
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accentText)
                .frame(width: 38, height: 38)
                .background(Theme.raised, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BodyStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        StepTitle(title: String(localized: "Over jou"),
                  subtitle: String(localized: "Hiermee berekenen we je energieverbruik en krachtniveau."))
        VStack(spacing: 14) {
            Picker("Eenheden", selection: Binding(get: { model.usesMetric }, set: { model.setMetric($0) })) {
                Text("kg / cm").tag(true)
                Text("lb / inch").tag(false)
            }
            .pickerStyle(.segmented)
            Picker("Geslacht", selection: $model.sex) {
                ForEach(Sex.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .card()
        VStack(spacing: 0) {
            row(String(localized: "Leeftijd")) { NumberField(value: $model.age, allowsDecimal: false) }
            Divider()
            row(String(localized: "Lengte (\(model.units.heightUnit))")) { NumberField(value: $model.height) }
            Divider()
            row(String(localized: "Gewicht (\(model.units.weightUnit))")) { NumberField(value: $model.weight) }
            Divider()
            row(String(localized: "Vetpercentage (%)")) { NumberField(value: $model.bodyFat, placeholder: "–") }
        }
        .card(padding: 16)
        Text("Vetpercentage is optioneel. Als je het weet, rekenen we nauwkeuriger met je vetvrije massa.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func row(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        HStack {
            Text(label)
            Spacer()
            field()
                .font(Theme.number(.body))
                .padding(.vertical, 8)
                .frame(width: 96)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(label)
        }
        .padding(.vertical, 8)
    }
}

/// Grote aantikbare keuze met icoon, titel en toelichting.
private struct OptionTile: View {
    let symbol: String
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.accentText)
                    .frame(width: 40, height: 40)
                    .background(selected ? Theme.accent : Theme.raised, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
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
}

private struct GoalStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        StepTitle(title: String(localized: "Wat is je doel?"),
                  subtitle: String(localized: "Je kunt dit later altijd aanpassen."))
        ForEach(Goal.allCases, id: \.self) { goal in
            OptionTile(symbol: symbol(goal), title: goal.title, detail: detail(goal), selected: model.goal == goal) {
                model.goal = goal
                Haptics.tap()
            }
        }
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dagelijkse activiteit").font(.body.weight(.semibold))
                Text("Je werk en dagelijks leven, zonder je trainingen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Activiteit", selection: $model.activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
        }
        .card(padding: 14)
    }

    private func symbol(_ goal: Goal) -> String {
        switch goal {
        case .cut: "arrow.down.right"
        case .bulk: "arrow.up.right"
        case .recomp: "arrow.triangle.2.circlepath"
        case .maintain: "equal"
        }
    }

    private func detail(_ goal: Goal) -> String {
        switch goal {
        case .cut: String(localized: "Vet verliezen en spiermassa behouden")
        case .bulk: String(localized: "Spiermassa en kracht opbouwen")
        case .recomp: String(localized: "Langzaam vet eraf en spier erbij")
        case .maintain: String(localized: "Gewicht vasthouden en sterker worden")
        }
    }
}

private struct ScheduleStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        StepTitle(title: String(localized: "Je trainingsweek"),
                  subtitle: String(localized: "Kies wat je echt volhoudt. Consistentie wint van ambitie."))
        VStack(alignment: .leading, spacing: 12) {
            Text("Dagen per week").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(2...6, id: \.self) { days in
                    let selected = model.daysPerWeek == days
                    Button {
                        model.daysPerWeek = days
                        Haptics.tap()
                    } label: {
                        Text("\(days)")
                            .font(Theme.number(.title3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(selected ? Theme.accent : Theme.raised,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(selected ? Theme.onAccent : Color.primary)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(days) dagen per week")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text("Past het best: \(model.plan.title)")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
        ForEach(Equipment.allCases, id: \.self) { equipment in
            OptionTile(symbol: symbol(equipment), title: equipment.title, detail: detail(equipment),
                       selected: model.equipment == equipment) {
                model.equipment = equipment
                Haptics.tap()
            }
        }
    }

    private func symbol(_ equipment: Equipment) -> String {
        switch equipment {
        case .gym: "building.2.fill"
        case .dumbbells: "dumbbell.fill"
        case .home: "house.fill"
        }
    }

    private func detail(_ equipment: Equipment) -> String {
        switch equipment {
        case .gym: String(localized: "Stangen, machines en kabels")
        case .dumbbells: String(localized: "Dumbbells en een bankje")
        case .home: String(localized: "Geen materiaal nodig")
        }
    }
}

private struct SummaryStep: View {
    let model: OnboardingModel

    var body: some View {
        let target = EnergyCalculator.target(model.energyInput, goal: model.goal)
        let macros = EnergyCalculator.macros(kcal: target.kcal, weightKg: model.weightKg, goal: model.goal,
                                             bodyFatPercent: model.bodyFat > 0 ? model.bodyFat : nil)
        let days = StarterTemplates.days(plan: model.plan, equipment: model.equipment)
        StepTitle(title: String(localized: "Je plan staat klaar"),
                  subtitle: String(localized: "Afgestemd op je doel, je week en je materiaal."))
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Tag(text: String(localized: "Schema"), filled: true)
                Spacer()
                Text("\(model.daysPerWeek) dagen per week")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(model.plan.title).font(.title.weight(.bold))
            ForEach(days) { day in
                HStack {
                    Image(systemName: "bolt.fill").font(.caption).foregroundStyle(Theme.accentText)
                        .accessibilityHidden(true)
                    Text(day.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(day.slugs.count) oefeningen").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .card()
        VStack(alignment: .leading, spacing: 14) {
            Tag(text: String(localized: "Dagdoel"), color: Theme.Fill.cool, filled: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CountUp(value: Int(target.kcal.rounded())).font(Theme.number(.largeTitle))
                Text("kcal").font(.title3).foregroundStyle(.secondary)
            }
            MacroBar(macros: macros)
            if target.wasFloored {
                Label("Je doel is verhoogd naar je rustverbranding. Lager gaan we niet.", systemImage: "shield.fill")
                    .font(.footnote)
            }
        }
        .card()
    }
}
