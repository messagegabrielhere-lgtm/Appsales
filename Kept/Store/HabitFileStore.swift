import Foundation

/// Reads and writes the habits file. Deliberately a plain value type with no `@Published`
/// state and no main-thread requirement, so the widget extension and App Intents (which run
/// off the main actor) can use it directly.
///
/// `HabitStore` wraps this for the app's UI. Nothing here touches the network; the file lives
/// in the shared App Group container so the app and widget see the same data.
enum HabitFileStore {
    /// Shared container when the App Group entitlement is present, otherwise the app's own
    /// Application Support folder (which is where 1.0 kept its data).
    static var fileURL: URL {
        if let container = AppGroup.containerURL {
            return container.appendingPathComponent("habits.json")
        }
        return legacyFileURL
    }

    static var legacyFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Kept", isDirectory: true)
            .appendingPathComponent("habits.json")
    }

    /// Never throws. A missing file reads as an empty list; a damaged one is moved aside and
    /// reads as empty, so the next save cannot overwrite data that might be recoverable.
    static func load(from url: URL = fileURL) -> [Habit] {
        JSONFile.loadArray(Habit.self, from: url)
    }

    @discardableResult
    static func save(_ habits: [Habit], to url: URL = fileURL) -> Bool {
        JSONFile.save(habits, to: url)
    }

    /// 1.0 stored the file in Application Support. Copy it into the shared container once.
    static func migrateLegacyFileIfNeeded(to url: URL = fileURL) {
        guard url != legacyFileURL else { return }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: url.path),
              manager.fileExists(atPath: legacyFileURL.path) else { return }
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? manager.copyItem(at: legacyFileURL, to: url)
    }

    /// Flips today's state for one habit and writes the result. Used by the widget's check
    /// buttons and by Siri, both of which run off the main actor.
    /// - Returns: the habit as it now stands, or nil if it no longer exists.
    @discardableResult
    static func toggle(habitID: UUID, on day: DayKey, at url: URL = fileURL) -> Habit? {
        var habits = load(from: url)
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return nil }
        habits[index].toggle(day)
        save(habits, to: url)
        return habits[index]
    }
}
