import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingEditor = false
    @State private var showingAbout = false
    @State private var today = DayKey.today()
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.habits.isEmpty {
                    EmptyStateView { showingEditor = true }
                } else {
                    habitList
                }
            }
            .navigationTitle("Kept")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.habits.isEmpty {
                        aboutButton
                    } else {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if !store.habits.isEmpty {
                            aboutButton
                        }
                        Button {
                            showingEditor = true
                        } label: {
                            Label("Add Habit", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                HabitEditorView(mode: .create) { habit in
                    withAnimation(.snappy) {
                        store.add(habit)
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .navigationDestination(for: UUID.self) { id in
                HabitDetailView(habitID: id)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Roll the date over if the app was left open across midnight.
            if phase == .active {
                today = DayKey.today()
            }
        }
        .onAppear(perform: openScreenFromLaunchArguments)
    }

    /// `-screen detail` or `-screen editor` (used by scripts/screenshots.sh together with
    /// `-demo`) opens that screen on launch so screenshots need no tapping.
    private func openScreenFromLaunchArguments() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "-screen"), index + 1 < args.count else { return }
        switch args[index + 1] {
        case "detail":
            if let first = store.habits.first {
                path = [first.id]
            }
        case "editor":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingEditor = true
            }
        default:
            break
        }
    }

    private var aboutButton: some View {
        Button {
            showingAbout = true
        } label: {
            Label("About", systemImage: "info.circle")
        }
    }

    private var doneCount: Int {
        store.habits.filter { $0.isCompleted(on: today) }.count
    }

    private var habitList: some View {
        List {
            Section {
                TodayProgressView(done: doneCount, total: store.habits.count, date: today.date())
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                ForEach(store.habits) { habit in
                    NavigationLink(value: habit.id) {
                        HabitRow(habit: habit, today: today) {
                            toggle(habit)
                        }
                    }
                }
                .onDelete { offsets in
                    withAnimation(.snappy) {
                        store.delete(at: offsets)
                    }
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            }
        }
    }

    private func toggle(_ habit: Habit) {
        let wasDone = habit.isCompleted(on: today)
        withAnimation(.snappy) {
            store.toggle(habit, on: today)
        }
        guard !wasDone, let updated = store.habit(id: habit.id) else {
            Haptics.tap()
            return
        }
        let streak = StreakCalculator.currentStreak(updated.completions, today: today)
        if doneCount == store.habits.count {
            Haptics.success()
        } else {
            Haptics.checkIn(newStreak: streak)
        }
    }
}

/// "3 of 5 done" with a thin progress bar. Reads as a single accessibility element.
private struct TodayProgressView: View {
    let done: Int
    let total: Int
    let date: Date

    private var fraction: Double {
        total == 0 ? 0 : Double(done) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(date, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(done == total ? "All done" : "\(done) of \(total) done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done == total ? Color.accentColor : Color.secondary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: fraction)
                .tint(.accentColor)
                .animation(.snappy, value: fraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) habits done today")
    }
}

#Preview {
    ContentView()
        .environmentObject(HabitStore.preview())
}
