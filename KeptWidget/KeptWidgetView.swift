import AppIntents
import SwiftUI
import WidgetKit

struct KeptEntry: TimelineEntry {
    let date: Date
    let habits: [Habit]
    let today: DayKey
    var waterMilliliters: Int = 0
}

/// Renders one widget family. The widget extension passes the family from the environment;
/// the app renders it directly for the widget showcase screenshot.
struct KeptWidgetView: View {
    let entry: KeptEntry
    let family: WidgetFamily

    private var scheduled: [Habit] { entry.habits.filter { $0.isScheduled(on: entry.today) } }
    private var done: Int { scheduled.filter { $0.isCompleted(on: entry.today) }.count }
    private var total: Int { scheduled.count }
    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    private var waterText: String {
        entry.waterMilliliters == 0 ? "Water" : VolumeFormat.string(milliliters: entry.waterMilliliters)
    }

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
            large
        default:
            medium
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
            Text(Brand.name)
                .font(.headline)
            Text(total == 0 ? "Nothing due today" : "\(done) of \(total) checked off")
            Label(waterText, systemImage: "drop.fill")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineText: String {
        if total == 0 { return "\(Brand.name) · \(waterText)" }
        return "\(Brand.name) · \(done)/\(total) · \(waterText)"
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
            HStack {
                Text(entry.date, format: .dateTime.weekday(.wide))
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 2)
            }
            Label(waterText, systemImage: "drop.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            rows(limit: 3)
            Spacer(minLength: 0)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            rows(limit: 6)
            Spacer(minLength: 0)
            quickLogBar
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if total > 0 {
                Text("\(done)/\(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(intent: AddWaterIntent()) {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                    Text(waterText)
                    Image(systemName: "plus")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.15), in: Capsule())
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func rows(limit: Int) -> some View {
        let habits = Array(entry.habits.prefix(limit))
        if habits.isEmpty {
            Text("Add your supplements in \(Brand.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            ForEach(habits) { habit in
                row(habit)
            }
        }
    }

    private func row(_ habit: Habit) -> some View {
        let isDone = habit.isCompleted(on: entry.today)
        let color = HabitPalette.color(habit.colorName)
        return HStack(spacing: 8) {
            Text(habit.emoji)
            Text(habit.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .strikethrough(isDone, color: .secondary)
                .foregroundStyle(isDone ? .secondary : .primary)
            Spacer(minLength: 4)
            Button(intent: ToggleHabitIntent(habit: HabitEntity(habit))) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? color : Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    /// Deep links into the app's editor, one per kind.
    private var quickLogBar: some View {
        HStack(spacing: 8) {
            ForEach(LogKind.allCases) { kind in
                Link(destination: URL(string: "kept://log/\(kind.rawValue)")!) {
                    VStack(spacing: 3) {
                        Image(systemName: kind.symbol)
                            .font(.subheadline.weight(.semibold))
                        Text(kind.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        HabitPalette.color(kind.colorName).opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .foregroundStyle(HabitPalette.color(kind.colorName))
                }
            }
        }
    }
}
