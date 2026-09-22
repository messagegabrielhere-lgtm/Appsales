import SwiftUI

struct HabitDetailView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    let habitID: UUID

    @State private var today = DayKey.today()
    @State private var visibleMonth = DayKey.today().firstOfMonth
    @State private var showingEditor = false
    @State private var confirmingDelete = false

    private let calendar = Calendar.current

    var body: some View {
        if let habit = store.habit(id: habitID) {
            content(for: habit)
        } else {
            ContentUnavailableView("Habit removed", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func content(for habit: Habit) -> some View {
        let color = HabitPalette.color(habit.colorName)
        let doneToday = habit.isCompleted(on: today)
        let restDay = !habit.isScheduled(on: today)

        ScrollView {
            VStack(spacing: 20) {
                Button {
                    let wasDone = doneToday
                    withAnimation(.snappy) {
                        store.toggle(habit, on: today)
                    }
                    if wasDone {
                        Haptics.tap()
                    } else if let updated = store.habit(id: habitID) {
                        Haptics.checkIn(newStreak: StreakCalculator.currentStreak(
                            updated.completions, today: today, schedule: updated.schedule))
                    }
                } label: {
                    Label(
                        doneToday ? "Done today" : (restDay ? "Rest day. Do it anyway?" : "Mark today done"),
                        systemImage: doneToday ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(
                        title: "Current streak",
                        value: "\(StreakCalculator.currentStreak(habit.completions, today: today, schedule: habit.schedule))",
                        color: color
                    )
                    StatTile(
                        title: "Best streak",
                        value: "\(StreakCalculator.longestStreak(habit.completions, schedule: habit.schedule))",
                        color: color
                    )
                    StatTile(
                        title: "Total days",
                        value: "\(habit.completions.count)",
                        color: color
                    )
                    StatTile(
                        title: "Last 30 days",
                        value: StreakCalculator
                            .completionRate(habit.completions, today: today, days: 30, schedule: habit.schedule)
                            .formatted(.percent.precision(.fractionLength(0))),
                        color: color
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Past year")
                        .font(.headline)
                    YearHeatmapView(
                        completions: habit.completions,
                        today: today,
                        schedule: habit.schedule,
                        color: color
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 12) {
                    HStack {
                        Button {
                            visibleMonth = visibleMonth.adding(months: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Previous month")

                        Spacer()

                        Text(visibleMonth.date(), format: .dateTime.month(.wide).year())
                            .font(.headline)

                        Spacer()

                        Button {
                            visibleMonth = visibleMonth.adding(months: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(visibleMonth >= today.firstOfMonth)
                        .accessibilityLabel("Next month")
                    }
                    .padding(.horizontal, 4)

                    MonthGridView(
                        month: visibleMonth,
                        today: today,
                        completions: habit.completions,
                        color: color
                    ) { day in
                        Haptics.tap()
                        withAnimation(.snappy) {
                            store.toggle(habit, on: day)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Label(scheduleDescription(habit), systemImage: "repeat")
                    Label(reminderDescription(habit), systemImage: habit.reminderMinutes == nil ? "bell.slash" : "bell")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tap any past day to fix a missed check-in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("\(habit.emoji) \(habit.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditorView(mode: .edit(habit)) { updated in
                store.update(updated)
            }
        }
        .confirmationDialog(
            "Delete \(habit.name)?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.delete(habit)
                dismiss()
            }
        } message: {
            Text("This removes the habit and all of its history.")
        }
        .onAppear {
            today = DayKey.today()
        }
    }

    private func scheduleDescription(_ habit: Habit) -> String {
        if habit.isEveryDay { return "Every day" }
        if habit.schedule == Habit.weekdays { return "Weekdays" }
        if habit.schedule == [1, 7] { return "Weekends" }
        let ordered = (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
        let names = ordered.filter { habit.schedule.contains($0) }.map { calendar.shortStandaloneWeekdaySymbols[$0 - 1] }
        return names.joined(separator: ", ")
    }

    private func reminderDescription(_ habit: Habit) -> String {
        guard let minutes = habit.reminderMinutes,
              let time = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) else {
            return "No reminder"
        }
        return "Reminder at " + time.formatted(date: .omitted, time: .shortened)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let store = HabitStore.preview()
    return NavigationStack {
        HabitDetailView(habitID: store.habits[0].id)
    }
    .environmentObject(store)
}
