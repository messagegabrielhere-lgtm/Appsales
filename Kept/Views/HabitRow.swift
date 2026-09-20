import SwiftUI

struct HabitRow: View {
    let habit: Habit
    let today: DayKey
    let onToggle: () -> Void

    private var isDone: Bool { habit.isCompleted(on: today) }
    private var streak: Int { StreakCalculator.currentStreak(habit.completions, today: today) }
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
                    Text(streakText)
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
        .accessibilityElement(children: .combine)
    }

    private var streakText: String {
        switch streak {
        case 0: return "No streak"
        case 1: return "1 day"
        default: return "\(streak) days"
        }
    }
}

/// Seven small dots for the last week, oldest on the left, today on the right.
private struct WeekStrip: View {
    let habit: Habit
    let today: DayKey
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach((0..<7).reversed(), id: \.self) { offset in
                let day = today.adding(days: -offset)
                Circle()
                    .fill(habit.isCompleted(on: day) ? color : color.opacity(0.18))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}
