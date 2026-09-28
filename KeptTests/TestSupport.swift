import Foundation
@testable import Kept

/// A fixed calendar so date math in tests never depends on the machine's time zone.
enum TestCalendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
        DayKey(year: year, month: month, day: day)
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KeptTests-\(UUID().uuidString)", isDirectory: true)
    }
}
