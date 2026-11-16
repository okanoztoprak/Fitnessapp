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

extension Experience {
    var title: String {
        switch self {
        case .beginner: String(localized: "Beginner")
        case .intermediate: String(localized: "Gevorderd")
        case .advanced: String(localized: "Ervaren")
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

extension Stage {
    var title: String {
        switch self {
        case .rookie: "Rookie"
        case .kindled: "Kindled"
        case .awakened: "Awakened"
        case .ascended: "Ascended"
        case .stormforged: "Stormforged"
        case .limitBreaker: "Limit Breaker"
        case .mythic: "Mythic"
        }
    }
}

extension MentorTone {
    var title: String {
        switch self {
        case .hype: String(localized: "Hype")
        case .strict: String(localized: "Streng")
        case .calm: String(localized: "Rustig")
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

extension XPSource {
    var title: String {
        switch self {
        case .workout: String(localized: "Training")
        case .personalRecord: String(localized: "Persoonlijk record")
        case .weighIn: String(localized: "Weging")
        case .proteinGoal: String(localized: "Eiwitdoel")
        case .sleep: String(localized: "Slaap")
        case .quest: String(localized: "Quest")
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

/// Sensei Kaido: korte teksten per toon. Origineel personage; illustratie volgt later.
enum Mentor {
    enum Moment { case greeting, workoutDone, restDay, record }

    static let name = "Sensei Kaido"

    static func line(_ moment: Moment, tone: MentorTone) -> String {
        switch (moment, tone) {
        case (.greeting, .hype): String(localized: "Vandaag wordt je kracht zichtbaar. Laat die aura branden!")
        case (.greeting, .strict): String(localized: "Het plan ligt klaar. Uitvoeren, geen excuses.")
        case (.greeting, .calm): String(localized: "Eén stap vandaag. Rustig en gericht.")
        case (.workoutDone, .hype): String(localized: "Geweldig! Je power level stijgt. Zo bouw je een legende.")
        case (.workoutDone, .strict): String(localized: "Gedaan. Morgen herstel je, daarna weer scherp.")
        case (.workoutDone, .calm): String(localized: "Goed werk. Eet, slaap en laat het werk zijn effect hebben.")
        case (.restDay, .hype): String(localized: "Rustdag! Hier groeit je kracht echt.")
        case (.restDay, .strict): String(localized: "Rust is onderdeel van het plan. Houd je eraan.")
        case (.restDay, .calm): String(localized: "Vandaag herstel je. Dat telt net zo zwaar als trainen.")
        case (.record, .hype): String(localized: "NIEUW RECORD! Je grens is zojuist verlegd!")
        case (.record, .strict): String(localized: "Record. Verdiend door consistent werk.")
        case (.record, .calm): String(localized: "Een nieuw record. Geniet er even van.")
        }
    }
}
