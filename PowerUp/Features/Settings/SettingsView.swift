import PowerCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @State private var notificationsDenied = false

    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: profile.reminderHour, minute: profile.reminderMinute, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            profile.reminderHour = parts.hour ?? 18
            profile.reminderMinute = parts.minute ?? 0
            updateReminders()
        })
    }

    /// Maandag tot en met zondag, met de korte namen van de taal van het toestel.
    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return HStack(spacing: 6) {
            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                let isOn = profile.reminderWeekdays.contains(weekday)
                Button {
                    var days = profile.reminderWeekdays
                    if isOn { days.remove(weekday) } else { days.insert(weekday) }
                    profile.reminderWeekdays = days
                    updateReminders()
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? Theme.accent : Theme.raised, in: Circle())
                        .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.standaloneWeekdaySymbols[weekday - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func updateReminders() {
        Task {
            if profile.reminderEnabled || profile.recapReminderEnabled {
                let allowed = await ReminderService.ensurePermission()
                notificationsDenied = !allowed
                if !allowed {
                    profile.reminderEnabled = false
                    profile.recapReminderEnabled = false
                }
            }
            await ReminderService.reschedule(profile: profile)
        }
    }

    var body: some View {
        Form {
            Group {
                Section("Weergave") {
                    Picker("Weergave", selection: $profile.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Eenheden") {
                    Picker("Eenheden", selection: $profile.usesMetric) {
                        Text("kg / cm").tag(true)
                        Text("lb / inch").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Training") {
                    Stepper("\(profile.trainingDaysPerWeek) dagen per week",
                            value: $profile.trainingDaysPerWeek, in: 2...6)
                    Picker("Schema", selection: $profile.preferredPlan) {
                        Text("Automatisch").tag(StarterPlan?.none)
                        ForEach(StarterPlan.allCases, id: \.self) { Text($0.title).tag(StarterPlan?.some($0)) }
                    }
                    Picker("Apparatuur", selection: $profile.equipment) {
                        ForEach(Equipment.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Stepper("Rusttijd: \(profile.restSeconds) s", value: $profile.restSeconds, in: 30...600, step: 15)
                    Picker("1RM-formule", selection: $profile.e1rmFormula) {
                        Text("Epley").tag(OneRepMax.Formula.epley)
                        Text("Brzycki").tag(OneRepMax.Formula.brzycki)
                    }
                    Toggle("Records vieren", isOn: $profile.celebratePRs)
                }
                Section {
                    Stepper("Stappendoel: \(profile.stepGoal.formatted())", value: $profile.stepGoal,
                            in: StepGoal.range, step: StepGoal.step)
                } header: {
                    Text("Activiteit")
                } footer: {
                    Text("Je stappen komen uit Apple Health. Koppelen doe je op het tabblad Vandaag of Voeding.")
                }
                Section {
                    Toggle("Trainingsherinnering", isOn: Binding(get: { profile.reminderEnabled }, set: { value in
                        profile.reminderEnabled = value
                        updateReminders()
                    }))
                    if profile.reminderEnabled {
                        DatePicker("Tijd", selection: reminderTime, displayedComponents: .hourAndMinute)
                        weekdayPicker
                    }
                    Toggle("Weekoverzicht op maandag", isOn: Binding(get: { profile.recapReminderEnabled }, set: { value in
                        profile.recapReminderEnabled = value
                        updateReminders()
                    }))
                } header: {
                    Text("Herinneringen")
                } footer: {
                    if notificationsDenied {
                        Text("Meldingen staan uit voor RIVO. Zet ze aan in de Instellingen-app van iOS.")
                    } else {
                        Text("Alleen de meldingen die je hier aanzet. Ze blijven op je toestel.")
                    }
                }
                Section {
                    Toggle("Calorieën verbergen", isOn: $profile.hideCalories)
                    Toggle("Gewicht verbergen", isOn: $profile.hideWeight)
                } header: {
                    Text("Welzijn")
                } footer: {
                    Text("Verberg getallen als je merkt dat ze je geen goed doen. Loggen en je trend blijven op de achtergrond werken.")
                }
                Section("Over") {
                    Text("RIVO geeft geen medisch advies. Overleg bij twijfel, klachten of een medische aandoening met een arts.")
                        .font(.footnote)
                    LabeledContent("Versie",
                                   value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Instellingen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
