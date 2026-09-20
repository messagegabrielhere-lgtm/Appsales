import Foundation
import Combine

/// Owns the list of habits and persists it as a single JSON file in Application Support.
/// Everything stays on-device. There is no network code anywhere in this app.
final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []

    private let fileURL: URL?

    /// - Parameter fileURL: where to persist. Pass `nil` for an in-memory store (previews, tests).
    init(fileURL: URL? = HabitStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    static var defaultFileURL: URL {
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

    // MARK: Persistence

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        do {
            habits = try JSONDecoder.kept.decode([Habit].self, from: data)
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
    }

    // MARK: Previews

    static func preview() -> HabitStore {
        let store = HabitStore(fileURL: nil)
        let today = DayKey.today()
        store.habits = [
            Habit(name: "Drink water", emoji: "💧", colorName: "blue",
                  completions: Set((0..<5).map { today.adding(days: -$0) })),
            Habit(name: "Read 10 pages", emoji: "📚", colorName: "orange",
                  completions: Set([1, 2, 3, 5, 6].map { today.adding(days: -$0) })),
            Habit(name: "Stretch", emoji: "🧘", colorName: "purple"),
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
