import Foundation

/// Pure functions over a set of completed days. Callers pass `today` in, which keeps this
/// fully unit-testable. Days outside `schedule` are rest days: they are skipped when walking
/// a streak, so they neither count toward it nor break it.
enum StreakCalculator {
    /// Consecutive scheduled days completed, ending today. If today is not done yet, the run
    /// that ended on the previous scheduled day still counts, so nobody sees a zero before
    /// they've had a chance to check in.
    static func currentStreak(
        _ completions: Set<DayKey>,
        today: DayKey,
        schedule: Set<Int> = Habit.everyDay,
        calendar: Calendar = .current
    ) -> Int {
        let schedule = schedule.isEmpty ? Habit.everyDay : schedule
        func isScheduled(_ day: DayKey) -> Bool { schedule.contains(day.weekday(calendar: calendar)) }
        func previousScheduled(_ day: DayKey) -> DayKey {
            var cursor = day.adding(days: -1, calendar: calendar)
            var steps = 0
            while !isScheduled(cursor) && steps < 7 {
                cursor = cursor.adding(days: -1, calendar: calendar)
                steps += 1
            }
            return cursor
        }

        var cursor = isScheduled(today) ? today : previousScheduled(today)
        if !completions.contains(cursor) {
            cursor = previousScheduled(cursor)
            guard completions.contains(cursor) else { return 0 }
        }
        var count = 0
        while completions.contains(cursor) {
            count += 1
            cursor = previousScheduled(cursor)
        }
        return count
    }

    /// The longest run of consecutive scheduled days ever completed.
    static func longestStreak(
        _ completions: Set<DayKey>,
        schedule: Set<Int> = Habit.everyDay,
        calendar: Calendar = .current
    ) -> Int {
        let schedule = schedule.isEmpty ? Habit.everyDay : schedule
        func isScheduled(_ day: DayKey) -> Bool { schedule.contains(day.weekday(calendar: calendar)) }
        func nextScheduled(_ day: DayKey) -> DayKey {
            var cursor = day.adding(days: 1, calendar: calendar)
            var steps = 0
            while !isScheduled(cursor) && steps < 7 {
                cursor = cursor.adding(days: 1, calendar: calendar)
                steps += 1
            }
            return cursor
        }

        var best = 0
        var run = 0
        var previous: DayKey?
        for day in completions.sorted() where isScheduled(day) {
            if let previous, nextScheduled(previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Fraction (0...1) of the scheduled days among the last `days` days, counting back from
    /// and including `today`, that were completed.
    static func completionRate(
        _ completions: Set<DayKey>,
        today: DayKey,
        days: Int,
        schedule: Set<Int> = Habit.everyDay,
        calendar: Calendar = .current
    ) -> Double {
        guard days > 0 else { return 0 }
        let schedule = schedule.isEmpty ? Habit.everyDay : schedule
        var scheduled = 0
        var done = 0
        for offset in 0..<days {
            let day = today.adding(days: -offset, calendar: calendar)
            guard schedule.contains(day.weekday(calendar: calendar)) else { continue }
            scheduled += 1
            if completions.contains(day) { done += 1 }
        }
        return scheduled == 0 ? 0 : Double(done) / Double(scheduled)
    }
}
