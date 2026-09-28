import XCTest
@testable import Kept

final class LogInsightsTests: XCTestCase {
    private let calendar = TestCalendar.utc

    func testEntriesOnADayAreFilteredAndSorted() {
        let log = [
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 19), text: "Dinner"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 20, 8), text: "Next day"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 8), text: "Breakfast"),
        ]
        let day = LogInsights.entries(on: TestCalendar.day(2026, 9, 19), in: log, calendar: calendar)
        XCTAssertEqual(day.map(\.text), ["Breakfast", "Dinner"])
    }

    func testWaterCountsOnlyWaterDrinks() {
        let log = [
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 19, 8), text: "Water", milliliters: 500),
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 19, 9), text: "Sparkling water", milliliters: 330),
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 19, 10), text: "Coffee", milliliters: 240),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 11), text: "Watermelon"),
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 20, 8), text: "Water", milliliters: 1000),
        ]
        XCTAssertEqual(LogInsights.waterMilliliters(on: TestCalendar.day(2026, 9, 19), in: log, calendar: calendar), 830)
    }

    func testRecentsAreNewestFirstDistinctAndPerKind() {
        let log = [
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 1), text: "Oats"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 2), text: "Eggs"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 3), text: "oats"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 4), text: "   "),
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 5), text: "Water"),
        ]
        XCTAssertEqual(LogInsights.recents(kind: .food, in: log), ["oats", "Eggs"])
        XCTAssertEqual(LogInsights.recents(kind: .food, in: log, limit: 1), ["oats"])
        XCTAssertEqual(LogInsights.recents(kind: .drink, in: log), ["Water"])
        XCTAssertEqual(LogInsights.recents(kind: .activity, in: log), [])
    }

    func testDefaultDateIsNowTodayAndSameClockTimeOnPastDays() {
        let now = TestCalendar.date(2026, 9, 21, 14, 30)
        XCTAssertEqual(LogInsights.defaultDate(for: TestCalendar.day(2026, 9, 21), now: now, calendar: calendar), now)
        XCTAssertEqual(
            LogInsights.defaultDate(for: TestCalendar.day(2026, 9, 19), now: now, calendar: calendar),
            TestCalendar.date(2026, 9, 19, 14, 30)
        )
    }

    func testHistoryRunsFromTodayBackToFirstData() {
        let today = TestCalendar.day(2026, 9, 21)
        let log = [LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 18, 9), text: "Eggs")]
        XCTAssertEqual(
            LogInsights.historyDays(habits: [], log: log, today: today, calendar: calendar),
            [TestCalendar.day(2026, 9, 21), TestCalendar.day(2026, 9, 20), TestCalendar.day(2026, 9, 19), TestCalendar.day(2026, 9, 18)]
        )
        XCTAssertEqual(LogInsights.historyDays(habits: [], log: log, today: today, limit: 2, calendar: calendar).count, 2)
        XCTAssertEqual(LogInsights.historyDays(habits: [], log: [], today: today, calendar: calendar), [today])
    }
}
