import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingEditor = false
    @State private var today = DayKey.today()

    var body: some View {
        NavigationStack {
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
                    if !store.habits.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Add Habit", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                HabitEditorView(mode: .create) { habit in
                    store.add(habit)
                }
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
    }

    private var habitList: some View {
        List {
            Section {
                ForEach(store.habits) { habit in
                    NavigationLink(value: habit.id) {
                        HabitRow(habit: habit, today: today) {
                            store.toggle(habit, on: today)
                        }
                    }
                }
                .onDelete { offsets in
                    store.delete(at: offsets)
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            } header: {
                Text(today.date(), format: .dateTime.weekday(.wide).month().day())
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HabitStore.preview())
}
