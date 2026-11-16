import Foundation

public enum Equipment: String, Sendable, CaseIterable { case gym, dumbbells, home }

public enum StarterPlan: String, Sendable, CaseIterable {
    case fullBody, upperLower, pushPullLegs

    public static func recommend(daysPerWeek: Int) -> StarterPlan {
        switch daysPerWeek {
        case ...3: .fullBody
        case 4: .upperLower
        default: .pushPullLegs
        }
    }
}
