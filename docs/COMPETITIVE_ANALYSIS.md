# Why Kept 2.0 looks the way it does

A short survey of the habit-tracker category on iOS as of September 2026, and the decisions it
drove. Sources are linked at the bottom.

## Who wins today, and why

| App | Price | What it wins on | Where users complain |
| --- | --- | --- | --- |
| Streaks | $4.99 once | Apple polish, Health auto-tracking, Apple Watch | 12-habit cap, dated look |
| HabitKit | Free + one-time unlock | Year heatmap "contribution graph", widgets, no bloat, 4.9 stars | Deeper stats behind paywall |
| Habitify | Subscription | Flexible schedules, reliable reminders, cross-platform | Subscription fatigue, 3-habit free cap |
| Productive | Subscription only | Routines, time-of-day grouping | "Why isn't this pay-once?" |
| Habit Tracker (Davetech) | Free + $2.99 | Widgets, cheap unlock | Freezes, widgets not refreshing |

Recurring themes in one-star reviews across the category:

1. **Subscriptions.** The single most common complaint. "Streaks and Done exist as one-time
   purchases" is a sentence that appears in reviews of every subscription app.
2. **Widgets that show stale data.** Second most common. People check habits from the home
   screen; if the widget lies, they uninstall.
3. **Slowness.** Freezes on open or on check-off. A habit app is used for five seconds at a time.
4. **Rigid daily-only streaks.** People want weekday-only or three-times-a-week habits without
   losing the streak on rest days.
5. **Free tiers that cap at three habits.** Feels like bait.

## What Kept 2.0 does about it

| Complaint | Kept's answer |
| --- | --- |
| Subscriptions | $0.99 once. Every feature. Said in the subtitle, the first screenshot, and the description. |
| Stale widgets | The app and widget share one file through an App Group; every save reloads the widget. Interactive check-off directly on the widget (iOS 17). Lock-screen widgets too. |
| Slowness | No database, no sync engine, no network. One small JSON file. Launch is instant. |
| Rigid streaks | Per-habit weekday schedule. Rest days are skipped, never broken. Streak grace until the next scheduled day. |
| Habit caps | None. |
| Missed check-ins | Reminders scheduled per day, skipped once the habit is done, skipped on rest days. |
| "I want to see my year" | GitHub-style 12-month heatmap on every habit. |
| Empty first run | Eight one-tap starter habits so the first check-in happens in seconds. |
| Siri | "Mark drink water done in Kept." |

## What Kept deliberately does not do (yet)

- **Apple Health auto-tracking** (Streaks' moat). Needs HealthKit entitlement and review scrutiny.
  Candidate for 2.1 once reviews ask for it.
- **iCloud sync.** Most one-star reviews about sync are about sync breaking. Export exists.
  Candidate for 2.1 via CloudKit key-value store.
- **Apple Watch.** Candidate for 2.2.
- **Multiple completions per day, notes, mood.** Scope creep. HabitKit users praise "no bloat".

## Store-listing implications

- Lead the subtitle with the price model: "Pay once. No subscription."
- First screenshot: the widget on a home screen. Second: the year heatmap. Third: the list.
- Keywords should include "widget", "streak", "no subscription", "simple", "private".

## Sources

- Timing: [Best Habit Tracker Apps for iPhone and Mac (2026)](https://timingapp.com/blog/habit-tracker-apps-iphone-mac/)
- EasyHabits: [Best Habit Tracker Apps for iPhone 2026](https://www.easyhabits.io/blog/best-habit-tracker-apps)
- 2sync: [12 best habit tracking apps in 2026](https://2sync.com/blog/best-habit-tracker-apps)
- Habi: [7 Best Streak Tracker Apps in 2026](https://habi.app/insights/best-streak-tracker-apps/)
- HabitBox: [Habit Tracker Widget: 7 Best Home Screen Apps (2026)](https://habitbox.app/blog/habit-tracker-widget)
- HabitKit: [homepage](https://habitkit.app/), [changelog](https://habitkit.app/changelog/), [App Store reviews](https://apps.apple.com/us/app/habit-tracker-habitkit/id6443918070?see-all=reviews&platform=iphone)
- Medium: [Building Habit Tracking Apps: HabitKit App Review](https://hiteshkohli.medium.com/building-habit-tracking-apps-habitkit-app-review-275bd615f564)
- RoutineBase: [Best Habit Tracker Apps in 2026](https://routinebase.com/best-habit-tracker-apps/)
