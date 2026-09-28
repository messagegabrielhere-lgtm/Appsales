import Foundation

/// Pure queries over the log. No stored state, so everything here is unit-tested directly.
enum LogInsights {
    static func entries(on day: DayKey, in log: [LogEntry], calendar: Calendar = .current) -> [LogEntry] {
        log.filter { $0.day(calendar: calendar) == day }.sorted { $0.date < $1.date }
    }

    static func waterMilliliters(of entries: [LogEntry]) -> Int {
        entries.filter(\.isWater).reduce(0) { $0 + ($1.milliliters ?? 0) }
    }

    static func waterMilliliters(on day: DayKey, in log: [LogEntry], calendar: Calendar = .current) -> Int {
        waterMilliliters(of: entries(on: day, in: log, calendar: calendar))
    }

    /// Distinct texts of this kind, most recently used first. People eat the same breakfast
    /// most days, so these turn a typed entry into a single tap.
    static func recents(kind: LogKind, in log: [LogEntry], limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in log.sorted(by: { $0.date > $1.date }) where entry.kind == kind {
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if seen.insert(text.lowercased()).inserted {
                result.append(text)
                if result.count == limit { break }
            }
        }
        return result
    }

    /// When a new entry should default to. Today means now; a past day means the same time of
    /// day on that day, which is what someone filling in yesterday usually wants.
    static func defaultDate(for day: DayKey, now: Date = Date(), calendar: Calendar = .current) -> Date {
        if day == DayKey(now, calendar: calendar) { return now }
        let clock = calendar.dateComponents([.hour, .minute], from: now)
        let start = day.date(calendar: calendar)
        return calendar.date(
            bySettingHour: clock.hour ?? 12,
            minute: clock.minute ?? 0,
            second: 0,
            of: start
        ) ?? start
    }

    /// Days to list in History, newest first, from today back to the first day with any data.
    static func historyDays(
        habits: [Habit],
        log: [LogEntry],
        today: DayKey,
        limit: Int = 365,
        calendar: Calendar = .current
    ) -> [DayKey] {
        var candidates: [DayKey] = log.map { $0.day(calendar: calendar) }
        for habit in habits {
            candidates.append(DayKey(habit.createdAt, calendar: calendar))
            if let first = habit.completions.min() { candidates.append(first) }
        }
        let earliest = candidates.min() ?? today
        var days: [DayKey] = []
        var cursor = today
        while days.count < limit {
            days.append(cursor)
            if cursor <= earliest { break }
            cursor = cursor.adding(days: -1, calendar: calendar)
        }
        return days
    }
}
