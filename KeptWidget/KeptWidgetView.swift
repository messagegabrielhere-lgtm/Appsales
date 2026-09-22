import AppIntents
import SwiftUI
import WidgetKit

struct KeptWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KeptEntry

    private var scheduled: [Habit] { entry.habits.filter { $0.isScheduled(on: entry.today) } }
    private var done: Int { scheduled.filter { $0.isCompleted(on: entry.today) }.count }
    private var total: Int { scheduled.count }
    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            Text(inlineText)
        case .systemSmall:
            small
        case .systemLarge:
            list(limit: 8)
        default:
            list(limit: 3)
        }
    }

    // MARK: Lock screen

    private var circular: some View {
        Gauge(value: Double(done), in: 0...Double(max(total, 1))) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text("\(done)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Kept")
                .font(.headline)
            Text(total == 0 ? "Rest day" : "\(done) of \(total) done")
            if let next = scheduled.first(where: { !$0.isCompleted(on: entry.today) }) {
                Text("Next: \(next.emoji) \(next.name)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineText: String {
        if total == 0 { return "Kept: rest day" }
        return done == total ? "Kept: all done" : "Kept: \(done) of \(total) done"
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.teal.opacity(0.2), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(done)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("of \(total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            Text(entry.date, format: .dateTime.weekday(.wide))
                .font(.caption.weight(.semibold))
            Text(total == 0 ? "Rest day" : (done == total ? "All done" : "habits done"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func list(limit: Int) -> some View {
        let habits = Array(entry.habits.prefix(limit))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(total == 0 ? "Rest day" : "\(done)/\(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if habits.isEmpty {
                Spacer()
                Text("Add a habit in Kept")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(habits) { habit in
                    row(habit)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(_ habit: Habit) -> some View {
        let done = habit.isCompleted(on: entry.today)
        let color = HabitPalette.color(habit.colorName)
        return HStack(spacing: 8) {
            Text(habit.emoji)
            Text(habit.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .strikethrough(done, color: .secondary)
                .foregroundStyle(done ? .secondary : .primary)
            Spacer(minLength: 4)
            Button(intent: ToggleHabitIntent(habit: HabitEntity(habit))) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? color : Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview(as: .systemMedium) {
    KeptWidget()
} timeline: {
    KeptEntry(date: Date(), habits: HabitStore.preview().habits, today: DayKey.today())
}
