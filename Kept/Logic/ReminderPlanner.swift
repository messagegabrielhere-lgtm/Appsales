import Foundation

struct PlannedReminder: Equatable {
    let habitID: UUID
    let day: DayKey
    /// Minutes after midnight.
    let minutes: Int
}

/// Decides which local notifications to schedule. iOS keeps at most 64 pending requests per
/// app, so reminders are scheduled as individual upcoming days rather than a repeating rule.
/// That also lets a day be skipped once the habit is already done, and rest days be skipped
/// entirely. The app re-plans on every change and every launch.
enum ReminderPlanner {
    static let pendingLimit = 60
    static let maxDaysAhead = 7

    static func plan(
        habits: [Habit],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = pendingLimit
    ) -> [PlannedReminder] {
        let withReminders = habits.filter { $0.reminderMinutes != nil }
        guard !withReminders.isEmpty else { return [] }
        let perHabit = max(1, min(maxDaysAhead, limit / withReminders.count))
        let today = DayKey(now, calendar: calendar)
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        var result: [PlannedReminder] = []
        for habit in withReminders {
            guard let minutes = habit.reminderMinutes else { continue }
            var scheduled = 0
            var offset = 0
            while scheduled < perHabit && offset < 28 {
                let day = today.adding(days: offset, calendar: calendar)
                offset += 1
                guard habit.isScheduled(on: day, calendar: calendar) else { continue }
                if habit.isCompleted(on: day) { continue }
                if day == today && minutes <= nowMinutes { continue }
                result.append(PlannedReminder(habitID: habit.id, day: day, minutes: minutes))
                scheduled += 1
            }
        }
        return result
    }
}
