import Combine
import Foundation
import WidgetKit

/// The app's observable view of the habits file. Confined to the main actor because SwiftUI
/// observes it; all file work is delegated to `HabitFileStore`, which the widget and App
/// Intents use directly from their own threads.
@MainActor
final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []

    private let fileURL: URL?

    /// - Parameter fileURL: where to persist. Pass `nil` for an in-memory store (previews, tests).
    init(fileURL: URL? = HabitFileStore.fileURL) {
        self.fileURL = fileURL
        if let fileURL {
            HabitFileStore.migrateLegacyFileIfNeeded(to: fileURL)
            habits = HabitFileStore.load(from: fileURL)
        }
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
        guard let fileURL else { return }
        let loaded = HabitFileStore.load(from: fileURL)
        if loaded != habits {
            habits = loaded
        }
    }

    private func save() {
        guard let fileURL else { return }
        HabitFileStore.save(habits, to: fileURL)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Previews and screenshots

    static func preview() -> HabitStore {
        let store = HabitStore(fileURL: nil)
        store.habits = HabitStore.demoHabits()
        return store
    }

    /// Sample data for previews, the widget gallery, and screenshots.
    nonisolated static func demoHabits() -> [Habit] {
        let today = DayKey.today()

        /// Deterministic pseudo-random miss pattern so screenshots are reproducible.
        func days(count: Int, hitRate: Int, skipping explicit: Set<Int> = [], weekdaysOnly: Bool = false) -> Set<DayKey> {
            var result: Set<DayKey> = []
            for offset in 0..<count {
                if explicit.contains(offset) { continue }
                let noise = (offset &* 2_654_435_761) % 100
                if noise >= hitRate { continue }
                let day = today.adding(days: -offset)
                if weekdaysOnly && !Habit.weekdays.contains(day.weekday()) { continue }
                result.insert(day)
            }
            return result
        }

        return [
            Habit(name: "Drink water", emoji: "💧", colorName: "blue",
                  completions: days(count: 330, hitRate: 100, skipping: [12, 40, 41, 75, 110, 150, 151, 200, 260, 300]),
                  reminderMinutes: 9 * 60),
            Habit(name: "Walk 20 minutes", emoji: "🚶", colorName: "green",
                  completions: days(count: 220, hitRate: 62, skipping: [0])),
            Habit(name: "Read 10 pages", emoji: "📚", colorName: "orange",
                  completions: days(count: 260, hitRate: 88, weekdaysOnly: true),
                  scheduledWeekdays: Habit.weekdays, reminderMinutes: 21 * 60 + 30),
            Habit(name: "Meditate", emoji: "🧘", colorName: "purple",
                  completions: days(count: 90, hitRate: 35, skipping: [0])),
            Habit(name: "No phone in bed", emoji: "📵", colorName: "indigo",
                  completions: days(count: 45, hitRate: 100)),
        ]
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
