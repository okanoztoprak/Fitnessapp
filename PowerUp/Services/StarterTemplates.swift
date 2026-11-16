import Foundation
import PowerCore

struct TemplateDay: Identifiable, Hashable {
    let name: String
    let slugs: [String]
    var id: String { name }
}

/// Startplan op basis van beschikbare dagen en apparatuur.
enum StarterTemplates {
    static func days(plan: StarterPlan, equipment: Equipment) -> [TemplateDay] {
        switch (plan, equipment) {
        case (.fullBody, .gym): [
            TemplateDay(name: "Full Body A", slugs: ["squat", "bench-press", "barbell-row", "romanian-deadlift", "lateral-raise", "plank"]),
            TemplateDay(name: "Full Body B", slugs: ["deadlift", "overhead-press", "lat-pulldown", "leg-press", "db-incline-press", "hanging-leg-raise"]),
        ]
        case (.upperLower, .gym): [
            TemplateDay(name: "Upper", slugs: ["bench-press", "barbell-row", "overhead-press", "lat-pulldown", "db-curl", "triceps-pushdown"]),
            TemplateDay(name: "Lower", slugs: ["squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "standing-calf-raise", "plank"]),
        ]
        case (.pushPullLegs, .gym): [
            TemplateDay(name: "Push", slugs: ["bench-press", "overhead-press", "db-incline-press", "lateral-raise", "triceps-pushdown"]),
            TemplateDay(name: "Pull", slugs: ["deadlift", "lat-pulldown", "barbell-row", "face-pull", "barbell-curl"]),
            TemplateDay(name: "Legs", slugs: ["squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "standing-calf-raise"]),
        ]
        case (.fullBody, .dumbbells): [
            TemplateDay(name: "Full Body A", slugs: ["goblet-squat", "db-bench-press", "db-row", "db-romanian-deadlift", "lateral-raise", "plank"]),
            TemplateDay(name: "Full Body B", slugs: ["bulgarian-split-squat", "db-shoulder-press", "chest-supported-row", "db-incline-press", "hammer-curl", "lying-leg-raise"]),
        ]
        case (.upperLower, .dumbbells): [
            TemplateDay(name: "Upper", slugs: ["db-bench-press", "db-row", "db-shoulder-press", "rear-delt-fly", "db-curl", "overhead-triceps-extension"]),
            TemplateDay(name: "Lower", slugs: ["goblet-squat", "db-romanian-deadlift", "bulgarian-split-squat", "db-calf-raise", "plank"]),
        ]
        case (.pushPullLegs, .dumbbells): [
            TemplateDay(name: "Push", slugs: ["db-bench-press", "db-shoulder-press", "db-incline-press", "lateral-raise", "overhead-triceps-extension"]),
            TemplateDay(name: "Pull", slugs: ["db-row", "chest-supported-row", "rear-delt-fly", "db-curl", "hammer-curl"]),
            TemplateDay(name: "Legs", slugs: ["goblet-squat", "db-romanian-deadlift", "lunge", "db-calf-raise", "plank"]),
        ]
        case (.fullBody, .home): [
            TemplateDay(name: "Full Body A", slugs: ["bodyweight-squat", "push-up", "inverted-row", "glute-bridge", "plank"]),
            TemplateDay(name: "Full Body B", slugs: ["pistol-squat", "pike-push-up", "pull-up", "nordic-curl", "lying-leg-raise"]),
        ]
        case (.upperLower, .home): [
            TemplateDay(name: "Upper", slugs: ["push-up", "pull-up", "pike-push-up", "inverted-row", "diamond-push-up"]),
            TemplateDay(name: "Lower", slugs: ["bodyweight-squat", "glute-bridge", "nordic-curl", "pistol-squat", "plank"]),
        ]
        case (.pushPullLegs, .home): [
            TemplateDay(name: "Push", slugs: ["push-up", "pike-push-up", "diamond-push-up", "bench-dip"]),
            TemplateDay(name: "Pull", slugs: ["pull-up", "inverted-row", "chin-up", "dead-bug"]),
            TemplateDay(name: "Legs", slugs: ["bodyweight-squat", "glute-bridge", "nordic-curl", "pistol-squat", "plank"]),
        ]
        }
    }

    static func days(for profile: UserProfile) -> [TemplateDay] {
        days(plan: .recommend(daysPerWeek: profile.trainingDaysPerWeek), equipment: profile.equipment)
    }
}
