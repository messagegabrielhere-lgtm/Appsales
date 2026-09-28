import Foundation

/// The span of days an export covers.
enum AIExportRange: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .week: return "7 days"
        case .month: return "30 days"
        }
    }

    /// Oldest first.
    func days(endingAt today: DayKey, calendar: Calendar = .current) -> [DayKey] {
        switch self {
        case .today:
            return [today]
        case .yesterday:
            return [today.adding(days: -1, calendar: calendar)]
        case .week:
            return (0..<7).reversed().map { today.adding(days: -$0, calendar: calendar) }
        case .month:
            return (0..<30).reversed().map { today.adding(days: -$0, calendar: calendar) }
        }
    }
}

/// A ready-made analysis request. The instructions are the product: each asks for specific,
/// checkable output, prefers ranges over false precision, and keeps health questions framed as
/// things to raise with a professional rather than advice.
enum AIPromptTemplate: String, CaseIterable, Identifiable {
    case patterns
    case nutrition
    case supplements
    case hydration
    case activity
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .patterns: return "Energy & mood patterns"
        case .nutrition: return "Nutrition estimate"
        case .supplements: return "Supplement review"
        case .hydration: return "Hydration & caffeine"
        case .activity: return "Activity & recovery"
        case .custom: return "Ask your own question"
        }
    }

    var subtitle: String {
        switch self {
        case .patterns: return "What seems to lift or drain you, with experiments to test it."
        case .nutrition: return "Calories, protein, carbs, fat and fibre per day, gaps flagged."
        case .supplements: return "Consistency, timing, and questions for your pharmacist."
        case .hydration: return "Fluids, caffeine and alcohol per day, and their timing."
        case .activity: return "What you did, how you fuelled it, how you felt after."
        case .custom: return "Anything you want to know about your log."
        }
    }

    var symbol: String {
        switch self {
        case .patterns: return "waveform.path.ecg"
        case .nutrition: return "chart.pie"
        case .supplements: return "pills"
        case .hydration: return "drop"
        case .activity: return "figure.run"
        case .custom: return "questionmark.bubble"
        }
    }

    static let notAdvice = "This is not medical advice, and you should say so where it matters."

    func instructions(customQuestion: String) -> String {
        switch self {
        case .patterns:
            return """
            Please look for patterns in my log below, connecting what I ate and drank, when I \
            ate, my activity, my supplements, and how I felt.

            1. List the clearest patterns you can see. For each, cite the specific days that \
            support it and say how confident you are.
            2. Point out anything about timing, such as late meals, caffeine after midday, or \
            long gaps without food, and what followed.
            3. Suggest up to three small experiments I could run next week to test the \
            strongest patterns.

            Separate correlation from causation. Keep it concise and practical. \
            \(AIPromptTemplate.notAdvice)
            """
        case .nutrition:
            return """
            Please estimate my nutrition from the food and drink log below.

            1. For each day, estimate calories, protein, carbohydrate, fat and fibre. Where I \
            didn't give a portion, assume a typical one and state the assumption.
            2. Show a compact table per day, then the average across the period.
            3. Name the two or three biggest gaps or excesses compared with general adult \
            guidelines, and suggest simple swaps using foods I already eat.

            Give ranges rather than false precision. \(AIPromptTemplate.notAdvice)
            """
        case .supplements:
            return """
            Please review my supplements and routines, listed as my daily checklist below, and \
            how consistently I took them.

            1. For each item, summarise how consistently I took it over the period.
            2. Comment on timing: which are commonly better taken with food, apart from each \
            other, or at a particular time of day, and whether my timing seems to match.
            3. Flag any combinations, including with anything in my food and drink log, that \
            are commonly worth discussing with a pharmacist or doctor.
            4. Flag any dose that looks unusual compared with common ranges.

            Do not tell me to start, stop or change anything. Frame every point as a question \
            I could raise with a pharmacist or doctor. \(AIPromptTemplate.notAdvice)
            """
        case .hydration:
            return """
            Please analyse my drinks from the log below.

            1. Estimate my total fluid per day and how much of it was water.
            2. Estimate caffeine and alcohol per day from the drinks listed, stating the amounts \
            you assumed.
            3. Look at timing, especially caffeine late in the day, and any link to how I felt \
            that evening or the next morning.
            4. Suggest simple, specific adjustments.

            \(AIPromptTemplate.notAdvice)
            """
        case .activity:
            return """
            Please analyse my activity alongside my food, drinks and how I felt.

            1. Summarise activity per day: type, duration, and a rough intensity estimate.
            2. Say whether my eating before and after activity looks adequate for recovery.
            3. Note any link between activity and how I felt later that day or the next day.
            4. Suggest a realistic weekly structure built on what I already do.

            \(AIPromptTemplate.notAdvice)
            """
        case .custom:
            let question = customQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            return """
            Please answer my question using the log below. Refer to specific days and entries. \
            If the log doesn't contain enough to answer, tell me what I should track to find out.

            My question: \(question.isEmpty ? "What stands out in my log?" : question)
            """
        }
    }
}

/// Turns a period of the log into one block of text, ready to paste into any AI assistant.
enum AIExportBuilder {
    struct Input {
        var template: AIPromptTemplate
        var customQuestion: String = ""
        var days: [DayKey]
        var habits: [Habit]
        var log: [LogEntry]
        /// Nil or blank to leave the About Me section out.
        var aboutMe: String?
        var calendar: Calendar = .current
    }

    /// Width the entry-type column is padded to, so entries line up.
    static let kindColumnWidth = 10

    static func build(_ input: Input) -> String {
        let calendar = input.calendar
        let days = input.days.sorted()
        var lines: [String] = []

        lines.append(input.template.instructions(customQuestion: input.customQuestion))
        lines.append("")

        if let about = input.aboutMe?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
            lines.append("ABOUT ME")
            lines.append(about)
            lines.append("")
        }

        lines.append("MY LOG")
        if let first = days.first, let last = days.last {
            if first == last {
                lines.append("Day: \(longDate(first, calendar: calendar))")
            } else {
                lines.append("Period: \(longDate(first, calendar: calendar)) to \(longDate(last, calendar: calendar)) (\(days.count) days)")
            }
        }
        lines.append("Times are local (\(calendar.timeZone.identifier)), 24-hour clock.")
        lines.append("Feeling ratings run from 1 (awful) to 5 (great).")

        if !input.habits.isEmpty {
            lines.append("")
            lines.append("Daily checklist (supplements and routines):")
            for habit in input.habits {
                lines.append("- " + describe(habit))
            }
        }

        let byDay = Dictionary(grouping: input.log) { $0.day(calendar: calendar) }

        for day in days {
            lines.append("")
            lines.append("## " + longDate(day, calendar: calendar))

            let tracked = input.habits.filter { isTracked($0, on: day, calendar: calendar) }
            if !tracked.isEmpty {
                let parts = tracked.map { habit -> String in
                    if habit.isCompleted(on: day) { return "\(habit.name) done" }
                    if !habit.isScheduled(on: day, calendar: calendar) { return "\(habit.name) rest day" }
                    return "\(habit.name) missed"
                }
                lines.append("Checklist: " + parts.joined(separator: "; "))
            }

            let entries = (byDay[day] ?? []).sorted { $0.date < $1.date }
            let water = LogInsights.waterMilliliters(of: entries)
            if water > 0 {
                lines.append("Water total: \(water) ml")
            }
            if entries.isEmpty {
                lines.append("Nothing logged.")
            }
            for entry in entries {
                lines.append(line(for: entry, calendar: calendar))
            }
        }

        lines.append("")
        lines.append("(Exported from \(Brand.name).)")
        return lines.joined(separator: "\n")
    }

    // MARK: Pieces, internal for tests

    static func line(for entry: LogEntry, calendar: Calendar) -> String {
        let time = formatter("HH:mm", calendar: calendar).string(from: entry.date)
        let kind = entry.kind.title.padding(toLength: kindColumnWidth, withPad: " ", startingAt: 0)
        let text = entry.text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var main = text
        if entry.kind == .feeling, let rating = entry.rating {
            main = text.isEmpty ? "\(rating)/5" : "\(rating)/5 \(text)"
        }

        var details: [String] = []
        if let amount = entry.amount?.trimmingCharacters(in: .whitespacesAndNewlines), !amount.isEmpty {
            details.append(amount)
        }
        if let ml = entry.milliliters { details.append("\(ml) ml") }
        if let minutes = entry.minutes { details.append("\(minutes) min") }

        let suffix = details.isEmpty ? "" : " (" + details.joined(separator: ", ") + ")"
        return "\(time)  \(kind)\(main)\(suffix)"
    }

    static func describe(_ habit: Habit) -> String {
        var parts = [habit.name]
        if let dose = habit.dose?.trimmingCharacters(in: .whitespacesAndNewlines), !dose.isEmpty {
            parts.append(dose)
        }
        parts.append(scheduleText(habit))
        if let minutes = habit.reminderMinutes {
            parts.append(String(format: "reminder at %02d:%02d", minutes / 60, minutes % 60))
        }
        return parts.joined(separator: ", ")
    }

    static func scheduleText(_ habit: Habit) -> String {
        let schedule = habit.schedule
        if schedule.count == 7 { return "every day" }
        if schedule == Habit.weekdays { return "weekdays" }
        if schedule == [1, 7] { return "weekends" }
        let names = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        return [2, 3, 4, 5, 6, 7, 1]
            .filter { schedule.contains($0) }
            .compactMap { names[$0] }
            .joined(separator: " ")
    }

    /// A habit only counts from the day it existed, or the first day it was ticked if the user
    /// back-filled earlier days. Otherwise a new supplement shows as "missed" all last month.
    static func isTracked(_ habit: Habit, on day: DayKey, calendar: Calendar) -> Bool {
        var start = DayKey(habit.createdAt, calendar: calendar)
        if let first = habit.completions.min(), first < start { start = first }
        return start <= day
    }

    static func longDate(_ day: DayKey, calendar: Calendar) -> String {
        formatter("EEEE d MMMM yyyy", calendar: calendar).string(from: day.date(calendar: calendar))
    }

    /// Fixed English and Gregorian output, whatever the device's settings, so the AI always
    /// receives the same unambiguous format.
    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = gregorian
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}

/// A spreadsheet of every entry and every checklist tick.
enum CSVExport {
    static let header = "date,time,type,text,amount,milliliters,minutes,rating"

    static func csv(log: [LogEntry], habits: [Habit], calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = gregorian
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = gregorian
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.dateFormat = "HH:mm"

        var rows: [(key: String, fields: [String])] = []
        for entry in log {
            let date = dateFormatter.string(from: entry.date)
            let time = timeFormatter.string(from: entry.date)
            rows.append((key: date + " " + time, fields: [
                date,
                time,
                entry.kind.rawValue,
                entry.text,
                entry.amount ?? "",
                entry.milliliters.map { String($0) } ?? "",
                entry.minutes.map { String($0) } ?? "",
                entry.rating.map { String($0) } ?? "",
            ]))
        }
        for habit in habits {
            for day in habit.completions {
                let date = dateFormatter.string(from: day.date(calendar: calendar))
                rows.append((key: date + " ", fields: [date, "", "checklist", habit.name, habit.dose ?? "", "", "", ""]))
            }
        }
        rows.sort { $0.key < $1.key }

        var lines = [header]
        lines.append(contentsOf: rows.map { $0.fields.map(escape).joined(separator: ",") })
        return lines.joined(separator: "\n") + "\n"
    }

    /// RFC 4180 quoting.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
