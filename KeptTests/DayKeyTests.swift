import XCTest
@testable import Kept

final class DayKeyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testCodableRoundTrip() throws {
        let original = DayKey(year: 2026, month: 9, day: 20)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"2026-09-20\"")
        let decoded = try JSONDecoder().decode(DayKey.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDecodingGarbageThrows() {
        let data = Data("\"not-a-date\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(DayKey.self, from: data))
    }

    func testAddingDaysCrossesMonth() {
        let end = DayKey(year: 2026, month: 1, day: 31).adding(days: 1, calendar: calendar)
        XCTAssertEqual(end, DayKey(year: 2026, month: 2, day: 1))
    }

    func testAddingNegativeDaysCrossesYear() {
        let start = DayKey(year: 2026, month: 1, day: 1).adding(days: -1, calendar: calendar)
        XCTAssertEqual(start, DayKey(year: 2025, month: 12, day: 31))
    }

    func testAddingMonthsClampsToFirstOfMonth() {
        let next = DayKey(year: 2026, month: 1, day: 31).adding(months: 1, calendar: calendar)
        XCTAssertEqual(next, DayKey(year: 2026, month: 2, day: 1))
    }

    func testOrdering() {
        XCTAssertLessThan(DayKey(year: 2025, month: 12, day: 31), DayKey(year: 2026, month: 1, day: 1))
        XCTAssertLessThan(DayKey(year: 2026, month: 1, day: 9), DayKey(year: 2026, month: 1, day: 10))
    }

    func testDateRoundTrip() {
        let key = DayKey(year: 2026, month: 9, day: 20)
        XCTAssertEqual(DayKey(key.date(calendar: calendar), calendar: calendar), key)
    }
}
