import XCTest
@testable import Kept

final class ReminderPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Sunday September 20, 2026 at 08:00 UTC.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 8, minute: 0))!
    }

    func testNoRemindersWhenNoneConfigured() {
        let habits = [Habit(name: "Water")]
        XCTAssertTrue(ReminderPlanner.plan(habits: habits, now: now, calendar: calendar).isEmpty)
    }

    func testSevenUpcomingDaysForDailyHabit() {
        let habit = Habit(name: "Water", reminderMinutes: 9 * 60)
        let plan = ReminderPlanner.plan(habits: [habit], now: now, calendar: calendar)
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.day, DayKey(year: 2026, month: 9, day: 20))
        XCTAssertEqual(plan.last?.day, DayKey(year: 2026, month: 9, day: 26))
        XCTAssertEqual(plan.first?.minutes, 9 * 60)
    }

    func testTodayIsSkippedWhenReminderTimeAlreadyPassed() {
        let habit = Habit(name: "Water", reminderMinutes: 7 * 60)
        let plan = ReminderPlanner.plan(habits: [habit], now: now, calendar: calendar)
        XCTAssertEqual(plan.first?.day, DayKey(year: 2026, month: 9, day: 21))
    }

    func testCompletedDaysAreSkipped() {
        let today = DayKey(year: 2026, month: 9, day: 20)
        let habit = Habit(name: "Water", completions: [today], reminderMinutes: 9 * 60)
        let plan = ReminderPlanner.plan(habits: [habit], now: now, calendar: calendar)
        XCTAssertFalse(plan.contains { $0.day == today })
    }

    func testRestDaysAreSkipped() {
        let habit = Habit(name: "Read", scheduledWeekdays: Habit.weekdays, reminderMinutes: 20 * 60)
        let plan = ReminderPlanner.plan(habits: [habit], now: now, calendar: calendar)
        XCTAssertEqual(plan.first?.day, DayKey(year: 2026, month: 9, day: 21))
        XCTAssertTrue(plan.allSatisfy { habit.isScheduled(on: $0.day, calendar: calendar) })
    }

    func testTotalStaysUnderTheSystemLimit() {
        let habits = (0..<20).map { Habit(name: "Habit \($0)", reminderMinutes: 9 * 60) }
        let plan = ReminderPlanner.plan(habits: habits, now: now, calendar: calendar)
        XCTAssertLessThanOrEqual(plan.count, ReminderPlanner.pendingLimit)
        XCTAssertGreaterThan(plan.count, 0)
    }
}
