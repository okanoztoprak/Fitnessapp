import Foundation

public struct SetPerformance: Sendable, Equatable {
    public var weight: Double
    public var reps: Int
    public init(weight: Double, reps: Int) {
        self.weight = weight
        self.reps = reps
    }
    public var volume: Double { weight * Double(reps) }
}

public enum PRKind: String, Sendable, CaseIterable {
    case weight, reps, volume, e1rm
}

public enum PRDetector {
    /// Vergelijkt een set met eerdere sets van dezelfde oefening.
    /// Zonder historie is er geen PR: de eerste sessie legt alleen de basislijn vast.
    public static func detect(set: SetPerformance, history: [SetPerformance],
                              formula: OneRepMax.Formula = .epley) -> Set<PRKind> {
        guard set.weight > 0, set.reps > 0 else { return [] }
        let past = history.filter { $0.weight > 0 && $0.reps > 0 }
        guard !past.isEmpty else { return [] }
        var kinds = Set<PRKind>()

        if set.weight > past.map(\.weight).max()! { kinds.insert(.weight) }

        // Reps-PR: meer reps dan ooit op dit gewicht of zwaarder.
        let atOrAbove = past.filter { $0.weight >= set.weight }
        if let best = atOrAbove.map(\.reps).max(), set.reps > best { kinds.insert(.reps) }

        if set.volume > past.map(\.volume).max()! { kinds.insert(.volume) }

        if let estimate = OneRepMax.estimate(weight: set.weight, reps: set.reps, formula: formula) {
            let best = past.compactMap {
                OneRepMax.estimate(weight: $0.weight, reps: $0.reps, formula: formula)
            }.max()
            if let best, estimate > best { kinds.insert(.e1rm) }
        }
        return kinds
    }
}
