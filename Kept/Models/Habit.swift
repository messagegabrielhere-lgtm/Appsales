import Foundation

/// One daily habit and the set of days it was completed on.
struct Habit: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var colorName: String
    var createdAt: Date
    var completions: Set<DayKey>

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "✅",
        colorName: String = "teal",
        createdAt: Date = Date(),
        completions: Set<DayKey> = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorName = colorName
        self.createdAt = createdAt
        self.completions = completions
    }

    func isCompleted(on day: DayKey) -> Bool {
        completions.contains(day)
    }

    mutating func toggle(_ day: DayKey) {
        if completions.contains(day) {
            completions.remove(day)
        } else {
            completions.insert(day)
        }
    }
}
