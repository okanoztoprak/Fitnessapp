import Foundation

// MARK: - Progressie per oefening

public struct ProgressionSuggestion: Sendable, Equatable {
    public enum Reason: String, Sendable {
        /// Alle werksets haalden de bovenkant van het repbereik: gewicht omhoog.
        case addWeight
        /// Zelfde gewicht, één rep erbij.
        case addReps
        /// Onder het repbereik gebleven: eerst dit gewicht onder controle krijgen.
        case consolidate
    }

    public var weight: Double
    public var reps: Int
    public var reason: Reason

    public init(weight: Double, reps: Int, reason: Reason) {
        self.weight = weight
        self.reps = reps
        self.reason = reason
    }
}

public enum ProgressionAdvisor {
    /// Dubbele progressie: eerst reps opbouwen binnen het bereik, dan gewicht erbij.
    /// Geeft `nil` zonder bruikbare historie; de eerste sessie legt de basislijn vast.
    public static func suggest(lastSets: [SetPerformance], repRange: ClosedRange<Int> = 8...12,
                               increment: Double) -> ProgressionSuggestion? {
        let sets = lastSets.filter { $0.reps > 0 }
        guard let top = sets.map(\.weight).max() else { return nil }
        // Werksets zijn de sets op het zwaarste gewicht; lichtere sets tellen als opbouw.
        let working = sets.filter { $0.weight == top }
        let fewest = working.map(\.reps).min() ?? 0

        if top <= 0 {
            // Lichaamsgewicht: alleen reps kunnen omhoog.
            return ProgressionSuggestion(weight: 0, reps: fewest + 1, reason: .addReps)
        }
        if fewest >= repRange.upperBound {
            return ProgressionSuggestion(weight: top + max(increment, 0), reps: repRange.lowerBound, reason: .addWeight)
        }
        if fewest < repRange.lowerBound {
            return ProgressionSuggestion(weight: top, reps: repRange.lowerBound, reason: .consolidate)
        }
        return ProgressionSuggestion(weight: top, reps: fewest + 1, reason: .addReps)
    }
}

// MARK: - Trainen of rusten

public struct SessionAdvice: Sendable, Equatable {
    public enum Kind: String, Sendable { case train, rest }
    public enum Reason: String, Sendable {
        case firstSession, onTrack, behindSchedule
        case trainedToday, weeklyGoalReached, consecutiveDays
    }

    public var kind: Kind
    public var reason: Reason
    /// Afgeronde trainingsdagen in de lopende kalenderweek.
    public var sessionsThisWeek: Int

    public init(kind: Kind, reason: Reason, sessionsThisWeek: Int) {
        self.kind = kind
        self.reason = reason
        self.sessionsThisWeek = sessionsThisWeek
    }
}

public enum SessionAdvisor {
    /// Advies voor vandaag op basis van de dagen waarop getraind is en het weekdoel.
    /// Rust is een advies, geen blokkade: de app laat je altijd trainen.
    public static func advise(workoutDays: [Date], plannedPerWeek: Int, today: Date,
                              calendar: Calendar = .current) -> SessionAdvice {
        let days = Set(workoutDays.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)
        let week = calendar.dateInterval(of: .weekOfYear, for: today)
        let thisWeek = days.filter { day in week.map { $0.contains(day) } ?? false }.count

        func advice(_ kind: SessionAdvice.Kind, _ reason: SessionAdvice.Reason) -> SessionAdvice {
            SessionAdvice(kind: kind, reason: reason, sessionsThisWeek: thisWeek)
        }

        guard !days.isEmpty else { return advice(.train, .firstSession) }
        if days.contains(todayStart) { return advice(.rest, .trainedToday) }
        if thisWeek >= plannedPerWeek { return advice(.rest, .weeklyGoalReached) }

        func trained(daysAgo: Int) -> Bool {
            calendar.date(byAdding: .day, value: -daysAgo, to: todayStart).map(days.contains) ?? false
        }
        // Bij een schema tot vier dagen is drie dagen op rij onnodig zwaar.
        if plannedPerWeek <= 4, trained(daysAgo: 1), trained(daysAgo: 2) {
            return advice(.rest, .consecutiveDays)
        }

        let daysLeft = week.map { interval -> Int in
            let end = calendar.startOfDay(for: interval.end)
            return max(1, calendar.dateComponents([.day], from: todayStart, to: end).day ?? 1)
        } ?? 1
        let sessionsLeft = plannedPerWeek - thisWeek
        return advice(.train, sessionsLeft >= daysLeft ? .behindSchedule : .onTrack)
    }

    /// Welke dag van het schema is aan de beurt: eerst wat nog nooit gedaan is, anders wat het langst geleden is.
    public static func nextDayIndex(lastPerformed: [Date?]) -> Int? {
        guard !lastPerformed.isEmpty else { return nil }
        if let never = lastPerformed.firstIndex(where: { $0 == nil }) { return never }
        return lastPerformed.indices.min { lastPerformed[$0]! < lastPerformed[$1]! }
    }
}
