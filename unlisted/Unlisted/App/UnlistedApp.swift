import SwiftUI

@main
struct UnlistedApp: App {
    @State private var store = LaunchOptions.current.demo ? AppStore.demo() : AppStore()

    var body: some Scene {
        WindowGroup {
            RootView(initialTab: LaunchOptions.current.tab)
                .environment(store)
        }
    }
}

/// Launch arguments used to take App Store screenshots:
/// `-demo` loads a fictional family; `-tab N` opens a tab.
struct LaunchOptions {
    var demo = false
    var tab = 0

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        demo = arguments.contains("-demo")
        if let index = arguments.firstIndex(of: "-tab"), index + 1 < arguments.count,
           let value = Int(arguments[index + 1]) {
            tab = value
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var showOnboarding = false
    @State private var tab: Int

    init(initialTab: Int = 0) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            ScanView()
                .tabItem { Label("Scan", systemImage: "magnifyingglass") }
                .tag(1)
            RemoveView()
                .tabItem { Label("Remove", systemImage: "eraser") }
                .tag(2)
            LettersView()
                .tabItem { Label("Letters", systemImage: "envelope") }
                .tag(3)
            ProtectView()
                .tabItem { Label("Protect", systemImage: "lock.shield") }
                .tag(4)
        }
        .onAppear { showOnboarding = store.me == nil }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView { showOnboarding = false }
                .interactiveDismissDisabled()
        }
    }
}
