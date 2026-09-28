import SwiftUI

/// One line of the day's timeline.
struct LogEntryRow: View {
    let entry: LogEntry

    private var color: Color { HabitPalette.color(entry.kind.colorName) }

    private var primary: String {
        if entry.kind == .feeling, let rating = entry.rating {
            return "\(LogEntry.face(for: rating)) \(LogEntry.label(for: rating))"
        }
        return entry.text
    }

    private var detail: String? {
        var parts: [String] = []
        if entry.kind == .feeling, entry.rating != nil, !entry.text.isEmpty {
            parts.append(entry.text)
        }
        if let amount = entry.amount, !amount.isEmpty { parts.append(amount) }
        if let ml = entry.milliliters { parts.append(VolumeFormat.string(milliliters: ml)) }
        if let minutes = entry.minutes { parts.append("\(minutes) min") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
                .padding(.top, 3)

            Image(systemName: entry.kind.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(primary)
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
