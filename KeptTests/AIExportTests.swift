import XCTest
@testable import Kept

/// The export is what users paste into their AI, so its exact shape matters.
/// September 2026: the 19th is a Saturday, the 20th Sunday, the 21st Monday.
final class AIExportTests: XCTestCase {
    private let calendar = TestCalendar.utc

    // MARK: Ranges

    func testRangesAreOldestFirstAndEndToday() {
        let today = TestCalendar.day(2026, 9, 21)
        XCTAssertEqual(AIExportRange.today.days(endingAt: today, calendar: calendar), [today])
        XCTAssertEqual(AIExportRange.yesterday.days(endingAt: today, calendar: calendar), [TestCalendar.day(2026, 9, 20)])

        let week = AIExportRange.week.days(endingAt: today, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, TestCalendar.day(2026, 9, 15))
        XCTAssertEqual(week.last, today)

        let month = AIExportRange.month.days(endingAt: today, calendar: calendar)
        XCTAssertEqual(month.count, 30)
        XCTAssertEqual(month.first, TestCalendar.day(2026, 8, 23))
        XCTAssertEqual(month, month.sorted())
    }

    // MARK: Lines

    func testEntryLinesAlignAndCarryTheirDetails() {
        func line(_ entry: LogEntry) -> String { AIExportBuilder.line(for: entry, calendar: calendar) }

        XCTAssertEqual(
            line(LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 7, 45), text: "Oatmeal", amount: "1 bowl")),
            "07:45  Food        Oatmeal (1 bowl)"
        )
        XCTAssertEqual(
            line(LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 19, 8), text: "Water", milliliters: 500)),
            "08:00  Drink       Water (500 ml)"
        )
        XCTAssertEqual(
            line(LogEntry(kind: .activity, date: TestCalendar.date(2026, 9, 19, 18, 15), text: "Run", minutes: 35)),
            "18:15  Activity    Run (35 min)"
        )
        XCTAssertEqual(
            line(LogEntry(kind: .feeling, date: TestCalendar.date(2026, 9, 19, 21), text: "tired", rating: 3)),
            "21:00  Feeling     3/5 tired"
        )
        XCTAssertEqual(
            line(LogEntry(kind: .feeling, date: TestCalendar.date(2026, 9, 19, 21), text: "", rating: 4)),
            "21:00  Feeling     4/5"
        )
    }

    func testMultiLineTextIsFlattenedToOneLine() {
        let entry = LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 12), text: "Soup\nand bread")
        XCTAssertEqual(AIExportBuilder.line(for: entry, calendar: calendar), "12:00  Food        Soup and bread")
    }

    func testHabitDescriptions() {
        XCTAssertEqual(
            AIExportBuilder.describe(Habit(name: "Magnesium", scheduledWeekdays: Habit.weekdays, reminderMinutes: 21 * 60 + 30, dose: "400 mg")),
            "Magnesium, 400 mg, weekdays, reminder at 21:30"
        )
        XCTAssertEqual(AIExportBuilder.describe(Habit(name: "Walk")), "Walk, every day")
        XCTAssertEqual(AIExportBuilder.scheduleText(Habit(name: "X", scheduledWeekdays: [2, 4, 6])), "Mon Wed Fri")
        XCTAssertEqual(AIExportBuilder.scheduleText(Habit(name: "X", scheduledWeekdays: [1, 7])), "weekends")
    }

    /// A habit added today must not appear as "missed" for every earlier day, unless the user
    /// back-filled ticks before it was created.
    func testHabitsCountOnlyFromWhenTheyExisted() {
        let created = TestCalendar.date(2026, 9, 21, 9)
        let fresh = Habit(name: "New", createdAt: created)
        XCTAssertFalse(AIExportBuilder.isTracked(fresh, on: TestCalendar.day(2026, 9, 20), calendar: calendar))
        XCTAssertTrue(AIExportBuilder.isTracked(fresh, on: TestCalendar.day(2026, 9, 21), calendar: calendar))

        let backfilled = Habit(name: "Old", createdAt: created, completions: [TestCalendar.day(2026, 9, 15)])
        XCTAssertTrue(AIExportBuilder.isTracked(backfilled, on: TestCalendar.day(2026, 9, 16), calendar: calendar))
    }

    // MARK: Whole document

    private func sampleInput(template: AIPromptTemplate = .patterns, aboutMe: String? = nil, question: String = "") -> AIExportBuilder.Input {
        let habits = [
            Habit(name: "Vitamin D", createdAt: TestCalendar.date(2026, 9, 1), completions: [TestCalendar.day(2026, 9, 19)], dose: "2000 IU"),
            Habit(name: "Magnesium", createdAt: TestCalendar.date(2026, 9, 1), scheduledWeekdays: Habit.weekdays),
            Habit(name: "New thing", createdAt: TestCalendar.date(2026, 9, 21, 9)),
        ]
        let log = [
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 7, 45), text: "Oatmeal", amount: "1 bowl"),
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 19, 8), text: "Water", milliliters: 500),
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 9, 19, 8, 30), text: "Coffee", milliliters: 240),
            LogEntry(kind: .feeling, date: TestCalendar.date(2026, 9, 21, 16), text: "Slump", rating: 2),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 25, 12), text: "Outside the range"),
        ]
        return AIExportBuilder.Input(
            template: template,
            customQuestion: question,
            days: [TestCalendar.day(2026, 9, 21), TestCalendar.day(2026, 9, 19), TestCalendar.day(2026, 9, 20)],
            habits: habits,
            log: log,
            aboutMe: aboutMe,
            calendar: calendar
        )
    }

    func testDocumentStructure() {
        let text = AIExportBuilder.build(sampleInput())
        let lines = text.components(separatedBy: "\n")

        XCTAssertTrue(text.hasPrefix(AIPromptTemplate.patterns.instructions(customQuestion: "")))
        XCTAssertTrue(lines.contains("Period: Saturday 19 September 2026 to Monday 21 September 2026 (3 days)"))
        XCTAssertTrue(lines.contains("- Vitamin D, 2000 IU, every day"))
        XCTAssertTrue(lines.contains("- Magnesium, weekdays"))

        XCTAssertTrue(lines.contains("## Saturday 19 September 2026"))
        XCTAssertTrue(lines.contains("Checklist: Vitamin D done; Magnesium rest day"))
        XCTAssertTrue(lines.contains("Water total: 500 ml"))
        XCTAssertTrue(lines.contains("07:45  Food        Oatmeal (1 bowl)"))

        XCTAssertTrue(lines.contains("## Sunday 20 September 2026"))
        XCTAssertTrue(lines.contains("Nothing logged."))

        XCTAssertTrue(lines.contains("Checklist: Vitamin D missed; Magnesium missed; New thing missed"))
        XCTAssertTrue(lines.contains("16:00  Feeling     2/5 Slump"))

        XCTAssertFalse(text.contains("Outside the range"))
        XCTAssertFalse(text.contains("ABOUT ME"))

        // Days appear in order even though they were passed out of order.
        let saturday = lines.firstIndex(of: "## Saturday 19 September 2026")!
        let sunday = lines.firstIndex(of: "## Sunday 20 September 2026")!
        let monday = lines.firstIndex(of: "## Monday 21 September 2026")!
        XCTAssertLessThan(saturday, sunday)
        XCTAssertLessThan(sunday, monday)
    }

    func testAboutMeIsIncludedOnlyWhenGiven() {
        XCTAssertTrue(AIExportBuilder.build(sampleInput(aboutMe: "34, runner")).contains("ABOUT ME\n34, runner"))
        XCTAssertFalse(AIExportBuilder.build(sampleInput(aboutMe: "   ")).contains("ABOUT ME"))
    }

    func testCustomQuestionIsEmbedded() {
        XCTAssertTrue(AIExportBuilder.build(sampleInput(template: .custom, question: "Why am I tired?")).contains("My question: Why am I tired?"))
        XCTAssertTrue(AIExportBuilder.build(sampleInput(template: .custom)).contains("My question: What stands out in my log?"))
    }

    func testEveryTemplateHasInstructionsAndTheSupplementOneDefersToProfessionals() {
        for template in AIPromptTemplate.allCases {
            XCTAssertFalse(template.instructions(customQuestion: "").isEmpty, template.rawValue)
            XCTAssertFalse(template.title.isEmpty)
            XCTAssertFalse(template.subtitle.isEmpty)
        }
        let supplements = AIPromptTemplate.supplements.instructions(customQuestion: "")
        XCTAssertTrue(supplements.contains("Do not tell me to start, stop or change anything"))
        XCTAssertTrue(supplements.contains("pharmacist"))
    }

    // MARK: CSV

    func testCSVEscaping() {
        XCTAssertEqual(CSVExport.escape("plain"), "plain")
        XCTAssertEqual(CSVExport.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExport.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExport.escape("line\nbreak"), "\"line\nbreak\"")
    }

    func testCSVRows() {
        let log = [LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 7, 45), text: "Eggs, toast", amount: "1 plate")]
        let habits = [Habit(name: "Vitamin D", completions: [TestCalendar.day(2026, 9, 19)], dose: "2000 IU")]
        let rows = CSVExport.csv(log: log, habits: habits, calendar: calendar).components(separatedBy: "\n")

        XCTAssertEqual(rows.first, CSVExport.header)
        let checklist = rows.firstIndex(of: "2026-09-19,,checklist,Vitamin D,2000 IU,,,")
        let food = rows.firstIndex(of: "2026-09-19,07:45,food,\"Eggs, toast\",1 plate,,,")
        XCTAssertNotNil(checklist, rows.joined(separator: "\n"))
        XCTAssertNotNil(food, rows.joined(separator: "\n"))
        XCTAssertLessThan(checklist!, food!)
    }

    // MARK: 2.1

    func testProfileLinesComeFirstInAboutMe() {
        var profile = UserProfile()
        profile.age = "39"
        profile.height = "6 ft 4 in"
        profile.medications = "None"
        var input = sampleInput(aboutMe: "Night shifts")
        input.profile = profile
        let text = AIExportBuilder.build(input)
        XCTAssertTrue(text.contains("ABOUT ME\nAge: 39\nHeight: 6 ft 4 in\nMedications: None\nOther notes: Night shifts\n"), text)
    }

    func testEmptyProfileAndNotesLeaveAboutMeOut() {
        var input = sampleInput(aboutMe: " ")
        input.profile = UserProfile()
        XCTAssertFalse(AIExportBuilder.build(input).contains("ABOUT ME"))
    }

    func testUntimedEntriesShowNoTimeAndAreExplained() {
        let entry = LogEntry(kind: .supplement, date: TestCalendar.date(2026, 9, 19, 12), text: "5g creatine", untimed: true)
        XCTAssertEqual(AIExportBuilder.line(for: entry, calendar: calendar), "--:--  Supplement  5g creatine")

        var input = sampleInput()
        XCTAssertFalse(AIExportBuilder.build(input).contains("--:--"))
        input.log.append(entry)
        XCTAssertTrue(AIExportBuilder.build(input).contains("Entries marked --:-- have no time"))
    }

    func testEveryPromptEndsWithTheMedicalReminder() {
        for template in AIPromptTemplate.allCases {
            let text = AIExportBuilder.build(sampleInput(template: template))
            XCTAssertTrue(text.contains(AIExportBuilder.closingNote), template.rawValue)
        }
    }

    func testEveryTemplateBelongsToAGroupOnce() {
        let grouped = AIPromptGroup.allCases.flatMap(\.templates)
        XCTAssertEqual(grouped.count, AIPromptTemplate.allCases.count)
        XCTAssertEqual(Set(grouped), Set(AIPromptTemplate.allCases))
    }

    func testTwoWeeksIsFourteenDays() {
        let days = AIExportRange.twoWeeks.days(endingAt: TestCalendar.day(2026, 9, 21), calendar: calendar)
        XCTAssertEqual(days.count, 14)
        XCTAssertEqual(days.first, TestCalendar.day(2026, 9, 8))
    }

    func testAssistantLinksCarryThePromptUntilItIsTooLong() {
        let short = AIAssistant.chatgpt.destination(for: "Hi & bye?")
        XCTAssertTrue(short.prefilled)
        XCTAssertEqual(short.url.absoluteString, "https://chatgpt.com/?q=Hi%20%26%20bye%3F")

        let long = AIAssistant.claude.destination(for: String(repeating: "steak ", count: 2000))
        XCTAssertFalse(long.prefilled)
        XCTAssertEqual(long.url.absoluteString, "https://claude.ai/new")

        XCTAssertFalse(AIAssistant.gemini.destination(for: "Hi").prefilled)
    }

    func testLongerPeriods() {
        let today = TestCalendar.day(2026, 9, 21)
        XCTAssertEqual(AIExportRange.quarter.days(endingAt: today, calendar: calendar).count, 90)
        XCTAssertEqual(AIExportRange.year.days(endingAt: today, calendar: calendar).count, 365)
        let all = AIExportRange.all.days(endingAt: today, firstDay: TestCalendar.day(2026, 9, 1), calendar: calendar)
        XCTAssertEqual(all.first, TestCalendar.day(2026, 9, 1))
        XCTAssertEqual(all.count, 21)
        XCTAssertEqual(AIExportRange.all.days(endingAt: today, calendar: calendar), [today])
    }

    func testLongPeriodsLeaveOutEmptyDays() {
        var input = sampleInput()
        input.days = AIExportRange.quarter.days(endingAt: TestCalendar.day(2026, 9, 21), calendar: calendar)
        let text = AIExportBuilder.build(input)
        XCTAssertTrue(text.contains("Days with nothing logged are left out."))
        XCTAssertFalse(text.contains("Nothing logged."))
        XCTAssertTrue(text.contains("## Saturday 19 September 2026"))
        XCTAssertTrue(text.contains("## Monday 21 September 2026"))
        XCTAssertFalse(text.contains("## Sunday 20 September 2026"))
    }
}
