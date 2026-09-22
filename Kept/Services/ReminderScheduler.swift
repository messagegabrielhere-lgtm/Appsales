import Foundation
import UserNotifications

/// Thin wrapper over UNUserNotificationCenter. All decisions about which days to schedule live
/// in `ReminderPlanner`, which is pure and unit-tested.
enum ReminderScheduler {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Replaces every pending reminder with a fresh plan. Cheap enough to call on every change.
    static func refresh(habits: [Habit], calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let plan = ReminderPlanner.plan(habits: habits, now: Date(), calendar: calendar)
        guard !plan.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })

        for item in plan {
            guard let habit = byID[item.habitID] else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(habit.emoji) \(habit.name)"
            content.body = "Keep the streak going. Tap to check in."
            content.sound = .default
            content.userInfo = ["habitID": habit.id.uuidString]

            var components = DateComponents()
            components.year = item.day.year
            components.month = item.day.month
            components.day = item.day.day
            components.hour = item.minutes / 60
            components.minute = item.minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "\(habit.id.uuidString)-\(item.day.description)"
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }
}
