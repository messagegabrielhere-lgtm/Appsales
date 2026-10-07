import Combine
import SwiftUI

/// Three tabs: log the day, look back, ask an AI about it.
struct RootView: View {
    enum Tab: Hashable {
        case today
        case history
        case ai
    }

    @EnvironmentObject private var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: Tab = .today
    @State private var aiRange: AIExportRange = .week
    @State private var pendingKind: LogKind?
    @State private var showingOnboarding = false
    @State private var showingWidgetShowcase = false

    var body: some View {
        TabView(selection: $tab) {
            TodayScreen(pendingKind: $pendingKind)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "calendar") }
            .tag(Tab.history)

            NavigationStack {
                AskAIView(range: $aiRange)
            }
            .tabItem { Label("Ask AI", systemImage: "sparkles") }
            .tag(Tab.ai)
        }
        .environment(\.askAI, AskAIAction { range in
            aiRange = range
            withAnimation(.snappy) { tab = .ai }
        })
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingWidgetShowcase) {
            WidgetShowcaseView(
                habits: store.habits,
                waterMilliliters: store.waterMilliliters(on: DayKey.today())
            )
        }
        .onAppear(perform: start)
        .onChange(of: scenePhase) { _, phase in
            // A widget button or Siri may have written while the app was in the background.
            if phase == .active {
                store.reloadFromDisk()
                ReminderScheduler.refresh(habits: store.habits)
            }
        }
        .onChange(of: store.habits) { _, habits in
            ReminderScheduler.refresh(habits: habits)
        }
        .onReceive(NotificationCenter.default.publisher(for: .keptDataChanged).receive(on: RunLoop.main)) { _ in
            store.reloadFromDisk()
        }
        .onOpenURL(perform: open)
    }

    private func start() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-screen"), index + 1 < args.count {
            switch args[index + 1] {
            case "history":
                tab = .history
            case "ai", "send":
                tab = .ai
            case "log":
                pendingKind = .food
            case "widgets":
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingWidgetShowcase = true
                }
            default:
                break
            }
            return
        }
        if !store.settings.hasOnboarded && store.habits.isEmpty && store.log.isEmpty {
            showingOnboarding = true
        }
    }

    /// `kept://log/food`, `kept://water`, `kept://ai`, `kept://history`. Used by widgets.
    private func open(_ url: URL) {
        guard url.scheme == "kept" else { return }
        switch url.host {
        case "log":
            tab = .today
            if let raw = url.pathComponents.dropFirst().first, let kind = LogKind(rawValue: raw) {
                pendingKind = kind
            }
        case "water":
            tab = .today
            store.addWater(on: DayKey.today())
            Haptics.success()
        case "ai":
            tab = .ai
        case "history":
            tab = .history
        default:
            tab = .today
        }
    }
}
