import AppIntents
import Foundation
import WidgetKit

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
        let wanted = Set(identifiers)
        return HabitFileStore.load()
            .filter { wanted.contains($0.id) }
            .map(HabitEntity.init)
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        HabitFileStore.load().map(HabitEntity.init)
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
        HabitFileStore.toggle(habitID: habit.id, on: DayKey.today())
        WidgetCenter.shared.reloadAllTimelines()
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
        let today = DayKey.today()
        var habits = HabitFileStore.load()
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return .result(dialog: IntentDialog("I couldn't find that habit in Kept."))
        }
        if !habits[index].isCompleted(on: today) {
            habits[index].toggle(today)
            HabitFileStore.save(habits)
            WidgetCenter.shared.reloadAllTimelines()
        }
        let updated = habits[index]
        let streak = StreakCalculator.currentStreak(updated.completions, today: today, schedule: updated.schedule)
        return .result(dialog: IntentDialog("\(updated.name) done. That's a \(streak) day streak."))
    }
}
