import SwiftUI

/// A tappable calendar month. Past and current days toggle; future days are disabled.
struct MonthGridView: View {
    /// Any day within the month to display.
    let month: DayKey
    let today: DayKey
    let completions: Set<DayKey>
    let color: Color
    let onToggle: (DayKey) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    private func dayCell(_ day: DayKey) -> some View {
        let done = completions.contains(day)
        let isToday = day == today
        let isFuture = day > today

        return Button {
            onToggle(day)
        } label: {
            Text("\(day.day)")
                .font(.callout.weight(done ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    done ? color : color.opacity(isFuture ? 0.05 : 0.12),
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .foregroundStyle(done ? Color.white : (isFuture ? Color.secondary : Color.primary))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isToday ? Color.primary : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(day.date(), format: .dateTime.month().day()))
        .accessibilityValue(done ? "Done" : "Not done")
    }

    /// Leading `nil`s pad the first week so day 1 lands on the correct weekday column.
    private var cells: [DayKey?] {
        let first = month.firstOfMonth
        let firstDate = first.date(calendar: calendar)
        let dayRange = calendar.range(of: .day, in: .month, for: firstDate) ?? 1..<31
        let weekdayOfFirst = calendar.component(.weekday, from: firstDate)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var result: [DayKey?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            result.append(DayKey(year: first.year, month: first.month, day: day))
        }
        return result
    }

    /// Weekday headers rotated to the user's locale's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }
}

#Preview {
    let today = DayKey.today()
    return MonthGridView(
        month: today,
        today: today,
        completions: Set((0..<6).map { today.adding(days: -$0) }),
        color: .teal
    ) { _ in }
    .padding()
}
