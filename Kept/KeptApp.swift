import SwiftUI

@main
struct KeptApp: App {
    @StateObject private var store = KeptApp.makeStore()
    @StateObject private var purchases = Purchases()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(purchases)
        }
    }

    /// Launching with the `-demo` argument (used by scripts/screenshots.sh) shows sample data
    /// in memory without touching the real data files. `-fresh` (used by the UI tests) starts
    /// as a brand-new user, also in memory.
    @MainActor
    private static func makeStore() -> HabitStore {
        if CommandLine.arguments.contains("-demo") {
            return HabitStore.preview()
        }
        if CommandLine.arguments.contains("-fresh") {
            return HabitStore(fileURL: nil)
        }
        return HabitStore()
    }
}
