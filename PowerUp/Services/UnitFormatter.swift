import Foundation
import PowerCore

/// Zet SI-opslagwaarden om naar de eenheden die de gebruiker koos, en terug.
struct UnitFormatter {
    /// "1 set" of "3 sets".
    static func sets(_ count: Int) -> String {
        count == 1 ? String(localized: "1 set") : String(localized: "\(count) sets")
    }

    let metric: Bool

    var weightUnit: String { metric ? "kg" : "lb" }
    var heightUnit: String { metric ? "cm" : "in" }
    var barWeight: Double { metric ? 20 : 45 }
    var plates: [Double] { metric ? PlateCalculator.standardKg : PlateCalculator.standardLb }

    func displayWeight(_ kg: Double) -> Double {
        metric ? kg : (UnitConversion.kgToLb(kg) * 100).rounded() / 100
    }
    func kg(fromDisplay value: Double) -> Double {
        metric ? value : UnitConversion.lbToKg(value)
    }
    func displayHeight(_ cm: Double) -> Double {
        metric ? cm : (UnitConversion.cmToInch(cm) * 10).rounded() / 10
    }
    func cm(fromDisplay value: Double) -> Double {
        metric ? value : UnitConversion.inchToCm(value)
    }
    func weightText(_ kg: Double, digits: Int = 1) -> String {
        "\(Self.number(displayWeight(kg), digits: digits)) \(weightUnit)"
    }

    static func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)))
    }
}

extension UserProfile {
    var units: UnitFormatter { UnitFormatter(metric: usesMetric) }
}
