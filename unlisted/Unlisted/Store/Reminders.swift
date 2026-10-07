import Foundation
import UserNotifications

/// Local notifications only. Text never includes names, so nothing personal
/// shows on the lock screen.
enum Reminders {
    static let weeklyScanID = "weekly-scan"

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func recheckID(_ broker: Broker, _ person: Person) -> String {
        "recheck-\(broker.id)-\(person.id.uuidString)"
    }

    static func scheduleRecheck(_ broker: Broker, for person: Person) {
        let content = UNMutableNotificationContent()
        content.title = "Time to re-check \(broker.name)"
        content.body = "People-search sites often re-list people. Open Unlisted to check again."
        content.sound = .default
        let seconds = TimeInterval(max(broker.recheckDays, 1)) * 86_400
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: recheckID(broker, person), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelRecheck(_ broker: Broker, for person: Person) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [recheckID(broker, person)])
    }

    static func setWeeklyScan(_ enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyScanID])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Weekly privacy check"
        content.body = "Run your searches again and see if anything new turned up."
        content.sound = .default
        var when = DateComponents()
        when.weekday = 2 // Monday
        when.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: weeklyScanID, content: content, trigger: trigger))
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
