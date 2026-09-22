import Foundation

/// One habit, the days it applies to, an optional daily reminder, and the days it was done.
struct Habit: Identifiable, Codable, Equatable {
    static let everyDay: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]

    var id: UUID
    var name: String
    var emoji: String
    var colorName: String
    var createdAt: Date
    var completions: Set<DayKey>
    /// Calendar weekday numbers (1 = Sunday ... 7 = Saturday) the habit is expected on.
    /// Days outside the schedule are rest days: they never break a streak.
    var scheduledWeekdays: Set<Int>
    /// Minutes after midnight for the daily reminder, or nil for no reminder.
    var reminderMinutes: Int?

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "✅",
        colorName: String = "teal",
        createdAt: Date = Date(),
        completions: Set<DayKey> = [],
        scheduledWeekdays: Set<Int> = Habit.everyDay,
        reminderMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorName = colorName
        self.createdAt = createdAt
        self.completions = completions
        self.scheduledWeekdays = scheduledWeekdays
        self.reminderMinutes = reminderMinutes
    }

    /// The schedule with an empty set treated as every day, so a habit can never have no days.
    var schedule: Set<Int> {
        scheduledWeekdays.isEmpty ? Habit.everyDay : scheduledWeekdays
    }

    var isEveryDay: Bool {
        schedule.count == 7
    }

    func isScheduled(on day: DayKey, calendar: Calendar = .current) -> Bool {
        schedule.contains(day.weekday(calendar: calendar))
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

    // MARK: Codable (tolerates files written by 1.0, which lack the newer keys)

    private enum CodingKeys: String, CodingKey {
        case id, name, emoji, colorName, createdAt, completions, scheduledWeekdays, reminderMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        colorName = try container.decode(String.self, forKey: .colorName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completions = try container.decode(Set<DayKey>.self, forKey: .completions)
        scheduledWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .scheduledWeekdays) ?? Habit.everyDay
        reminderMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderMinutes)
    }
}
