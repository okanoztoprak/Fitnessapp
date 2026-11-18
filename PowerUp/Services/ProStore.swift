import Foundation
import Observation
import StoreKit
import WidgetKit

/// RIVO Pro via StoreKit 2: een maand- en jaarabonnement in één abonnementsgroep.
/// Apple regelt betaling, proefperiode, verlenging en opzeggen; de app leest alleen wat actief is.
@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    enum Plan: String, CaseIterable {
        case yearly = "rivo.pro.yearly"
        case monthly = "rivo.pro.monthly"
    }

    private(set) var products: [Product] = []
    private(set) var isPro: Bool
    private(set) var isLoading = false
    /// Of deze Apple ID nog recht heeft op de gratis proefweek van het jaarabonnement.
    private(set) var trialEligible = true
    var errorMessage: String?

    @ObservationIgnored private var updates: Task<Void, Never>?
    private static let cacheKey = "rivo.isPro"

    private init() {
        // Laatste bekende stand, zodat Pro-functies bij een start zonder internet niet even verdwijnen.
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
    }

    func product(_ plan: Plan) -> Product? { products.first { $0.id == plan.rawValue } }

    func load() async {
        guard products.isEmpty else { await refreshEntitlements(); return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Plan.allCases.map(\.rawValue))
                .sorted { $0.price > $1.price }
            if let yearly = product(.yearly), let subscription = yearly.subscription {
                trialEligible = await subscription.isEligibleForIntroOffer
            }
        } catch {
            errorMessage = String(localized: "De abonnementen konden niet geladen worden. Controleer je verbinding.")
        }
        await refreshEntitlements()
    }

    /// Koopt een abonnement. Geeft `true` terug als Pro daarna actief is.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        errorMessage = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = String(localized: "De aankoop kon niet worden gecontroleerd.")
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .pending:
                // Bijvoorbeeld 'Vraag om te kopen' bij gezinsdelen; Transaction.updates meldt het later.
                errorMessage = String(localized: "De aankoop wacht op goedkeuring.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = String(localized: "Herstellen is niet gelukt. Probeer het later opnieuw.")
        }
        await refreshEntitlements()
        if !isPro, errorMessage == nil {
            errorMessage = String(localized: "Er is geen actief abonnement gevonden voor deze Apple ID.")
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Plan(rawValue: transaction.productID) != nil,
               transaction.revocationDate == nil {
                active = true
            }
        }
        guard active != isPro else { return }
        isPro = active
        UserDefaults.standard.set(active, forKey: Self.cacheKey)
        var snapshot = WidgetSnapshot.load()
        snapshot.isPro = active
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
