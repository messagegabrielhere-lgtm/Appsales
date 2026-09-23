import SwiftUI

@main
struct KeptApp: App {
    @StateObject private var store = KeptApp.makeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }

    /// Launching with the `-demo` argument (used by scripts/screenshots.sh) shows sample
    /// habits in memory without touching the real data file.
    @MainActor
    private static func makeStore() -> HabitStore {
        if CommandLine.arguments.contains("-demo") {
            return HabitStore.preview()
        }
        return HabitStore()
    }
}
