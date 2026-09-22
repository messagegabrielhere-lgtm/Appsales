import AppIntents

/// Registers "Mark <habit> done in Kept" with Siri and the Shortcuts app.
struct KeptShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Mark \(\.$habit) done in \(.applicationName)",
                "Log \(\.$habit) in \(.applicationName)",
                "I did \(\.$habit) in \(.applicationName)",
            ],
            shortTitle: "Mark habit done",
            systemImageName: "checkmark.circle"
        )
    }
}
