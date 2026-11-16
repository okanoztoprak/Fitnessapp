import Foundation

/// Opslag is altijd SI (kg, cm). Omrekenen gebeurt alleen voor weergave en invoer.
public enum UnitConversion {
    public static let lbPerKg = 2.204_622_621_8
    public static let cmPerInch = 2.54

    public static func kgToLb(_ kg: Double) -> Double { kg * lbPerKg }
    public static func lbToKg(_ lb: Double) -> Double { lb / lbPerKg }
    public static func cmToInch(_ cm: Double) -> Double { cm / cmPerInch }
    public static func inchToCm(_ inch: Double) -> Double { inch * cmPerInch }
}
