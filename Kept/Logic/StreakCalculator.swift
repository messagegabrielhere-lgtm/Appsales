import Foundation

/// Pure functions over a set of completed days. No dates are read from the system here;
/// callers pass `today` in, which keeps this logic fully unit-testable.
enum StreakCalculator {
    /// Consecutive completed days ending today. If today is not done yet, the streak that
    /// ended yesterday still counts, so a user is not shown "0" before they've had a chance
    /// to check in.
    static func currentStreak(_ completions: Set<DayKey>, today: DayKey, calendar: Calendar = .current) -> Int {
        var cursor = today
        if !completions.contains(cursor) {
            cursor = cursor.adding(days: -1, calendar: calendar)
            guard completions.contains(cursor) else { return 0 }
        }
        var count = 0
        while completions.contains(cursor) {
            count += 1
            cursor = cursor.adding(days: -1, calendar: calendar)
        }
        return count
    }

    /// The longest run of consecutive completed days ever recorded.
    static func longestStreak(_ completions: Set<DayKey>, calendar: Calendar = .current) -> Int {
        var best = 0
        var run = 0
        var previous: DayKey?
        for day in completions.sorted() {
            if let previous, previous.adding(days: 1, calendar: calendar) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Fraction (0...1) of the last `days` days, counting back from and including `today`,
    /// that were completed.
    static func completionRate(_ completions: Set<DayKey>, today: DayKey, days: Int, calendar: Calendar = .current) -> Double {
        guard days > 0 else { return 0 }
        var done = 0
        for offset in 0..<days where completions.contains(today.adding(days: -offset, calendar: calendar)) {
            done += 1
        }
        return Double(done) / Double(days)
    }
}
