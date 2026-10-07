import Foundation

/// The span of days an export covers. Today's AI assistants read hundreds of pages at once,
/// so the longer spans are genuinely useful: a year of meals is what shows a trend.
enum AIExportRange: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case week
    case twoWeeks
    case month
    case quarter
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .week: return "7 days"
        case .twoWeeks: return "14 days"
        case .month: return "30 days"
        case .quarter: return "90 days"
        case .year: return "1 year"
        case .all: return "All time"
        }
    }

    /// Oldest first. `firstDay` is the earliest day with data, used by `.all`.
    func days(endingAt today: DayKey, firstDay: DayKey? = nil, calendar: Calendar = .current) -> [DayKey] {
        func last(_ count: Int) -> [DayKey] {
            (0..<count).reversed().map { today.adding(days: -$0, calendar: calendar) }
        }
        switch self {
        case .today: return [today]
        case .yesterday: return [today.adding(days: -1, calendar: calendar)]
        case .week: return last(7)
        case .twoWeeks: return last(14)
        case .month: return last(30)
        case .quarter: return last(90)
        case .year: return last(365)
        case .all:
            guard let firstDay, firstDay < today else { return [today] }
            var days: [DayKey] = []
            var day = firstDay
            while day <= today {
                days.append(day)
                day = day.adding(days: 1, calendar: calendar)
            }
            return days
        }
    }
}

/// How the question list is grouped on screen.
enum AIPromptGroup: String, CaseIterable, Identifiable {
    case understand
    case nutrition
    case health
    case plan
    case ask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .understand: return "Understand my days"
        case .nutrition: return "Nutrition"
        case .health: return "Health habits"
        case .plan: return "Plan ahead"
        case .ask: return "Anything else"
        }
    }

    var templates: [AIPromptTemplate] {
        AIPromptTemplate.allCases.filter { $0.group == self }
    }
}

/// A ready-made analysis request. The instructions are the product: each asks for specific,
/// checkable output, prefers ranges over false precision, and keeps health questions framed as
/// things to raise with a professional rather than advice.
enum AIPromptTemplate: String, CaseIterable, Identifiable {
    case patterns
    case review
    case nutrition
    case protein
    case weight
    case gut
    case sleep
    case hydration
    case supplements
    case heart
    case activity
    case mealPlan
    case grocery
    case doctor
    case custom

    var id: String { rawValue }

    var group: AIPromptGroup {
        switch self {
        case .patterns, .review: return .understand
        case .nutrition, .protein, .weight, .gut: return .nutrition
        case .sleep, .hydration, .supplements, .heart, .activity: return .health
        case .mealPlan, .grocery, .doctor: return .plan
        case .custom: return .ask
        }
    }

    var title: String {
        switch self {
        case .patterns: return "Energy & mood patterns"
        case .review: return "Weekly review"
        case .nutrition: return "Nutrition estimate"
        case .protein: return "Protein check"
        case .weight: return "Weight goal check"
        case .gut: return "Gut health"
        case .sleep: return "Sleep & energy"
        case .hydration: return "Hydration, caffeine & alcohol"
        case .supplements: return "Supplement review"
        case .heart: return "Heart-healthy habits"
        case .activity: return "Activity & recovery"
        case .mealPlan: return "Plan tomorrow's meals"
        case .grocery: return "Grocery list"
        case .doctor: return "Doctor visit summary"
        case .custom: return "Ask your own question"
        }
    }

    var subtitle: String {
        switch self {
        case .patterns: return "What seems to lift or drain you, with experiments to test it."
        case .review: return "Wins, what to improve, scores and one focus for next week."
        case .nutrition: return "Calories, protein, carbs, fat and fiber per day, gaps flagged."
        case .protein: return "Grams per day against your weight and goals, and easy ways to close a gap."
        case .weight: return "Your energy needs against what you eat, and the changes that matter most."
        case .gut: return "Fiber, plant variety, fermented foods, and links to digestion."
        case .sleep: return "Caffeine, alcohol and late meals against how you slept and felt."
        case .hydration: return "Fluids, caffeine and alcohol per day, and their timing."
        case .supplements: return "Consistency, timing, and questions for your pharmacist."
        case .heart: return "Sodium, fats, fiber, alcohol and activity, with questions for your doctor."
        case .activity: return "What you did, how you fueled it, how you felt after."
        case .mealPlan: return "Realistic meals for tomorrow from foods you already like."
        case .grocery: return "Next week's list from what you eat, with a few smart swaps."
        case .doctor: return "A one-page summary and questions to bring to your appointment."
        case .custom: return "Anything you want to know about your log."
        }
    }

    var symbol: String {
        switch self {
        case .patterns: return "waveform.path.ecg"
        case .review: return "checkmark.seal"
        case .nutrition: return "chart.pie"
        case .protein: return "dumbbell"
        case .weight: return "scalemass"
        case .gut: return "leaf"
        case .sleep: return "bed.double"
        case .hydration: return "drop"
        case .supplements: return "pills"
        case .heart: return "heart.text.square"
        case .activity: return "figure.run"
        case .mealPlan: return "fork.knife"
        case .grocery: return "cart"
        case .doctor: return "stethoscope"
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

            1. For each day, estimate calories, protein, carbohydrate, fat and fiber. Where I \
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

            1. For each item, summarize how consistently I took it over the period.
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
            Please analyze my drinks from the log below.

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
            Please analyze my activity alongside my food, drinks and how I felt.

            1. Summarize activity per day: type, duration, and a rough intensity estimate.
            2. Say whether my eating before and after activity looks adequate for recovery.
            3. Note any link between activity and how I felt later that day or the next day.
            4. Suggest a realistic weekly structure built on what I already do.

            \(AIPromptTemplate.notAdvice)
            """
        case .review:
            return """
            Please give me an honest review of the period in my log below.

            1. Three things that went well, citing the days.
            2. Three things to improve, most important first.
            3. Score each from 1 to 10 with one line of reasoning: food quality, protein, \
            hydration, alcohol, activity, and consistency with my checklist.
            4. One small, specific focus for next week.

            Be direct and encouraging. \(AIPromptTemplate.notAdvice)
            """
        case .protein:
            return """
            Please check my protein intake from the log below.

            1. Estimate protein in grams per day and list the main sources. Use the grams I \
            wrote where I gave them, such as "30g protein shake".
            2. Compare with common ranges for my body weight and goals from About Me, stating \
            the range you use. If my weight isn't given, use general adult guidance and say so.
            3. Show how protein is spread across the day.
            4. Suggest easy ways to close any gap using foods I already eat.

            Give ranges rather than false precision. \(AIPromptTemplate.notAdvice)
            """
        case .weight:
            return """
            Please compare what I eat with my weight goal, using About Me (age, sex, height, \
            weight, activity level, goals) and the log below.

            1. Estimate my daily energy needs as a range and explain the method.
            2. Estimate my average daily intake as a range, including drinks and alcohol.
            3. Say whether the two are consistent with my goal and what trend to expect.
            4. Name the three changes with the biggest effect that fit how I already eat.

            If key details are missing from About Me, say what you need. Give ranges rather \
            than false precision. \(AIPromptTemplate.notAdvice)
            """
        case .gut:
            return """
            Please look at my gut health habits in the log below.

            1. Estimate fiber per day and count the different plant foods across the period.
            2. List fermented foods, probiotics and prebiotics, and how often I had them.
            3. Look for links between foods or drinks and anything I noted about digestion, \
            saying how confident you are.
            4. Suggest small additions using foods I already like.

            \(AIPromptTemplate.notAdvice)
            """
        case .sleep:
            return """
            Please look at how caffeine, alcohol, late meals and activity line up with what I \
            noted about sleep, energy and mood.

            1. For each day, note my last caffeine and any alcohol, with times where given. \
            Where entries have no time, use their order in the day.
            2. Point out late or heavy meals and what followed.
            3. List the patterns you see, citing days and saying how confident you are.
            4. Suggest two experiments to try next week.

            \(AIPromptTemplate.notAdvice)
            """
        case .heart:
            return """
            Please review my log for habits commonly discussed in relation to heart health.

            1. Give a rough picture of sodium and saturated fat, naming the biggest contributors.
            2. Estimate fiber and whole-food variety.
            3. Total my alcohol per week, and my activity minutes per week compared with \
            common guidelines.
            4. List questions worth asking my doctor, taking into account my medical history \
            and medications in About Me.

            Do not diagnose anything. \(AIPromptTemplate.notAdvice)
            """
        case .mealPlan:
            return """
            Please plan my meals for tomorrow, based on what I usually eat and enjoy in the log \
            below and my goals in About Me.

            1. Breakfast, lunch, dinner and snacks, each with a rough portion and protein amount.
            2. Mostly foods I already eat, with one or two upgrades marked as such.
            3. Respect any allergies, intolerances and diet preferences in About Me.
            4. Rough totals for the day: calories and protein as ranges.

            \(AIPromptTemplate.notAdvice)
            """
        case .grocery:
            return """
            Please make my grocery list for next week from the log below.

            1. Base it on the foods and drinks I have most often.
            2. Add a few healthier swaps, marked as swaps, that fit my goals in About Me.
            3. Group items by store section with rough quantities for one week.
            4. Respect any allergies, intolerances and diet preferences in About Me.
            """
        case .doctor:
            return """
            Please prepare a one-page summary I can bring to my doctor, from the log below and \
            About Me.

            1. My typical eating pattern and meal timing.
            2. Alcohol, caffeine and nicotine, per week.
            3. Activity per week.
            4. Supplements and medications, with doses and how consistently I took them.
            5. Symptoms or notes I logged, with dates.
            6. Five questions I could ask, taking into account my medical history and \
            medications.

            Keep it plain and factual. Do not diagnose or recommend treatment.
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
        /// Age, height, weight, history and so on. Nil to leave out.
        var profile: UserProfile? = nil
        /// Apple Health by day, when the user includes it.
        var health: [DayKey: HealthDay] = [:]
        var usesPounds = false
        var calendar: Calendar = .current
    }

    /// Width the entry-type column is padded to, so entries line up.
    static let kindColumnWidth = 12

    static func build(_ input: Input) -> String {
        let calendar = input.calendar
        let days = input.days.sorted()
        var lines: [String] = []

        lines.append(input.template.instructions(customQuestion: input.customQuestion))
        lines.append("")

        let profileLines = input.profile?.promptLines ?? []
        let notes = input.aboutMe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !profileLines.isEmpty || !notes.isEmpty {
            lines.append("ABOUT ME")
            lines.append(contentsOf: profileLines)
            if !notes.isEmpty {
                lines.append(profileLines.isEmpty ? notes : "Other notes: \(notes)")
            }
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
        let included = Set(days)
        if input.log.contains(where: { $0.untimed && included.contains($0.day(calendar: calendar)) }) {
            lines.append("Entries marked --:-- have no time; they are in the order I wrote them.")
        }
        lines.append("Feeling ratings run from 1 (awful) to 5 (great).")
        if !input.health.isEmpty {
            lines.append("Apple Health lines come from the iPhone and any watch. Sleep is the night before that day.")
        }

        if !input.habits.isEmpty {
            lines.append("")
            lines.append("Daily checklist (supplements and routines):")
            for habit in input.habits {
                lines.append("- " + describe(habit))
            }
        }

        let byDay = Dictionary(grouping: input.log) { $0.day(calendar: calendar) }
        // Over a month, empty days are noise that costs the AI attention, so they're left out.
        let skipEmptyDays = days.count > AIExportBuilder.longRangeDays
        if skipEmptyDays {
            lines.append("Days with nothing logged are left out.")
        }

        for day in days {
            if skipEmptyDays && (byDay[day] ?? []).isEmpty && !input.habits.contains(where: { $0.isCompleted(on: day) })
                && (input.health[day]?.isEmpty ?? true) {
                continue
            }
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

            if let health = input.health[day]?.line(usesPounds: input.usesPounds) {
                lines.append(health)
            }

            let entries = (byDay[day] ?? []).sorted { $0.date < $1.date }
            let water = LogInsights.waterMilliliters(of: entries)
            if water > 0 {
                lines.append("Water total: \(water) ml")
            }
            if entries.isEmpty && (input.health[day]?.isEmpty ?? true) {
                lines.append("Nothing logged.")
            }
            for entry in entries {
                lines.append(line(for: entry, calendar: calendar))
            }
        }

        lines.append("")
        lines.append(closingNote)
        lines.append("(Exported from \(Brand.name).)")
        return lines.joined(separator: "\n")
    }

    /// Periods longer than this leave out days with nothing logged.
    static let longRangeDays = 31

    /// Added to every prompt, whatever the template.
    static let closingNote = "You are an AI assistant, not my doctor, and this is not medical advice. If anything in my log or About Me could need medical attention, tell me plainly to check with a professional."

    // MARK: Pieces, internal for tests

    static func line(for entry: LogEntry, calendar: Calendar) -> String {
        let time = entry.untimed ? "--:--" : formatter("HH:mm", calendar: calendar).string(from: entry.date)
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
