import SwiftUI

struct HabitRow: View {
    let habit: Habit
    let today: DayKey
    let onToggle: () -> Void

    private var isDone: Bool { habit.isCompleted(on: today) }
    private var isScheduledToday: Bool { habit.isScheduled(on: today) }
    private var streak: Int { StreakCalculator.currentStreak(habit.completions, today: today, schedule: habit.schedule) }
    private var color: Color { HabitPalette.color(habit.colorName) }

    var body: some View {
        HStack(spacing: 12) {
            Text(habit.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    WeekStrip(habit: habit, today: today, color: color)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button(action: onToggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(isDone ? color : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark \(habit.name) not done" : "Mark \(habit.name) done")
        }
        .padding(.vertical, 4)
        .opacity(isScheduledToday || isDone ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if !isScheduledToday && !isDone { return streak > 0 ? "Rest day · \(streak) day streak" : "Rest day" }
        switch streak {
        case 0: return "No streak"
        case 1: return "1 day"
        default: return "\(streak) days"
        }
    }
}

/// Seven small dots for the last week, oldest on the left, today on the right.
/// Rest days are drawn almost invisible so the eye reads only the days that count.
private struct WeekStrip: View {
    let habit: Habit
    let today: DayKey
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach((0..<7).reversed(), id: \.self) { offset in
                let day = today.adding(days: -offset)
                let done = habit.isCompleted(on: day)
                let scheduled = habit.isScheduled(on: day)
                Circle()
                    .fill(done ? color : color.opacity(scheduled ? 0.18 : 0.06))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}
