import Foundation

/// A single calendar day (year, month, day) with no time-of-day or time zone attached.
///
/// Habit completions are stored as `DayKey`s so that a check-in made at 11:59 PM stays on
/// that day no matter what time zone the device is in later. Encoded as `"yyyy-MM-dd"`.
struct DayKey: Hashable, Codable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    static func today(calendar: Calendar = .current) -> DayKey {
        DayKey(Date(), calendar: calendar)
    }

    /// Midnight at the start of this day in the given calendar.
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        let base = date(calendar: calendar)
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        return DayKey(shifted, calendar: calendar)
    }

    func adding(months: Int, calendar: Calendar = .current) -> DayKey {
        let base = firstOfMonth.date(calendar: calendar)
        let shifted = calendar.date(byAdding: .month, value: months, to: base) ?? base
        return DayKey(shifted, calendar: calendar)
    }

    var firstOfMonth: DayKey {
        DayKey(year: year, month: month, day: 1)
    }

    /// Calendar weekday number: 1 = Sunday through 7 = Saturday in the Gregorian calendar.
    func weekday(calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date(calendar: calendar))
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Codable ("yyyy-MM-dd")

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid DayKey: \(raw)")
            )
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
