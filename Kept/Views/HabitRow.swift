import SwiftUI
import UIKit

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

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                Text(streakText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(isDone ? color : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark \(habit.name) not done" : "Mark \(habit.name) done")
        }
        .padding(.vertical, 4)
    }

    private var streakText: String {
        switch streak {
        case 0: return "No streak yet"
        case 1: return "1 day streak"
        default: return "\(streak) day streak"
        }
    }
}
