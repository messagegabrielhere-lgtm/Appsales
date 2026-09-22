import AppIntents
import Foundation

/// A habit as Siri, Shortcuts, and interactive widgets see it.
struct HabitEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitQuery()

    var id: UUID
    var name: String
    var emoji: String

    init(_ habit: Habit) {
        id = habit.id
        name = habit.name
        emoji = habit.emoji
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
}

struct HabitQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let habits = HabitStore().habits
        return identifiers.compactMap { id in
            habits.first { $0.id == id }.map { HabitEntity($0) }
        }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        HabitStore().habits.map { HabitEntity($0) }
    }
}

/// Used by the widget's check buttons. Flips today's state for the habit.
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"
    static var description = IntentDescription("Marks a habit done for today, or undoes it.")
    static var openAppWhenRun = false

    @Parameter(title: "Habit") var habit: HabitEntity

    init() {}

    init(habit: HabitEntity) {
        self.habit = habit
    }

    func perform() async throws -> some IntentResult {
        let store = HabitStore()
        if let target = store.habit(id: habit.id) {
            store.toggle(target, on: DayKey.today())
        }
        return .result()
    }
}

/// Used by Siri and the Shortcuts app. Marks the habit done; saying it twice is harmless.
struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Habit Done"
    static var description = IntentDescription("Marks a habit as done for today.")
    static var openAppWhenRun = false

    @Parameter(title: "Habit") var habit: HabitEntity

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = HabitStore()
        let today = DayKey.today()
        guard let target = store.habit(id: habit.id) else {
            return .result(dialog: IntentDialog("I couldn't find that habit in Kept."))
        }
        if !target.isCompleted(on: today) {
            store.toggle(target, on: today)
        }
        let completions = store.habit(id: habit.id)?.completions ?? []
        let streak = StreakCalculator.currentStreak(completions, today: today, schedule: target.schedule)
        let name = target.name
        return .result(dialog: IntentDialog("\(name) done. That's a \(streak) day streak."))
    }
}
