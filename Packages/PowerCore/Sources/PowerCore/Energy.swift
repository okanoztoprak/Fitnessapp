import Foundation

public enum Sex: String, Sendable, CaseIterable { case male, female }

public enum ActivityLevel: String, Sendable, CaseIterable {
    case sedentary, light, moderate, active, veryActive

    public var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

public enum Goal: String, Sendable, CaseIterable {
    case cut, bulk, recomp, maintain

    /// Aanpassing ten opzichte van TDEE.
    public var calorieFactor: Double {
        switch self {
        case .cut: 0.80
        case .bulk: 1.10
        case .recomp: 0.95
        case .maintain: 1.0
        }
    }
}

public enum BMRFormula: String, Sendable { case mifflinStJeor, katchMcArdle }

public struct EnergyInput: Sendable, Equatable {
    public var weightKg: Double
    public var heightCm: Double
    public var age: Int
    public var sex: Sex
    public var bodyFatPercent: Double?
    public var activity: ActivityLevel

    public init(weightKg: Double, heightCm: Double, age: Int, sex: Sex,
                bodyFatPercent: Double? = nil, activity: ActivityLevel) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.age = age
        self.sex = sex
        self.bodyFatPercent = bodyFatPercent
        self.activity = activity
    }
}

public struct CalorieTarget: Sendable, Equatable {
    public var kcal: Double
    public var bmr: Double
    public var tdee: Double
    public var formula: BMRFormula
    /// Het doel is omhoog bijgesteld naar de calorievloer (BMR).
    public var wasFloored: Bool
    /// Verwachte gewichtsverandering per week in kg (negatief = afvallen).
    public var expectedWeeklyChangeKg: Double
    /// Meer dan 1% lichaamsgewicht verlies per week.
    public var exceedsSafeLossRate: Bool
}

public struct MacroTarget: Sendable, Equatable {
    public var proteinG: Double
    public var fatG: Double
    public var carbsG: Double
}

public enum EnergyCalculator {
    public static let kcalPerKg = 7700.0

    public static func bmr(_ input: EnergyInput) -> (value: Double, formula: BMRFormula) {
        if let bf = input.bodyFatPercent, bf > 0, bf < 70 {
            let lean = input.weightKg * (1 - bf / 100)
            return (370 + 21.6 * lean, .katchMcArdle)
        }
        let base = 10 * input.weightKg + 6.25 * input.heightCm - 5 * Double(input.age)
        return (base + (input.sex == .male ? 5 : -161), .mifflinStJeor)
    }

    public static func tdee(_ input: EnergyInput) -> Double {
        bmr(input).value * input.activity.multiplier
    }

    public static func target(_ input: EnergyInput, goal: Goal) -> CalorieTarget {
        let (bmrValue, formula) = bmr(input)
        let tdeeValue = bmrValue * input.activity.multiplier
        let raw = tdeeValue * goal.calorieFactor
        let kcal = max(raw, bmrValue)
        let weekly = (kcal - tdeeValue) * 7 / kcalPerKg
        return CalorieTarget(
            kcal: kcal, bmr: bmrValue, tdee: tdeeValue, formula: formula,
            wasFloored: raw < bmrValue,
            expectedWeeklyChangeKg: weekly,
            exceedsSafeLossRate: -weekly > input.weightKg * 0.01
        )
    }

    /// Standaard eiwit in g per kg lichaamsgewicht.
    public static func defaultProteinPerKg(goal: Goal) -> Double { goal == .cut ? 2.2 : 1.8 }

    /// Eiwit 1,8 g/kg (2,2 bij een cut), vet 25% van de calorieën, rest koolhydraten.
    /// Met bekend vetpercentage boven 25% wordt eiwit op vetvrije massa gebaseerd.
    /// Een eigen eiwitdoel (`proteinPerKg`) en vetaandeel (`fatShare`) overschrijven de standaard.
    public static func macros(kcal: Double, weightKg: Double, goal: Goal,
                              bodyFatPercent: Double? = nil, proteinPerKg: Double? = nil,
                              fatShare: Double = 0.25) -> MacroTarget {
        var reference = weightKg
        var perKg = defaultProteinPerKg(goal: goal)
        if let proteinPerKg {
            perKg = proteinPerKg
        } else if let bf = bodyFatPercent, bf > 25, bf < 70 {
            reference = weightKg * (1 - bf / 100)
            perKg += 0.4
        }
        let protein = min(reference * perKg, kcal * 0.4 / 4)
        let fat = kcal * min(max(fatShare, 0.15), 0.45) / 9
        let carbs = max(0, (kcal - protein * 4 - fat * 9) / 4)
        return MacroTarget(proteinG: protein, fatG: fat, carbsG: carbs)
    }
}
