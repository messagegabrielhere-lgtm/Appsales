import XCTest
@testable import Kept

final class StreakCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
        DayKey(year: year, month: month, day: day)
    }

    // MARK: currentStreak, every day

    func testNoCompletionsIsZero() {
        XCTAssertEqual(StreakCalculator.currentStreak([], today: day(2026, 9, 20), calendar: calendar), 0)
    }

    func testStreakEndingToday() {
        let done: Set<DayKey> = [day(2026, 9, 18), day(2026, 9, 19), day(2026, 9, 20)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 20), calendar: calendar), 3)
    }

    func testStreakEndingYesterdayStillCounts() {
        let done: Set<DayKey> = [day(2026, 9, 18), day(2026, 9, 19)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 20), calendar: calendar), 2)
    }

    func testStreakThatEndedTwoDaysAgoIsBroken() {
        let done: Set<DayKey> = [day(2026, 9, 17), day(2026, 9, 18)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 20), calendar: calendar), 0)
    }

    func testGapBreaksStreak() {
        let done: Set<DayKey> = [day(2026, 9, 15), day(2026, 9, 16), day(2026, 9, 18), day(2026, 9, 19), day(2026, 9, 20)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 20), calendar: calendar), 3)
    }

    func testStreakAcrossMonthAndYearBoundary() {
        let done: Set<DayKey> = [day(2025, 12, 30), day(2025, 12, 31), day(2026, 1, 1), day(2026, 1, 2)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 1, 2), calendar: calendar), 4)
    }

    // MARK: currentStreak, weekday schedule
    // September 2026: the 14th is a Monday, the 19th and 20th are the weekend.

    func testWeekendIsSkippedForWeekdayHabit() {
        let done: Set<DayKey> = [day(2026, 9, 14), day(2026, 9, 15), day(2026, 9, 16), day(2026, 9, 17), day(2026, 9, 18)]
        // Sunday the 20th: nothing expected today; Friday's run still stands.
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 20), schedule: Habit.weekdays, calendar: calendar), 5)
        // Monday the 21st, not done yet: grace continues from Friday.
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 21), schedule: Habit.weekdays, calendar: calendar), 5)
        // Monday the 21st done: six.
        XCTAssertEqual(StreakCalculator.currentStreak(done.union([day(2026, 9, 21)]), today: day(2026, 9, 21), schedule: Habit.weekdays, calendar: calendar), 6)
    }

    func testMissedWeekdayBreaksWeekdayStreak() {
        // Wednesday the 16th missed.
        let done: Set<DayKey> = [day(2026, 9, 14), day(2026, 9, 15), day(2026, 9, 17), day(2026, 9, 18)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 18), schedule: Habit.weekdays, calendar: calendar), 2)
    }

    func testCompletionOnRestDayDoesNotAffectStreak() {
        let done: Set<DayKey> = [day(2026, 9, 17), day(2026, 9, 18), day(2026, 9, 19)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 19), schedule: Habit.weekdays, calendar: calendar), 2)
    }

    func testEmptyScheduleMeansEveryDay() {
        let done: Set<DayKey> = [day(2026, 9, 19), day(2026, 9, 20)]
        XCTAssertEqual(StreakCalculator.currentStreak(done, today: day(2026, 9, 20), schedule: [], calendar: calendar), 2)
    }

    // MARK: longestStreak

    func testLongestStreakEmpty() {
        XCTAssertEqual(StreakCalculator.longestStreak([], calendar: calendar), 0)
    }

    func testLongestStreakPicksTheLongerRun() {
        let done: Set<DayKey> = [
            day(2026, 3, 1), day(2026, 3, 2),
            day(2026, 3, 10), day(2026, 3, 11), day(2026, 3, 12), day(2026, 3, 13),
            day(2026, 3, 20),
        ]
        XCTAssertEqual(StreakCalculator.longestStreak(done, calendar: calendar), 4)
    }

    func testLongestStreakHandlesLeapDay() {
        let done: Set<DayKey> = [day(2028, 2, 28), day(2028, 2, 29), day(2028, 3, 1)]
        XCTAssertEqual(StreakCalculator.longestStreak(done, calendar: calendar), 3)
    }

    func testLongestStreakBridgesWeekendForWeekdayHabit() {
        let done: Set<DayKey> = [day(2026, 9, 17), day(2026, 9, 18), day(2026, 9, 21), day(2026, 9, 22)]
        XCTAssertEqual(StreakCalculator.longestStreak(done, schedule: Habit.weekdays, calendar: calendar), 4)
        XCTAssertEqual(StreakCalculator.longestStreak(done, calendar: calendar), 2)
    }

    // MARK: completionRate

    func testCompletionRate() {
        let today = day(2026, 9, 20)
        let done: Set<DayKey> = [today, today.adding(days: -1, calendar: calendar), today.adding(days: -5, calendar: calendar)]
        XCTAssertEqual(StreakCalculator.completionRate(done, today: today, days: 10, calendar: calendar), 0.3, accuracy: 0.0001)
    }

    func testCompletionRateCountsOnlyScheduledDays() {
        // Sun 20 back to Mon 14: five weekdays, all done, two weekend days ignored.
        let done: Set<DayKey> = [day(2026, 9, 14), day(2026, 9, 15), day(2026, 9, 16), day(2026, 9, 17), day(2026, 9, 18)]
        XCTAssertEqual(StreakCalculator.completionRate(done, today: day(2026, 9, 20), days: 7, schedule: Habit.weekdays, calendar: calendar), 1.0, accuracy: 0.0001)
    }

    func testCompletionRateIgnoresDaysOutsideWindow() {
        let today = day(2026, 9, 20)
        let done: Set<DayKey> = [today.adding(days: -40, calendar: calendar)]
        XCTAssertEqual(StreakCalculator.completionRate(done, today: today, days: 30, calendar: calendar), 0)
    }

    func testCompletionRateZeroDaysIsZero() {
        XCTAssertEqual(StreakCalculator.completionRate([day(2026, 9, 20)], today: day(2026, 9, 20), days: 0, calendar: calendar), 0)
    }
}
