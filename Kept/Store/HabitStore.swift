import Foundation
import Combine
import WidgetKit

/// Owns the list of habits and persists it as a single JSON file in the shared App Group
/// container, so the widget reads and writes the same data. Everything stays on-device.
/// There is no network code anywhere in this app.
final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []

    private let fileURL: URL?

    /// - Parameter fileURL: where to persist. Pass `nil` for an in-memory store (previews, tests).
    init(fileURL: URL? = HabitStore.defaultFileURL) {
        self.fileURL = fileURL
        migrateLegacyFileIfNeeded()
        load()
    }

    /// Shared container when the App Group entitlement is present, otherwise the app's own
    /// Application Support folder (which is where 1.0 kept its data).
    static var defaultFileURL: URL {
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

    // MARK: Mutations

    func add(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    func update(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        save()
    }

    func delete(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func toggle(_ habit: Habit, on day: DayKey) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].toggle(day)
        save()
    }

    func habit(id: UUID) -> Habit? {
        habits.first { $0.id == id }
    }

    /// Re-reads the file. The app calls this when it becomes active, because the widget or a
    /// Siri shortcut may have changed the data while the app was in the background.
    func reloadFromDisk() {
        load()
    }

    // MARK: Persistence

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        do {
            let loaded = try JSONDecoder.kept.decode([Habit].self, from: data)
            if loaded != habits {
                habits = loaded
            }
        } catch {
            // A corrupt file should not brick the app. Start empty; the next save overwrites it.
            habits = []
        }
    }

    private func save() {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.kept.encode(habits)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Kept: failed to save habits: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 1.0 stored the file in Application Support. Copy it into the shared container once.
    private func migrateLegacyFileIfNeeded() {
        guard let url = fileURL, url != HabitStore.legacyFileURL else { return }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: url.path), manager.fileExists(atPath: HabitStore.legacyFileURL.path) else { return }
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? manager.copyItem(at: HabitStore.legacyFileURL, to: url)
    }

    // MARK: Previews and screenshots

    static func preview() -> HabitStore {
        let store = HabitStore(fileURL: nil)
        let today = DayKey.today()
        func days(_ offsets: [Int]) -> Set<DayKey> { Set(offsets.map { today.adding(days: -$0) }) }
        store.habits = [
            Habit(name: "Drink water", emoji: "💧", colorName: "blue",
                  completions: days(Array(0..<12) + Array(14..<40)), reminderMinutes: 9 * 60),
            Habit(name: "Walk 20 minutes", emoji: "🚶", colorName: "green",
                  completions: days([1, 2, 3, 4, 6, 7, 8, 10, 11, 13, 15, 16, 17, 18, 20, 22, 23])),
            Habit(name: "Read 10 pages", emoji: "📚", colorName: "orange",
                  completions: days([0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13, 14, 16, 17, 19, 20, 21, 22, 24, 26]),
                  scheduledWeekdays: Habit.weekdays, reminderMinutes: 21 * 60 + 30),
            Habit(name: "Meditate", emoji: "🧘", colorName: "purple",
                  completions: days([1, 3, 5, 8, 9, 12])),
            Habit(name: "No phone in bed", emoji: "📵", colorName: "indigo",
                  completions: days([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20])),
        ]
        return store
    }
}

extension JSONEncoder {
    static var kept: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var kept: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
