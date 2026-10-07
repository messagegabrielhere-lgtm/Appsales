import Combine
import Foundation
import WidgetKit

/// The app's observable view of its data files: the supplement and routine checklist, the
/// food, drink, activity and feeling log, and settings. Confined to the main actor because
/// SwiftUI observes it. All file work is delegated to plain stores that the widget and App
/// Intents also use directly from their own threads.
@MainActor
final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var settings = KeptSettings()
    @Published private(set) var estimates: [DailyEstimate] = []

    private let fileURL: URL?

    /// The log and settings live beside the habits file, so a store pointed at a temporary
    /// directory in tests never touches real data.
    private var logURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent(LogFileStore.fileName)
    }

    private var estimatesURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent(EstimateFileStore.fileName)
    }

    private var settingsURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent(SettingsFileStore.fileName)
    }

    /// - Parameter fileURL: the habits file. Pass `nil` for an in-memory store (previews, tests).
    init(fileURL: URL? = HabitFileStore.fileURL) {
        self.fileURL = fileURL
        if let fileURL {
            HabitFileStore.migrateLegacyFileIfNeeded(to: fileURL)
        }
        loadAll()
    }

    // MARK: Checklist

    func add(_ habit: Habit) {
        habits.append(habit)
        saveHabits()
    }

    func update(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        saveHabits()
    }

    func delete(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        saveHabits()
    }

    func delete(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
        saveHabits()
    }

    func move(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        saveHabits()
    }

    func toggle(_ habit: Habit, on day: DayKey) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].toggle(day)
        saveHabits()
    }

    func habit(id: UUID) -> Habit? {
        habits.first { $0.id == id }
    }

    // MARK: Log

    func addEntry(_ entry: LogEntry) {
        log.append(entry)
        log.sort { $0.date < $1.date }
        saveLog()
    }

    func updateEntry(_ entry: LogEntry) {
        guard let index = log.firstIndex(where: { $0.id == entry.id }) else { return }
        log[index] = entry
        log.sort { $0.date < $1.date }
        saveLog()
    }

    func deleteEntry(_ entry: LogEntry) {
        log.removeAll { $0.id == entry.id }
        saveLog()
    }

    /// One glass at the user's chosen size, timed now or at this time of day on a past day.
    func addWater(on day: DayKey) {
        addEntry(LogEntry(
            kind: .drink,
            date: LogInsights.defaultDate(for: day),
            text: "Water",
            milliliters: settings.glassMilliliters
        ))
    }

    /// Adds a typed or pasted list as untimed entries, in the order written, after any untimed
    /// entries already on each day. Ticks the checklist items lines refer to when asked.
    /// Returns how many entries were added.
    @discardableResult
    func addList(_ days: [BulkEntryParser.Day], tickChecklist: Bool) -> Int {
        var added: [LogEntry] = []
        var habitsChanged = false
        for parsed in days {
            var index = entries(on: parsed.day).filter(\.untimed).count
            for item in parsed.items {
                added.append(LogEntry(
                    kind: item.kind,
                    date: LogEntry.untimedDate(on: parsed.day, index: index),
                    text: item.text,
                    milliliters: item.kind == .drink ? item.milliliters : nil,
                    minutes: item.kind == .activity ? item.minutes : nil,
                    untimed: true
                ))
                index += 1
                if tickChecklist, let id = item.habitID,
                   let habitIndex = habits.firstIndex(where: { $0.id == id }),
                   !habits[habitIndex].isCompleted(on: parsed.day) {
                    habits[habitIndex].completions.insert(parsed.day)
                    habitsChanged = true
                }
            }
        }
        guard !added.isEmpty else { return 0 }
        log.append(contentsOf: added)
        log.sort { $0.date < $1.date }
        saveLog()
        if habitsChanged { saveHabits() }
        return added.count
    }

    /// Combines a Fuelprint backup with what's here. Takes the backup's profile only when this
    /// device has none. Returns what was added.
    @discardableResult
    func merge(_ backup: KeptBackup) -> BackupMerge.Result {
        let result = BackupMerge.merge(habits: habits, log: log, backupHabits: backup.habits, backupLog: backup.log)
        if let backupEstimates = backup.estimates {
            let known = Set(estimates.map(\.day))
            saveEstimates(backupEstimates.filter { !known.contains($0.day) })
        }
        if result.addedHabits + result.addedTicks > 0 {
            habits = result.habits
            saveHabits()
        }
        if result.addedEntries > 0 {
            log = result.log
            saveLog()
        }
        if !settings.hasAboutMe && backup.settings.hasAboutMe {
            var updated = settings
            updated.profile = backup.settings.profile
            updated.aboutMe = backup.settings.aboutMe
            updateSettings(updated)
        }
        return result
    }

    func entries(on day: DayKey) -> [LogEntry] {
        LogInsights.entries(on: day, in: log)
    }

    func waterMilliliters(on day: DayKey) -> Int {
        LogInsights.waterMilliliters(on: day, in: log)
    }

    func recents(for kind: LogKind) -> [String] {
        LogInsights.recents(kind: kind, in: log)
    }

    // MARK: AI estimates

    /// Saves estimates pasted back from an AI answer; a newer estimate for a day replaces the
    /// older one. Returns how many days were saved.
    @discardableResult
    func saveEstimates(_ new: [DailyEstimate]) -> Int {
        guard !new.isEmpty else { return 0 }
        var byDay = Dictionary(uniqueKeysWithValues: estimates.map { ($0.day, $0) })
        for estimate in new { byDay[estimate.day] = estimate }
        estimates = byDay.values.sorted { $0.day < $1.day }
        if let estimatesURL { EstimateFileStore.save(estimates, to: estimatesURL) }
        return new.count
    }

    func deleteEstimates() {
        estimates = []
        if let estimatesURL { EstimateFileStore.save([], to: estimatesURL) }
    }

    // MARK: Settings

    func updateSettings(_ newValue: KeptSettings) {
        settings = newValue
        guard let settingsURL else { return }
        SettingsFileStore.save(settings, to: settingsURL)
    }

    // MARK: Persistence

    /// Re-reads every file. Called when the app becomes active and when a widget button or Siri
    /// writes from inside the app's process, so the open store never overwrites their changes.
    func reloadFromDisk() {
        loadAll()
    }

    private func loadAll() {
        guard let fileURL, let logURL, let settingsURL else { return }
        let loadedHabits = HabitFileStore.load(from: fileURL)
        if loadedHabits != habits { habits = loadedHabits }
        let loadedLog = LogFileStore.load(from: logURL)
        if loadedLog != log { log = loadedLog }
        let loadedSettings = SettingsFileStore.load(from: settingsURL)
        if loadedSettings != settings { settings = loadedSettings }
        if let estimatesURL {
            let loadedEstimates = EstimateFileStore.load(from: estimatesURL)
            if loadedEstimates != estimates { estimates = loadedEstimates }
        }
    }

    private func saveHabits() {
        guard let fileURL else { return }
        HabitFileStore.save(habits, to: fileURL)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveLog() {
        guard let logURL else { return }
        LogFileStore.save(log, to: logURL)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Previews and screenshots

    static func preview() -> HabitStore {
        let store = HabitStore(fileURL: nil)
        store.habits = HabitStore.demoHabits()
        store.log = HabitStore.demoLog()
        store.estimates = HabitStore.demoEstimates()
        var settings = KeptSettings()
        settings.profile.age = "34"
        settings.profile.sex = "Female"
        settings.profile.height = "5 ft 6 in"
        settings.profile.weight = "150 lb"
        settings.profile.activityLevel = "Run three times a week"
        settings.profile.goals = "Steady energy through the afternoon, better sleep"
        settings.profile.diet = "Mostly whole foods, high protein"
        settings.hasOnboarded = true
        settings.acceptedAIDisclaimer = true
        store.settings = settings
        return store
    }

    /// Sample checklist for previews, the widget gallery, and screenshots.
    nonisolated static func demoHabits() -> [Habit] {
        let today = DayKey.today()
        let longAgo = Calendar.current.date(byAdding: .day, value: -400, to: Date()) ?? Date()

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
            Habit(name: "Vitamin D", emoji: "☀️", colorName: "yellow", createdAt: longAgo,
                  completions: days(count: 330, hitRate: 100, skipping: [12, 40, 41, 75, 110, 150, 151, 200, 260, 300]),
                  reminderMinutes: 8 * 60, dose: "2000 IU"),
            Habit(name: "Creatine", emoji: "💪", colorName: "purple", createdAt: longAgo,
                  completions: days(count: 220, hitRate: 85)),
            Habit(name: "Omega-3", emoji: "🐟", colorName: "blue", createdAt: longAgo,
                  completions: days(count: 200, hitRate: 70, skipping: [0]), dose: "1 g"),
            Habit(name: "Magnesium", emoji: "😴", colorName: "indigo", createdAt: longAgo,
                  completions: days(count: 260, hitRate: 90, skipping: [0]),
                  reminderMinutes: 21 * 60 + 30, dose: "400 mg"),
            Habit(name: "Walk 20 minutes", emoji: "🚶", colorName: "green", createdAt: longAgo,
                  completions: days(count: 120, hitRate: 75, skipping: [0])),
        ]
    }

    /// Six weeks of estimates for the Trends screenshot.
    nonisolated static func demoEstimates() -> [DailyEstimate] {
        let today = DayKey.today()
        return (1...42).map { offset in
            let wave = Double((offset * 37) % 11) - 5
            return DailyEstimate(
                day: today.adding(days: -offset),
                calories: Int(2250 - Double(offset) * 4 + wave * 40),
                proteinGrams: Int(105 + Double(42 - offset) * 0.9 + wave * 3),
                carbsGrams: 220, fatGrams: 80,
                fiberGrams: Int(18 + Double(42 - offset) * 0.2 + wave),
                savedAt: Date()
            )
        }.sorted { $0.day < $1.day }
    }

    /// A week of realistic entries.
    nonisolated static func demoLog() -> [LogEntry] {
        let calendar = Calendar.current
        let today = DayKey.today()

        func at(_ offset: Int, _ hour: Int, _ minute: Int) -> Date {
            let start = today.adding(days: -offset).date()
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
        }

        var entries: [LogEntry] = []
        for offset in 0..<7 {
            let pattern = offset % 3
            entries.append(LogEntry(kind: .food, date: at(offset, 7, 45),
                                    text: pattern == 1 ? "Two eggs, sourdough toast, avocado" : "Greek yogurt with berries and granola",
                                    amount: "1 bowl"))
            entries.append(LogEntry(kind: .drink, date: at(offset, 8, 5), text: "Flat white", milliliters: 240))
            entries.append(LogEntry(kind: .drink, date: at(offset, 10, 30), text: "Water", milliliters: 500))
            entries.append(LogEntry(kind: .food, date: at(offset, 12, 45),
                                    text: pattern == 2 ? "Pizza, two slices" : "Chicken and avocado wrap"))
            entries.append(LogEntry(kind: .drink, date: at(offset, 13, 0), text: "Water", milliliters: 330))
            if pattern == 2 {
                entries.append(LogEntry(kind: .drink, date: at(offset, 15, 0), text: "Cola", milliliters: 330))
                entries.append(LogEntry(kind: .feeling, date: at(offset, 16, 0), text: "Afternoon crash, foggy", rating: 2))
            } else {
                entries.append(LogEntry(kind: .food, date: at(offset, 15, 30), text: "Apple and a handful of almonds"))
                entries.append(LogEntry(kind: .feeling, date: at(offset, 16, 0), text: "Steady, focused", rating: 4))
            }
            if offset != 0 {
                entries.append(LogEntry(kind: .activity, date: at(offset, 18, 15),
                                        text: pattern == 1 ? "Strength training, upper body" : "Run, easy pace",
                                        minutes: pattern == 1 ? 45 : 35))
                entries.append(LogEntry(kind: .food, date: at(offset, 19, 30), text: "Salmon, rice and broccoli", amount: "1 plate"))
                entries.append(LogEntry(kind: .drink, date: at(offset, 19, 35), text: "Water", milliliters: 500))
                entries.append(LogEntry(kind: .feeling, date: at(offset, 21, 45),
                                        text: pattern == 2 ? "Wired, slept badly" : "Relaxed, sleepy",
                                        rating: pattern == 2 ? 2 : 4))
            }
        }
        return entries.sorted { $0.date < $1.date }
    }
}
