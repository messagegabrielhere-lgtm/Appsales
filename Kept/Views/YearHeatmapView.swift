import SwiftUI

/// A year of check-ins at a glance: 53 columns of weeks, 7 rows of days, today at the far right.
/// Cells grow to fill the available width (up to a cap) and scroll horizontally when they can't.
struct YearHeatmapView: View {
    let completions: Set<DayKey>
    let today: DayKey
    let schedule: Set<Int>
    let color: Color

    @State private var availableWidth: CGFloat = 0

    private let calendar = Calendar.current
    private let weeks = 53
    private let minCell: CGFloat = 11
    private let maxCell: CGFloat = 20
    private let gap: CGFloat = 3

    private var cell: CGFloat {
        guard availableWidth > 0 else { return minCell }
        let fitted = (availableWidth - CGFloat(weeks - 1) * gap) / CGFloat(weeks)
        return min(maxCell, max(minCell, fitted.rounded(.down)))
    }

    /// The first cell: the start of the week that contains the day one year back.
    private var startDay: DayKey {
        var day = today.adding(days: -(weeks * 7 - 1), calendar: calendar)
        while (day.weekday(calendar: calendar) - calendar.firstWeekday + 7) % 7 != 0 {
            day = day.adding(days: -1, calendar: calendar)
        }
        return day
    }

    var body: some View {
        let start = startDay
        let size = cell
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { row in
                                square(for: start.adding(days: week * 7 + row, calendar: calendar), size: size)
                            }
                        }
                        .id(week)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                proxy.scrollTo(weeks - 1, anchor: .trailing)
            }
        }
        .frame(height: 7 * size + 6 * gap + 4)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: HeatmapWidthKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(HeatmapWidthKey.self) { width in
            // Preference changes are delivered after layout, so this cannot re-enter it.
            if abs(width - availableWidth) > 0.5 {
                availableWidth = width
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Year overview, \(completions.count) days completed")
    }

    private func square(for day: DayKey, size: CGFloat) -> some View {
        let done = completions.contains(day)
        let future = day > today
        let scheduled = schedule.contains(day.weekday(calendar: calendar))
        let fill: Color
        if done {
            fill = color
        } else if future || !scheduled {
            fill = color.opacity(0.06)
        } else {
            fill = color.opacity(0.16)
        }
        return RoundedRectangle(cornerRadius: size * 0.22)
            .fill(fill)
            .frame(width: size, height: size)
    }
}

private struct HeatmapWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    let today = DayKey.today()
    return YearHeatmapView(
        completions: Set((0..<200).filter { $0 % 3 != 0 }.map { today.adding(days: -$0) }),
        today: today,
        schedule: Habit.everyDay,
        color: .teal
    )
    .padding()
}
