import StoreKit
import SwiftUI

/// Pro-functies, met de tekst die het betaalscherm erbij toont.
enum ProFeature: String, Identifiable {
    case programs, checkIn, weeklyRecap, widgets, liveActivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .programs: String(localized: "Trainingsprogramma's")
        case .checkIn: String(localized: "Wekelijkse check-in")
        case .weeklyRecap: String(localized: "Weekoverzicht")
        case .widgets: String(localized: "Widgets")
        case .liveActivity: String(localized: "Rusttimer op je toegangsscherm")
        }
    }
}

/// Betaalscherm voor RIVO Pro.
struct PaywallView: View {
    var feature: ProFeature?
    @Environment(\.dismiss) private var dismiss
    @State private var store = ProStore.shared
    @State private var selected: ProStore.Plan = .yearly
    @State private var buying = false

    private let benefits: [(symbol: String, title: String, detail: String)] = [
        ("calendar.badge.plus", String(localized: "Trainingsprogramma's"),
         String(localized: "Blokken van 4 tot 6 weken met RIR per week en een deloadweek.")),
        ("chart.line.uptrend.xyaxis", String(localized: "Adaptief caloriedoel"),
         String(localized: "Elke week een check-in op basis van je echte verbruik.")),
        ("rosette", String(localized: "Weekoverzicht"),
         String(localized: "Je score, hoogtepunten en één focuspunt per week.")),
        ("apps.iphone", String(localized: "Widgets en Live Activity"),
         String(localized: "Stappen op je beginscherm, rusttimer op je toegangsscherm.")),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(benefits, id: \.title) { benefit in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefit.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.onAccent)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benefit.title).font(.subheadline.weight(.bold))
                                    Text(benefit.detail).font(.footnote).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .card()
                    plans
                    purchaseButton
                    footer
                }
                .padding()
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit", systemImage: "xmark") { dismiss() }
                }
            }
            .task { await store.load() }
            .onChange(of: store.isPro) { _, isPro in if isPro { dismiss() } }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            BrandLogo(height: 26)
            Text("RIVO Pro")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text(feature.map { String(localized: "\($0.title) hoort bij RIVO Pro.") }
                 ?? String(localized: "Haal meer uit elke training en elke week."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if store.products.isEmpty {
                if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Text(store.errorMessage ?? String(localized: "Abonnementen zijn nu niet beschikbaar."))
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            if let yearly = store.product(.yearly) {
                planRow(.yearly, product: yearly, title: String(localized: "Jaarlijks"),
                        detail: yearlyDetail(yearly), badge: savingsBadge(yearly))
            }
            if let monthly = store.product(.monthly) {
                planRow(.monthly, product: monthly, title: String(localized: "Maandelijks"),
                        detail: String(localized: "\(monthly.displayPrice) per maand"), badge: nil)
            }
        }
    }

    private func planRow(_ plan: ProStore.Plan, product: Product, title: String, detail: String, badge: String?) -> some View {
        let isOn = selected == plan
        return Button {
            selected = plan
            Haptics.tap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.accentText : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge { Tag(text: badge, filled: true) }
                    }
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .glassSurface(fill: isOn ? Theme.accent.opacity(0.35) : Theme.card, cornerRadius: 20)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isOn ? Theme.accentText : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func yearlyDetail(_ product: Product) -> String {
        let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
        return String(localized: "\(product.displayPrice) per jaar · \(perMonth) per maand")
    }

    /// Korting van het jaar tegenover twaalf losse maanden, afgerond op hele procenten.
    private func savingsBadge(_ yearly: Product) -> String? {
        guard let monthly = store.product(.monthly), monthly.price > 0 else { return nil }
        let twelve = NSDecimalNumber(decimal: monthly.price * 12).doubleValue
        let year = NSDecimalNumber(decimal: yearly.price).doubleValue
        let percent = Int(((1 - year / twelve) * 100).rounded())
        return percent >= 5 ? String(localized: "\(percent)% korting") : nil
    }

    private var hasTrial: Bool {
        selected == .yearly && store.trialEligible && store.product(.yearly)?.subscription?.introductoryOffer != nil
    }

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = store.product(selected) else { return }
                Task {
                    buying = true
                    if await store.purchase(product) { Haptics.success() }
                    buying = false
                }
            } label: {
                if buying {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Text(hasTrial ? String(localized: "Probeer 7 dagen gratis") : String(localized: "Word Pro"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(buying || store.product(selected) == nil)
            if let error = store.errorMessage, !store.products.isEmpty {
                Text(error).font(.caption).foregroundStyle(Theme.bad).multilineTextAlignment(.center)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Aankopen herstellen") { Task { await store.restore() } }
                .font(.footnote.weight(.semibold))
            Text(hasTrial
                 ? String(localized: "Na de gratis week wordt het jaarbedrag afgeschreven, tenzij je minstens 24 uur van tevoren opzegt. Het abonnement verlengt automatisch; opzeggen kan altijd in de Instellingen van je iPhone.")
                 : String(localized: "Het abonnement verlengt automatisch, tenzij je minstens 24 uur voor het einde van de periode opzegt. Opzeggen kan altijd in de Instellingen van je iPhone."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Gebruiksvoorwaarden", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            .font(.caption.weight(.semibold))
        }
    }
}

/// Opent het betaalscherm als de functie Pro vraagt en de gebruiker nog geen Pro heeft.
extension View {
    func paywall(for feature: Binding<ProFeature?>) -> some View {
        sheet(item: feature) { PaywallView(feature: $0) }
    }
}
