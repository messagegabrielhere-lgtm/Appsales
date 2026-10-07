import XCTest
@testable import Kept

final class BulkEntryParserTests: XCTestCase {
    private let calendar = TestCalendar.utc
    private let today = TestCalendar.day(2026, 10, 8)

    private func parse(_ text: String, habits: [Habit] = [], monthFirst: Bool = true) -> BulkEntryParser.Result {
        BulkEntryParser.parse(
            text,
            defaultDay: today,
            today: today,
            habits: habits,
            glassMilliliters: 250,
            monthFirst: monthFirst,
            calendar: calendar
        )
    }

    // MARK: Days

    func testAListWithoutDatesGoesToTheDefaultDayInOrder() {
        let result = parse("Oatmeal\n\n  Black coffee  \nBanana\n")
        XCTAssertEqual(result.days.map(\.day), [today])
        XCTAssertEqual(result.days[0].items.map(\.text), ["Oatmeal", "Black coffee", "Banana"])
        XCTAssertTrue(result.preamble.isEmpty)
    }

    func testDateLinesSplitDaysAndTextBeforeTheFirstDateIsPreamble() {
        let text = """
        Daily Intake

        Some notes about me

        09/26/26 -
        Steak and eggs
        Water

        9/28/26 -
        Kimchi

        10/01/26:
        Halibut and rice
        """
        let result = parse(text)
        XCTAssertEqual(result.preamble, ["Daily Intake", "Some notes about me"])
        XCTAssertEqual(result.days.map(\.day), [
            TestCalendar.day(2026, 9, 26), TestCalendar.day(2026, 9, 28), TestCalendar.day(2026, 10, 1),
        ])
        XCTAssertEqual(result.days[0].items.map(\.text), ["Steak and eggs", "Water"])
        XCTAssertEqual(result.itemCount, 4)
    }

    func testDateFormats() {
        func day(_ line: String, monthFirst: Bool = true) -> DayKey? {
            BulkEntryParser.dateHeader(line, today: today, monthFirst: monthFirst, calendar: calendar)?.day
        }
        XCTAssertEqual(day("10/06/26 -"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("10/6/2026"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("10/6"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("2026-10-06"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("Oct 6"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("October 6th, 2026:"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("Tuesday, October 6"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("6 Oct"), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("## Mon 10/5"), TestCalendar.day(2026, 10, 5))
        XCTAssertEqual(day("Today"), today)
        XCTAssertEqual(day("Yesterday:"), TestCalendar.day(2026, 10, 7))
        XCTAssertEqual(day("06/10/26", monthFirst: false), TestCalendar.day(2026, 10, 6))
        XCTAssertEqual(day("13/10/26"), TestCalendar.day(2026, 10, 13), "no month 13, so day first")
        // Without a year, the most recent past date: December is last year in October.
        XCTAssertEqual(day("12/25"), TestCalendar.day(2025, 12, 25))
    }

    func testFoodThatLooksLikeADateIsNotADate() {
        for line in ["1/2 avocado", "2/3 cup oats", "5.5", "Marathon 5", "Mayo 2 tbsp", "Sun 2 hours", "2/31/26"] {
            XCTAssertNil(BulkEntryParser.dateHeader(line, today: today, monthFirst: true, calendar: calendar), line)
        }
    }

    func testDateAndEntryOnOneLine() {
        let result = parse("10/06/26 - Steak salad\nWater")
        XCTAssertEqual(result.days.map(\.day), [TestCalendar.day(2026, 10, 6)])
        XCTAssertEqual(result.days[0].items.map(\.text), ["Steak salad", "Water"])
    }

    func testFutureDatesAreSkipped() {
        let result = parse("10/07/26\nToast\n10/20/26\nPlanned dinner\nDessert")
        XCTAssertEqual(result.days.map(\.day), [TestCalendar.day(2026, 10, 7)])
        XCTAssertEqual(result.futureLines, 2)
    }

    func testRepeatedDateMergesIntoOneDay() {
        let result = parse("10/06/26\nToast\n10/07/26\nSoup\n10/06/26\nPie")
        XCTAssertEqual(result.days.map(\.day), [TestCalendar.day(2026, 10, 6), TestCalendar.day(2026, 10, 7)])
        XCTAssertEqual(result.days[0].items.map(\.text), ["Toast", "Pie"])
    }

    func testBulletsNumbersAndCheckboxesAreStripped() {
        XCTAssertEqual(BulkEntryParser.clean("- Toast"), "Toast")
        XCTAssertEqual(BulkEntryParser.clean("• Toast"), "Toast")
        XCTAssertEqual(BulkEntryParser.clean("3. Toast"), "Toast")
        XCTAssertEqual(BulkEntryParser.clean("- [x] Toast"), "Toast")
        XCTAssertEqual(BulkEntryParser.clean("1.5 mile walk"), "1.5 mile walk")
        XCTAssertEqual(BulkEntryParser.clean("2 eggs"), "2 eggs")
    }

    // MARK: Kinds

    func testClassification() {
        let expected: [String: LogKind] = [
            "Two strips of steak": .food,
            "Steak filet": .food,
            "Green beans": .food,
            "Mini protein bar": .food,
            "Probiotic yogurt": .food,
            "Popcorn with a bit of butter": .food,
            "Tart cherry pie with milk": .food,
            "Miso soup with seaweed and tofu": .food,
            "Smoked roast": .food,
            "Half can of black beans": .food,
            "Two cups black coffee with half and half": .drink,
            "Glass of tomato juice with lime": .drink,
            "30g protein shake": .drink,
            "Two glasses of Merlot": .drink,
            "9oz Shiraz": .drink,
            "Dirty martini": .drink,
            "Espresso with cream": .drink,
            "Sparkling water": .drink,
            "Coconut water": .drink,
            "Water": .drink,
            "Probiotic yogurt drink": .drink,
            "5g creatine": .supplement,
            "Creatine water": .supplement,
            "Biotin gummies": .supplement,
            "Fish oil": .supplement,
            "Magnesium glycinate": .supplement,
            "Ashwagandha": .supplement,
            "Vitamin D 2000 IU": .supplement,
            "Zinc 15mg": .supplement,
            "Heavy yard work for an hour": .activity,
            "1.5 mile walk": .activity,
            "45 min strength training": .activity,
            "Yoga": .activity,
            "Cigar": .note,
            "Dentist check up, all clear": .note,
            "Felt sluggish after lunch": .feeling,
            "Headache in the afternoon": .feeling,
            "Slept 6 hours": .feeling,
        ]
        for (line, kind) in expected {
            XCTAssertEqual(BulkEntryParser.classify(line), kind, line)
        }
    }

    func testWordsMatchWholeWordsOnly() {
        // "steak" contains "tea", "ginger" contains "gin", "crumble" contains "rum".
        XCTAssertEqual(BulkEntryParser.classify("Steak"), .food)
        XCTAssertEqual(BulkEntryParser.classify("Ginger chicken"), .food)
        XCTAssertEqual(BulkEntryParser.classify("Apple crumble"), .food)
    }

    // MARK: Amounts

    func testDrinkVolumes() {
        XCTAssertEqual(BulkEntryParser.milliliters(in: "9oz shiraz"), 266)
        XCTAssertEqual(BulkEntryParser.milliliters(in: "500 ml water"), 500)
        XCTAssertEqual(BulkEntryParser.milliliters(in: "1.5 l water"), 1500)
        XCTAssertEqual(BulkEntryParser.milliliters(in: "12 fl oz soda"), 355)
        XCTAssertNil(BulkEntryParser.milliliters(in: "black coffee"))
    }

    func testPlainWaterCountsAsAGlass() {
        let result = parse("Water\nGlass of water\nCoconut water\n16 oz water")
        let items = result.days[0].items
        XCTAssertEqual(items.map(\.milliliters), [250, 250, nil, 473])
    }

    func testActivityDurations() {
        XCTAssertEqual(BulkEntryParser.minutes(in: "heavy yard work for an hour"), 60)
        XCTAssertEqual(BulkEntryParser.minutes(in: "45 min strength training"), 45)
        XCTAssertEqual(BulkEntryParser.minutes(in: "1.5 hours hiking"), 90)
        XCTAssertEqual(BulkEntryParser.minutes(in: "half an hour of yoga"), 30)
        XCTAssertNil(BulkEntryParser.minutes(in: "1.5 mile walk"))
    }

    func testChangingKindRecomputesAmounts() {
        let item = parse("16 oz water").days[0].items[0]
        let asFood = BulkEntryParser.with(item, kind: .food, glassMilliliters: 250)
        XCTAssertEqual(asFood.kind, .food)
        XCTAssertNil(asFood.milliliters)
        XCTAssertEqual(BulkEntryParser.with(asFood, kind: .drink, glassMilliliters: 250).milliliters, 473)
    }

    // MARK: Checklist and duplicates

    func testLinesNamingAChecklistItemAreLinkedToIt() {
        let creatine = Habit(name: "Creatine", createdAt: TestCalendar.date(2026, 1, 1))
        let result = parse("5g creatine\nToast", habits: [creatine])
        XCTAssertEqual(result.days[0].items.map(\.habitID), [creatine.id, nil])
    }

    func testDuplicatesAlreadyLoggedAreRemovedCountingRepeats() {
        let day = TestCalendar.day(2026, 10, 6)
        let log = [
            LogEntry(kind: .drink, date: TestCalendar.date(2026, 10, 6, 9), text: "Water"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 10, 6, 12), text: "steak salad"),
            LogEntry(kind: .food, date: TestCalendar.date(2026, 10, 5, 12), text: "Toast"),
        ]
        let result = parse("10/06/26\nWater\nWater\nSteak salad!\nToast")
        let (days, skipped) = BulkEntryParser.removingDuplicates(of: result.days, in: log, calendar: calendar)
        XCTAssertEqual(skipped, 2)
        XCTAssertEqual(days.map(\.day), [day])
        XCTAssertEqual(days[0].items.map(\.text), ["Water", "Toast"])
    }

    func testUntimedDatesKeepOrderInsideTheDay() {
        let day = TestCalendar.day(2026, 10, 6)
        let first = LogEntry.untimedDate(on: day, index: 0, calendar: calendar)
        let second = LogEntry.untimedDate(on: day, index: 1, calendar: calendar)
        XCTAssertLessThan(first, second)
        XCTAssertEqual(DayKey(second, calendar: calendar), day)
    }

    func testTypeLabels() {
        let result = parse("Activity: yard work\nSupplement: fish oil\nBreakfast: eggs\nMood: good\n8:15 coffee\nNote: dentist")
        let items = result.days[0].items
        XCTAssertEqual(items.map(\.text), ["yard work", "fish oil", "Breakfast: eggs", "Mood: good", "8:15 coffee", "dentist"])
        XCTAssertEqual(items.map(\.kind), [.activity, .supplement, .food, .feeling, .drink, .note])
    }
}
