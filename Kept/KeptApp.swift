import SwiftUI

@main
struct KeptApp: App {
    @StateObject private var store = HabitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
