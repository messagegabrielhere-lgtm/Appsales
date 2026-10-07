import AppIntents

/// Registers Kept's phrases with Siri and the Shortcuts app.
struct KeptShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddLogEntryIntent(),
            phrases: [
                "Log \(\.$kind) in \(.applicationName)",
                "Add \(\.$kind) to \(.applicationName)",
                "Log a meal in \(.applicationName)",
            ],
            shortTitle: "Log an entry",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: LogDayIntent(),
            phrases: [
                "Tell \(.applicationName) what I ate",
                "Log my day in \(.applicationName)",
                "Tell \(.applicationName) what I had",
            ],
            shortTitle: "Log several things",
            systemImageName: "mic"
        )
        AppShortcut(
            intent: AddWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add a glass of water in \(.applicationName)",
            ],
            shortTitle: "Add water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Mark \(\.$habit) done in \(.applicationName)",
                "I took \(\.$habit) in \(.applicationName)",
            ],
            shortTitle: "Check off",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: GetAIPromptIntent(),
            phrases: [
                "Get my \(.applicationName) AI prompt",
                "Get my \(\.$question) prompt from \(.applicationName)",
            ],
            shortTitle: "AI prompt",
            systemImageName: "sparkles"
        )
    }
}
