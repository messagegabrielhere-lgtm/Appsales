import XCTest
@testable import Kept

final class LabelParserTests: XCTestCase {
    func testNutritionFactsPanel() {
        let lines = ["Peanut Butter Bar", "Nutrition Facts", "Serving size 1 bar (60g)", "Calories 250",
                     "Total Fat 10g 13%", "Total Carbohydrate 24g 9%", "Dietary Fiber 5g", "Total Sugars 8g", "Protein 20g"]
        XCTAssertEqual(LabelParser.line(from: lines),
                       "Food: Peanut Butter Bar (serving 1 bar (60g), 250 kcal, 20 g protein, 24 g carbs, 10 g fat, 5 g fiber, 8 g sugar)")
    }

    func testSupplementFactsPanel() {
        let lines = ["Supplement Facts", "Serving Size 2 Capsules", "Amount Per Serving %DV",
                     "Magnesium (as magnesium glycinate) 400 mg 95%"]
        XCTAssertEqual(LabelParser.line(from: lines), "Supplement: Magnesium (as magnesium glycinate) 400 mg")
    }

    func testMultivitaminSummarizes() {
        let lines = ["Daily Multi", "Supplement Facts", "Vitamin A 900mcg", "Vitamin C 90 mg", "Vitamin D3 50 mcg", "Zinc 11 mg", "Iodine 150 mcg"]
        XCTAssertEqual(LabelParser.line(from: lines), "Supplement: Daily Multi (Vitamin A 900 mcg, Vitamin C 90 mg, Vitamin D3 50 mcg and 2 more)")
    }

    func testTheLineParsesWithTheRightKind() {
        let line = LabelParser.line(from: ["Supplement Facts", "Creatine Monohydrate 5 g"])!
        let today = TestCalendar.day(2026, 10, 8)
        let item = BulkEntryParser.parse(line, defaultDay: today, today: today, calendar: TestCalendar.utc).days[0].items[0]
        XCTAssertEqual(item.kind, .supplement)
        XCTAssertEqual(item.text, "Creatine Monohydrate 5 g")
    }
}
