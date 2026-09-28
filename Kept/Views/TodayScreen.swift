import SwiftUI

/// The Today tab: one day at a time, stepping back with the arrows to fill in earlier days.
struct TodayScreen: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @Binding var pendingKind: LogKind?

    @State private var day = DayKey.today()
    @State private var lastKnownToday = DayKey.today()
    @State private var path: [UUID] = []
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            DayView(day: day, pendingKind: $pendingKind)
                .navigationTitle(DayTitle.title(for: day))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if day != DayKey.today() {
                            Button("Today") {
                                withAnimation(.snappy) { day = DayKey.today() }
                            }
                        }
                        Button {
                            withAnimation(.snappy) { day = day.adding(days: -1) }
                        } label: {
                            Label("Previous day", systemImage: "chevron.left")
                        }
                        Button {
                            withAnimation(.snappy) { day = day.adding(days: 1) }
                        } label: {
                            Label("Next day", systemImage: "chevron.right")
                        }
                        .disabled(day >= DayKey.today())
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    HabitDetailView(habitID: id)
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .onChange(of: pendingKind) { _, kind in
            // Quick logging from a widget or deep link always means "now".
            if kind != nil { day = DayKey.today() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Roll over at midnight if the user was looking at today.
            guard phase == .active else { return }
            let now = DayKey.today()
            if day == lastKnownToday { day = now }
            lastKnownToday = now
        }
        .onAppear(perform: openScreenFromLaunchArguments)
    }

    /// `-screen detail` (used with `-demo` by scripts/screenshots.sh) opens the first checklist
    /// item so the screenshot needs no tapping.
    private func openScreenFromLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screen"), index + 1 < args.count else { return }
        if args[index + 1] == "detail", let first = store.habits.first {
            path = [first.id]
        }
    }
}
