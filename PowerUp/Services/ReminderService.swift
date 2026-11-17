import Foundation
import UserNotifications

/// Lokale meldingen: een trainingsherinnering op gekozen dagen en het weekoverzicht op maandag.
/// Er gaat niets via een server; alles staat op het toestel.
@MainActor
enum ReminderService {
    private static let trainingPrefix = "training-"
    private static let recapID = "weekly-recap"

    /// Vraagt toestemming als dat nog niet gebeurd is. Geeft terug of meldingen mogen.
    static func ensurePermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Zet de meldingen opnieuw klaar volgens het profiel.
    static func reschedule(profile: UserProfile) async {
        let center = UNUserNotificationCenter.current()
        let ids = (1...7).map { "\(trainingPrefix)\($0)" } + [recapID]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        if profile.reminderEnabled {
            for weekday in profile.reminderWeekdays {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Tijd om te trainen")
                content.body = String(localized: "Je volgende training staat klaar. Even kijken?")
                content.sound = .default
                var components = DateComponents()
                components.weekday = weekday
                components.hour = profile.reminderHour
                components.minute = profile.reminderMinute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: "\(trainingPrefix)\(weekday)",
                                                            content: content, trigger: trigger))
            }
        }
        if profile.recapReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Je weekoverzicht staat klaar")
            content.body = String(localized: "Bekijk je score en je focus voor deze week.")
            content.sound = .default
            var components = DateComponents()
            components.weekday = 2
            components.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: recapID, content: content, trigger: trigger))
        }
    }

    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }
}
