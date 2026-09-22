import AppIntents
import SwiftUI
import WidgetKit

struct KeptEntry: TimelineEntry {
    let date: Date
    let habits: [Habit]
    let today: DayKey
}

struct KeptProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeptEntry {
        KeptEntry(date: Date(), habits: HabitStore.preview().habits, today: DayKey.today())
    }

    func getSnapshot(in context: Context, completion: @escaping (KeptEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeptEntry>) -> Void) {
        let entry = currentEntry()
        // The app reloads timelines on every save; this refresh only handles the date rolling over.
        let calendar = Calendar.current
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> KeptEntry {
        KeptEntry(date: Date(), habits: HabitStore().habits, today: DayKey.today())
    }
}

struct KeptWidget: Widget {
    let kind = "KeptWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeptProvider()) { entry in
            KeptWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Habits")
        .description("Check off habits without opening the app.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
