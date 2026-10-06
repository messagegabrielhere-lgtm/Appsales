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
        NotificationCenter.default.post(name: .keptDataChanged, object: nil)
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
            return .result(dialog: IntentDialog("I couldn't find that habit in \(Brand.name)."))
        }
        if !habits[index].isCompleted(on: today) {
            habits[index].toggle(today)
            HabitFileStore.save(habits)
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: .keptDataChanged, object: nil)
        }
        let updated = habits[index]
        let streak = StreakCalculator.currentStreak(updated.completions, today: today, schedule: updated.schedule)
        return .result(dialog: IntentDialog("\(updated.name) done. That's a \(streak) day streak."))
    }
}

// MARK: Logging

/// The four entry kinds, as Siri and Shortcuts see them.
enum LogKindAppEnum: String, AppEnum {
    case food
    case drink
    case activity
    case feeling

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Entry Type"

    static var caseDisplayRepresentations: [LogKindAppEnum: DisplayRepresentation] = [
        .food: "food",
        .drink: "drink",
        .activity: "activity",
        .feeling: "feeling",
    ]

    var logKind: LogKind {
        LogKind(rawValue: rawValue) ?? .food
    }
}

/// "Log food in Fuelprint", then Siri asks what you had. The fastest possible way to log.
struct AddLogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Entry"
    static var description = IntentDescription("Adds food, a drink, activity or how you feel to today's log.")
    static var openAppWhenRun = false

    @Parameter(title: "Type", default: .food)
    var kind: LogKindAppEnum

    @Parameter(title: "Entry", requestValueDialog: IntentDialog("What should I log?"))
    var text: String

    init() {}

    init(kind: LogKindAppEnum, text: String) {
        self.kind = kind
        self.text = text
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: IntentDialog("There was nothing to log."))
        }
        let logKind = kind.logKind
        let settings = SettingsFileStore.load()
        let entry = LogEntry(
            kind: logKind,
            date: Date(),
            text: trimmed,
            milliliters: logKind == .drink && trimmed.localizedCaseInsensitiveContains("water") ? settings.glassMilliliters : nil
        )
        LogFileStore.append(entry)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .keptDataChanged, object: nil)
        return .result(dialog: IntentDialog("Logged \(logKind.title.lowercased()): \(trimmed)."))
    }
}

/// One glass of water. Backs the widget's water button and "Log water in Fuelprint".
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a Glass of Water"
    static var description = IntentDescription("Adds one glass of water to today's log.")
    static var openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let settings = SettingsFileStore.load()
        let entry = LogEntry(kind: .drink, date: Date(), text: "Water", milliliters: settings.glassMilliliters)
        let log = LogFileStore.append(entry)
        let total = LogInsights.waterMilliliters(on: DayKey.today(), in: log)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .keptDataChanged, object: nil)
        let glass = VolumeFormat.string(milliliters: settings.glassMilliliters)
        let today = VolumeFormat.string(milliliters: total)
        return .result(dialog: IntentDialog("Added \(glass) of water. That's \(today) today."))
    }
}
