import Foundation
import PowerCore

// Weergavenamen voor enums. Alles loopt via de String Catalog (nl is de brontaal).

extension Sex {
    var title: String {
        switch self {
        case .male: String(localized: "Man")
        case .female: String(localized: "Vrouw")
        }
    }
}

extension ActivityLevel {
    var title: String {
        switch self {
        case .sedentary: String(localized: "Zittend")
        case .light: String(localized: "Licht actief")
        case .moderate: String(localized: "Gemiddeld actief")
        case .active: String(localized: "Actief")
        case .veryActive: String(localized: "Zeer actief")
        }
    }
}

extension Goal {
    var title: String {
        switch self {
        case .cut: String(localized: "Afvallen (cut)")
        case .bulk: String(localized: "Aankomen (bulk)")
        case .recomp: String(localized: "Recomp")
        case .maintain: String(localized: "Onderhoud")
        }
    }
}

extension Equipment {
    var title: String {
        switch self {
        case .gym: String(localized: "Sportschool")
        case .dumbbells: String(localized: "Dumbbells")
        case .home: String(localized: "Thuis (lichaamsgewicht)")
        }
    }
}

extension StarterPlan {
    var title: String {
        switch self {
        case .fullBody: "Full Body"
        case .upperLower: "Upper/Lower"
        case .pushPullLegs: "Push/Pull/Legs"
        }
    }
}

extension MuscleGroup {
    var title: String {
        switch self {
        case .chest: String(localized: "Borst")
        case .back: String(localized: "Rug")
        case .shoulders: String(localized: "Schouders")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .forearms: String(localized: "Onderarmen")
        case .quads: String(localized: "Quadriceps")
        case .hamstrings: String(localized: "Hamstrings")
        case .glutes: String(localized: "Billen")
        case .calves: String(localized: "Kuiten")
        case .core: String(localized: "Core")
        case .cardio: String(localized: "Cardio")
        }
    }
}

extension SetKind {
    var title: String {
        switch self {
        case .warmup: String(localized: "Warming-up")
        case .normal: String(localized: "Normaal")
        case .dropset: String(localized: "Dropset")
        case .failure: String(localized: "Tot falen")
        }
    }
    var badge: String {
        switch self {
        case .warmup: "W"
        case .normal: ""
        case .dropset: "D"
        case .failure: "F"
        }
    }
}

extension PRKind {
    var title: String {
        switch self {
        case .weight: String(localized: "Gewicht")
        case .reps: String(localized: "Reps")
        case .volume: String(localized: "Volume")
        case .e1rm: String(localized: "Geschatte 1RM")
        }
    }
}

enum GearLabel {
    static let all = ["barbell", "dumbbell", "machine", "cable", "bodyweight", "kettlebell", "band", "cardio"]

    static func title(_ raw: String) -> String {
        switch raw {
        case "barbell": String(localized: "Barbell")
        case "dumbbell": String(localized: "Dumbbell")
        case "machine": String(localized: "Machine")
        case "cable": String(localized: "Kabel")
        case "bodyweight": String(localized: "Lichaamsgewicht")
        case "kettlebell": String(localized: "Kettlebell")
        case "band": String(localized: "Weerstandsband")
        default: String(localized: "Cardio")
        }
    }
}

extension StrengthLevel {
    var title: String {
        switch self {
        case .beginner: String(localized: "Beginner")
        case .novice: String(localized: "Gevorderde beginner")
        case .intermediate: String(localized: "Gevorderd")
        case .advanced: String(localized: "Ver gevorderd")
        case .elite: String(localized: "Elite")
        }
    }
}

extension MainLift {
    var title: String {
        switch self {
        case .squat: String(localized: "Squat")
        case .bench: String(localized: "Bankdrukken")
        case .deadlift: String(localized: "Deadlift")
        case .overheadPress: String(localized: "Overhead press")
        case .row: String(localized: "Barbell row")
        }
    }
}

extension Appearance {
    var title: String {
        switch self {
        case .system: String(localized: "Systeem")
        case .light: String(localized: "Licht")
        case .dark: String(localized: "Donker")
        }
    }
}

extension MuscleGroup {
    var symbol: String {
        switch self {
        case .chest, .back, .shoulders: "figure.strengthtraining.traditional"
        case .biceps, .triceps, .forearms: "figure.arms.open"
        case .quads, .hamstrings, .glutes, .calves: "figure.strengthtraining.functional"
        case .core: "figure.core.training"
        case .cardio: "figure.run"
        }
    }
}
