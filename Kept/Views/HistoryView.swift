import SwiftUI

/// Every day with data, newest first. Tap a day to see and edit it.
struct HistoryView: View {
    @EnvironmentObject private var store: HabitStore

    var body: some View {
        let today = DayKey.today()
        let days = LogInsights.historyDays(habits: store.habits, log: store.log, today: today)
        let grouped = Dictionary(grouping: store.log) { $0.day() }

        List {
            Section {
                NavigationLink {
                    TrendsView()
                } label: {
                    Label("Trends: calories, protein, water and more", systemImage: "chart.xyaxis.line")
                }
            }
            Section {
                ForEach(days, id: \.self) { day in
                    NavigationLink(value: day) {
                        HistoryRow(day: day, entries: grouped[day] ?? [], habits: store.habits)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationDestination(for: DayKey.self) { day in
            DayView(day: day, pendingKind: .constant(nil))
                .navigationTitle(DayTitle.title(for: day))
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationDestination(for: UUID.self) { id in
            HabitDetailView(habitID: id)
        }
    }
}

private struct HistoryRow: View {
    let day: DayKey
    let entries: [LogEntry]
    let habits: [Habit]

    private var scheduled: [Habit] { habits.filter { $0.isScheduled(on: day) } }
    private var done: Int { scheduled.filter { $0.isCompleted(on: day) }.count }

    private var averageFeeling: Double? {
        let ratings = entries.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DayTitle.title(for: day))
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(LogKind.allCases) { kind in
                    let count = entries.filter { $0.kind == kind }.count
                    if count > 0 {
                        Label("\(count)", systemImage: kind.symbol)
                            .foregroundStyle(HabitPalette.color(kind.colorName))
                    }
                }
                if done > 0 {
                    Label("\(done)/\(scheduled.count)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                if let averageFeeling {
                    Text(LogEntry.face(for: Int(averageFeeling.rounded())))
                }
                if entries.isEmpty && done == 0 {
                    Text("Nothing logged")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}
