import Foundation

/// Dagtotaal zoals een externe bron het aanlevert.
struct DailyNutrition: Sendable, Equatable {
    let date: Date
    let kcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}

/// Een bron van voedingsdata. MyFitnessPal schrijft naar Apple Health, dus Health is de eerste bron;
/// een directe MyFitnessPal-koppeling of een andere app kan later dezelfde vorm aannemen.
protocol NutritionSource: Sendable {
    /// Vaste sleutel, opgeslagen bij de ingevoerde dagen.
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }

    func requestAccess() async throws
    /// Eén waarde per kalenderdag in `[start, end)`; dagen zonder inname ontbreken.
    func dailyNutrition(from start: Date, to end: Date) async throws -> [DailyNutrition]
}

/// Lichaamsgewicht uit een externe bron, bijvoorbeeld een slimme weegschaal.
struct ExternalWeight: Sendable, Equatable {
    let id: String
    let date: Date
    let kg: Double
}
