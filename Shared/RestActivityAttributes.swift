import ActivityKit
import Foundation

/// Live Activity van de rusttimer: op het toegangsscherm en in het Dynamic Island.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var totalSeconds: Int
    }

    /// Naam van de training, bijvoorbeeld "Full Body A".
    var workoutName: String
}
