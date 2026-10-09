import XCTest
@testable import Kept

final class SpeechSplitterTests: XCTestCase {
    func testARunOnSentenceBecomesEntries() {
        let spoken = "Two eggs and toast with black coffee, then five grams of creatine, a thirty minute walk at lunch, and a glass of red wine with dinner."
        XCTAssertEqual(SpeechSplitter.list(from: spoken).components(separatedBy: "\n"), [
            "2 eggs and toast",
            "Black coffee",
            "5 g of creatine",
            "A 30 minute walk at lunch",
            "A glass of red wine with dinner",
        ])
    }

    func testLeadingDayAndFillers() {
        let lines = SpeechSplitter.list(from: "Yesterday I had a turkey sandwich then I took fish oil").components(separatedBy: "\n")
        XCTAssertEqual(lines, ["Yesterday", "A turkey sandwich", "Fish oil"])
    }

    func testTheResultParsesIntoTheRightKinds() {
        let text = SpeechSplitter.list(from: "Oatmeal with blueberries and a latte, also forty five minutes of yoga")
        let today = TestCalendar.day(2026, 10, 8)
        let items = BulkEntryParser.parse(text, defaultDay: today, today: today, calendar: TestCalendar.utc).days[0].items
        XCTAssertEqual(items.map(\.text), ["Oatmeal with blueberries", "A latte", "45 minutes of yoga"])
        XCTAssertEqual(items.map(\.kind), [.food, .drink, .activity])
        XCTAssertEqual(items[2].minutes, 45)
    }

    func testNumberWords() {
        XCTAssertEqual(SpeechSplitter.normalizeNumbers(in: "twenty-five grams of protein"), "25 g of protein")
        XCTAssertEqual(SpeechSplitter.normalizeNumbers(in: "three hundred"), "3 hundred")
        XCTAssertEqual(SpeechSplitter.normalizeNumbers(in: "sixteen ounces of water"), "16 oz of water")
    }

    func testDecimalsThousandsAndNamesStayWhole() {
        let lines = SpeechSplitter.list(from: "I had a Dr. Pepper and 1.5 liters of water, then 1,000 mg of vitamin C. Walked 2.5 miles").components(separatedBy: "\n")
        XCTAssertEqual(lines, ["A Dr Pepper", "1.5 liters of water", "1,000 mg of vitamin C", "Walked 2.5 miles"])
    }

    func testPossessiveDayAndTrailingAnd() {
        XCTAssertEqual(SpeechSplitter.list(from: "Today's lunch was a salad").components(separatedBy: "\n"),
                       ["Today", "Lunch was a salad"])
        XCTAssertEqual(SpeechSplitter.list(from: "I took creatine and later a protein shake").components(separatedBy: "\n"),
                       ["Creatine", "A protein shake"])
        XCTAssertEqual(SpeechSplitter.list(from: "Todays special was soup").components(separatedBy: "\n").first, "Todays special was soup")
    }
}
