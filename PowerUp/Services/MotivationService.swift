import Foundation
import PowerCore
import SwiftData
import SwiftUI

/// Alles wat het weekoverzicht en de uitdagingen nodig hebben, in één keer opgehaald.
@MainActor
struct MotivationData {
    let profile: UserProfile
    let finished: [Workout]
    let records: [PersonalRecord]
    let nutrition: [NutritionEntry]
    let weights: [BodyWeightEntry]
    let program: TrainingProgram?

    private var calendar: Calendar { .current }

    var plannedPerWeek: Int { program?.daysPerWeek ?? profile.trainingDaysPerWeek }

    var tracksNutrition: Bool {
        if profile.healthSyncEnabled { return true }
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        return nutrition.contains { $0.date >= cutoff }
    }

    func weekStart(of date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    // MARK: Weekoverzicht

    func summary(weekStart start: Date) -> WeekSummary {
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let inWeek = finished.filter { $0.startedAt >= start && $0.startedAt < end }
        let plan = NutritionPlan(profile: profile, weights: weights, entries: nutrition)
        let days = plan.days.filter { $0.date >= start && $0.date < end }
        let onTarget = days.filter { abs($0.kcal - plan.targetKcal) <= plan.targetKcal * 0.1 }.count
        let protein = days.filter { $0.proteinG >= plan.macros.proteinG * 0.9 }.count
        let weekWeights = weights.filter { $0.date >= start && $0.date < end }
        let weighInDays = Set(weekWeights.map { calendar.startOfDay(for: $0.date) }).count

        // Verandering van het trendgewicht over de week, zonder tikfouten.
        let points = AdaptiveExpenditure.withoutOutliers(weights.map { WeightPoint(date: $0.date, kg: $0.kg) })
        let trend = WeightTrend.ema(points)
        let before = trend.last { $0.date < start }?.kg ?? trend.first { $0.date >= start }?.kg
        let after = trend.last { $0.date < end }?.kg
        let change = (before != nil && after != nil && weighInDays > 0) ? (after ?? 0) - (before ?? 0) : nil

        return WeekSummary(
            workouts: Set(inWeek.map { calendar.startOfDay(for: $0.startedAt) }).count,
            plannedWorkouts: plannedPerWeek,
            hardSets: inWeek.reduce(0) { $0 + Insights.hardSets(in: $1) },
            volumeKg: inWeek.reduce(0) { $0 + $1.volumeKg },
            records: Set(records.filter { $0.date >= start && $0.date < end }.map(\.exerciseSlug)).count,
            loggedFoodDays: days.filter { $0.kcal > 0 }.count,
            daysOnTarget: onTarget,
            proteinDays: protein,
            weighIns: weighInDays,
            trendChangeKg: change)
    }

    func review(weekStart start: Date) -> (summary: WeekSummary, review: WeeklyReview) {
        let current = summary(weekStart: start)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start
        let previous = summary(weekStart: previousStart)
        let streak = WeekStreak.current(workoutDays: finished.map(\.startedAt),
                                        today: calendar.date(byAdding: .day, value: 6, to: start) ?? start)
        return (current, WeeklyReviewer.review(current: current, previous: previous.isEmpty ? nil : previous,
                                               streakWeeks: streak, tracksNutrition: tracksNutrition))
    }

    /// Het overzicht van vorige week, als dat er is en nog niet bekeken.
    var pendingRecapWeek: Date? {
        let thisWeek = weekStart(of: Date())
        guard let last = calendar.date(byAdding: .day, value: -7, to: thisWeek),
              (profile.lastRecapSeen ?? .distantPast) < thisWeek,
              !summary(weekStart: last).isEmpty else { return nil }
        return last
    }

    /// De laatste weken met iets erin, nieuwste eerst.
    func recentWeeks(count: Int = 8) -> [Date] {
        let thisWeek = weekStart(of: Date())
        return (1...count).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -7 * offset, to: thisWeek),
                  !summary(weekStart: start).isEmpty else { return nil }
            return start
        }
    }

    // MARK: Uitdagingen

    func currentChallenges(now: Date = Date()) -> [ChallengeDefinition] {
        let weekStart = weekStart(of: now)
        let week = calendar.component(.weekOfYear, from: now)
        let previousWeeks = (1...4).compactMap { calendar.date(byAdding: .day, value: -7 * $0, to: weekStart) }
            .map { summary(weekStart: $0) }
            .filter { $0.workouts > 0 }
        let average = previousWeeks.isEmpty ? nil
            : Double(previousWeeks.reduce(0) { $0 + $1.hardSets }) / Double(previousWeeks.count)
        var result = ChallengeGenerator.weekly(weekStart: weekStart, weekNumber: week, plannedPerWeek: plannedPerWeek,
                                               tracksNutrition: tracksNutrition, averageWeeklySets: average)
        if let month = calendar.dateInterval(of: .month, for: now) {
            let days = calendar.dateComponents([.day], from: month.start, to: month.end).day ?? 30
            result.append(ChallengeGenerator.monthly(monthStart: month.start, plannedPerWeek: plannedPerWeek,
                                                     daysInMonth: days))
        }
        return result
    }

    func progress(of challenge: ChallengeDefinition) -> Double {
        let end: Date = switch challenge.period {
        case .week: calendar.date(byAdding: .day, value: 7, to: challenge.start) ?? challenge.start
        case .month: calendar.date(byAdding: .month, value: 1, to: challenge.start) ?? challenge.start
        }
        switch challenge.kind {
        case .workouts:
            // Trainingsdagen, niet sessies: drie korte trainingen op één dag tellen als één.
            return Double(Set(finished.filter { $0.startedAt >= challenge.start && $0.startedAt < end }
                .map { calendar.startOfDay(for: $0.startedAt) }).count)
        case .hardSets:
            return Double(finished.filter { $0.startedAt >= challenge.start && $0.startedAt < end }
                .reduce(0) { $0 + Insights.hardSets(in: $1) })
        case .records:
            return Double(Set(records.filter { $0.date >= challenge.start && $0.date < end }.map(\.exerciseSlug)).count)
        case .weighIns:
            return Double(Set(weights.filter { $0.date >= challenge.start && $0.date < end }
                .map { calendar.startOfDay(for: $0.date) }).count)
        case .proteinDays, .foodLogDays:
            let plan = NutritionPlan(profile: profile, weights: weights, entries: nutrition)
            let days = plan.days.filter { $0.date >= challenge.start && $0.date < end }
            if challenge.kind == .foodLogDays { return Double(days.filter { $0.kcal > 0 }.count) }
            return Double(days.filter { $0.proteinG >= plan.macros.proteinG * 0.9 }.count)
        }
    }
}

/// Teksten en symbolen voor de motivatieschermen.
enum MotivationText {
    static func title(_ kind: ChallengeKind, target: Int, period: ChallengePeriod) -> String {
        switch (kind, period) {
        case (.workouts, .month): String(localized: "\(target) trainingen deze maand")
        case (.workouts, _): String(localized: "Train \(target)× deze week")
        case (.proteinDays, _): String(localized: "\(target) dagen je eiwitdoel")
        case (.foodLogDays, _): String(localized: "\(target) dagen je eten loggen")
        case (.weighIns, _): String(localized: "\(target)× wegen")
        case (.records, _): String(localized: "Verbeter een record")
        case (.hardSets, _): String(localized: "\(target) harde sets")
        }
    }

    static func symbol(_ kind: ChallengeKind) -> String {
        switch kind {
        case .workouts: "dumbbell.fill"
        case .proteinDays: "fork.knife"
        case .foodLogDays: "list.bullet.clipboard.fill"
        case .weighIns: "scalemass.fill"
        case .records: "trophy.fill"
        case .hardSets: "flame.fill"
        }
    }

    static func color(_ kind: ChallengeKind) -> Color {
        switch kind {
        case .workouts, .hardSets: Theme.accentText
        case .proteinDays, .foodLogDays: Theme.coral
        case .weighIns: Theme.violet
        case .records: Theme.warn
        }
    }

    /// Vulkleur voor een badge; zwarte tekst moet erop leesbaar blijven.
    static func badgeFill(_ kind: ChallengeKind) -> Color {
        switch kind {
        case .workouts, .hardSets: Theme.accent
        case .proteinDays, .foodLogDays: Theme.Fill.coral
        case .weighIns: Theme.Fill.violet
        case .records: Theme.Fill.warn
        }
    }

    static func highlight(_ highlight: Highlight) -> (symbol: String, text: String) {
        switch highlight {
        case .planCompleted: ("checkmark.seal.fill", String(localized: "Alle geplande trainingen gedaan"))
        case let .moreVolume(percent): ("arrow.up.right", String(localized: "\(percent)% meer volume dan de week ervoor"))
        case let .records(count): ("trophy.fill", count == 1 ? String(localized: "1 nieuw record")
                                   : String(localized: "\(count) nieuwe records"))
        case let .streak(weeks): ("flame.fill", String(localized: "\(weeks) weken op rij getraind"))
        case let .proteinDays(days): ("fork.knife", String(localized: "\(days) dagen je eiwitdoel gehaald"))
        }
    }

    static func focus(_ focus: WeekFocus) -> (title: String, text: String) {
        switch focus {
        case let .trainMore(missing):
            (String(localized: "Plan je trainingen in"),
             missing == 1 ? String(localized: "Er ontbrak 1 training. Zet je trainingen deze week vast in je agenda.")
             : String(localized: "Er ontbraken \(missing) trainingen. Zet je trainingen deze week vast in je agenda."))
        case .logFood:
            (String(localized: "Log je eten"),
             String(localized: "Met minstens 5 gelogde dagen wordt je verbruik en je caloriedoel een stuk nauwkeuriger."))
        case .hitProtein:
            (String(localized: "Meer eiwit"),
             String(localized: "Je haalde je eiwitdoel op minder dan 4 dagen. Een eiwitrijk ontbijt maakt het verschil."))
        case .weighIn:
            (String(localized: "Weeg je vaker"),
             String(localized: "Twee tot drie wegingen per week maken je gewichtstrend betrouwbaar."))
        case .keepGoing:
            (String(localized: "Zo doorgaan"), String(localized: "Alles op schema. Houd dit ritme vast."))
        }
    }

    static func weekTitle(_ start: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let week = Calendar.current.component(.weekOfYear, from: start)
        return String(localized: "Week \(week) · \(start.formatted(.dateTime.day().month())) – \(end.formatted(.dateTime.day().month()))")
    }

    static func scoreLabel(_ score: Int) -> String {
        switch score {
        case 85...: String(localized: "Sterke week")
        case 60..<85: String(localized: "Goede week")
        case 30..<60: String(localized: "Op weg")
        default: String(localized: "Nieuwe kansen")
        }
    }
}
