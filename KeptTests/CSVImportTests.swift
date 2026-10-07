import XCTest
@testable import Kept

final class CSVImportTests: XCTestCase {
    private let calendar = TestCalendar.utc
    private let today = TestCalendar.day(2026, 10, 8)

    private func convert(_ csv: String) -> CSVImport.Conversion? {
        CSVImport.convert(csv, today: today, monthFirst: true, calendar: calendar)
    }

    func testQuotedFieldsCommasNewlinesAndEscapedQuotes() {
        let rows = CSVImport.rows("a,b,c\r\n\"x, y\",\"say \"\"hi\"\"\",\"two\nlines\"\n1,2,3")
        XCTAssertEqual(rows, [["a", "b", "c"], ["x, y", "say \"hi\"", "two\nlines"], ["1", "2", "3"]])
    }

    func testSemicolonAndTabDelimitersAreDetected() {
        XCTAssertEqual(CSVImport.rows("date;food\n2026-10-06;Toast"), [["date", "food"], ["2026-10-06", "Toast"]])
        XCTAssertEqual(CSVImport.rows("date\tfood\n2026-10-06\tToast"), [["date", "food"], ["2026-10-06", "Toast"]])
    }

    func testFoodTrackerStyleExport() {
        let csv = """
        Day,Time,Group,Food Name,Amount,Energy (kcal),Protein (g)
        2026-10-06,08:00,Breakfast,Oatmeal,1 cup,150,5
        2026-10-06,13:00,Lunch,Chicken salad,1 bowl,420,38.5
        2026-10-05,19:00,Dinner,Salmon,6 oz,350,34
        """
        let result = convert(csv)!
        XCTAssertEqual(result.rows, 3)
        XCTAssertEqual(result.text, """
        2026-10-05
        Dinner: Salmon (6 oz, 350 kcal, 34 g protein)

        2026-10-06
        Breakfast: Oatmeal (1 cup, 150 kcal, 5 g protein)
        Lunch: Chicken salad (1 bowl, 420 kcal, 38.5 g protein)
        """)

        let parsed = BulkEntryParser.parse(result.text, defaultDay: today, today: today, monthFirst: true, calendar: calendar)
        XCTAssertEqual(parsed.days.map(\.day), [TestCalendar.day(2026, 10, 5), TestCalendar.day(2026, 10, 6)])
        XCTAssertEqual(parsed.days[1].items.map(\.kind), [.food, .food])
        XCTAssertEqual(parsed.days[1].items[0].text, "Breakfast: Oatmeal (1 cup, 150 kcal, 5 g protein)")
    }

    func testExerciseRowsBecomeActivityAndQuantityJoinsUnits() {
        let csv = """
        Date,Name,Type,Quantity,Units,Calories
        10/06/2026,Elliptical,Exercise,30,minutes,-250
        10/06/2026,Banana,Snacks,1,each,105
        """
        let parsed = BulkEntryParser.parse(convert(csv)!.text, defaultDay: today, today: today, monthFirst: true, calendar: calendar)
        let items = parsed.days[0].items
        XCTAssertEqual(items.map(\.kind), [.activity, .food])
        XCTAssertEqual(items[0].text, "Elliptical (30 minutes)")
        XCTAssertEqual(items[0].minutes, 30)
        XCTAssertEqual(items[1].text, "Snacks: Banana (1 each, 105 kcal)")
    }

    func testMoodJournalStyleExport() {
        let csv = """
        full_date,date,weekday,time,mood,activities,note_title,note
        2026-10-06,October 6,Tuesday,21:00,good,gym | reading,,Slept well after the walk
        """
        let parsed = BulkEntryParser.parse(convert(csv)!.text, defaultDay: today, today: today, monthFirst: true, calendar: calendar)
        let items = parsed.days[0].items
        XCTAssertEqual(items.map(\.text), ["gym | reading", "Mood: good", "Slept well after the walk"])
        XCTAssertEqual(items.map(\.kind), [.activity, .feeling, .note])
    }

    func testFuelprintsOwnExportRoundTrips() {
        let log = [
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 10, 6, 8), text: "Water", milliliters: 500),
            LogEntry(kind: .supplement, date: TestCalendar.date(2026, 10, 6, 9), text: "Creatine", amount: "5 g"),
            LogEntry(kind: .activity, date: TestCalendar.date(2026, 10, 6, 18), text: "Run", minutes: 30),
        ]
        let csv = CSVExport.csv(log: log, habits: [], calendar: calendar)
        let parsed = BulkEntryParser.parse(convert(csv)!.text, defaultDay: today, today: today, monthFirst: true, calendar: calendar)
        let items = parsed.days[0].items
        XCTAssertEqual(items.map(\.kind), [.drink, .supplement, .activity])
        XCTAssertEqual(items[0].milliliters, 500)
        XCTAssertEqual(items[2].minutes, 30)
    }

    func testRowsWithoutReadableDatesAreCountedAndAFileWithoutADateColumnIsRejected() {
        let result = convert("Date,Food\n2026-10-06,Toast\nsometime,Soup\n")!
        XCTAssertEqual(result.rows, 1)
        XCTAssertEqual(result.skippedRows, 1)
        XCTAssertNil(convert("Food,Calories\nToast,100"))
    }

    func testDateValues() {
        func day(_ raw: String) -> DayKey? {
            CSVImport.parseDay(raw, today: today, monthFirst: true, calendar: calendar)
        }
        XCTAssertEqual(day("2026-10-06T08:15:00Z"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("2026-10-06 08:15"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("10/06/2026 8:15 AM"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("Oct 6, 2026"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("Tuesday, October 6, 2026 at 9:00"), TestCalendar.day(2026, 10, 6))
        XCTAssertNil(day(""))
    }
}
