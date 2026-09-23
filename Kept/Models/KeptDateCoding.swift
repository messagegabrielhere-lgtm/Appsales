import Foundation

/// How dates are written to the habits file, and the resolution a `Habit` therefore keeps.
///
/// Foundation's plain `.iso8601` strategy writes whole seconds, and even with fractional
/// seconds the format stores milliseconds while `Date()` carries far finer precision. Either
/// way a `Date` does not survive a round trip unchanged, so a saved habit never compared
/// equal to the one it was built from.
///
/// The fix has two halves. Encoding keeps fractional seconds, and `Habit` canonicalises its
/// `createdAt` through `canonical(_:)` on the way in. A habit therefore always equals its own
/// saved-and-loaded self, which is what `HabitStore.reloadFromDisk()` relies on to tell a real
/// change from a no-op.
enum KeptDateCoding {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Files written by version 1.0 have no fractional part.
    static let wholeSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        fractional.string(from: date)
    }

    static func date(from raw: String) -> Date? {
        fractional.date(from: raw) ?? wholeSeconds.date(from: raw)
    }

    /// The date as it will read back after a save. Defined as an actual round trip rather than
    /// arithmetic, so it stays correct if the format ever changes.
    static func canonical(_ date: Date) -> Date {
        self.date(from: string(from: date)) ?? date
    }
}
