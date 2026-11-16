import Foundation

public struct PlateLoadout: Sendable, Equatable {
    /// Schijven per kant, zwaarste eerst.
    public var perSide: [Double]
    /// Gewicht dat met de beschikbare schijven niet te maken is.
    public var remainder: Double
}

public enum PlateCalculator {
    public static let standardKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    public static let standardLb: [Double] = [45, 35, 25, 10, 5, 2.5]

    public static func loadout(target: Double, bar: Double, plates: [Double]) -> PlateLoadout {
        var perSideLeft = max(0, target - bar) / 2
        var result: [Double] = []
        for plate in plates.sorted(by: >) where plate > 0 {
            while perSideLeft >= plate - 1e-9 {
                result.append(plate)
                perSideLeft -= plate
            }
        }
        let remainder = (perSideLeft * 2 * 1000).rounded() / 1000
        return PlateLoadout(perSide: result, remainder: max(0, remainder))
    }
}
