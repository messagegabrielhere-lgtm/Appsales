import XCTest
@testable import Kept

final class EstimateParserTests: XCTestCase {
    func testTheRequestedBlock() {
        let answer = """
        Here's your week…

        FUELPRINT-DAILY
        date,calories,protein_g,carbs_g,fat_g,fiber_g
        YYYY-MM-DD,0,0,0,0,0
        2026-10-05,2100,140,180,80,25
        2026-10-06,1950.5,128,150,90,18
        END
        """
        let estimates = EstimateParser.parse(answer)
        XCTAssertEqual(estimates.map(\.day), [DayKey(year: 2026, month: 10, day: 5), DayKey(year: 2026, month: 10, day: 6)])
        XCTAssertEqual(estimates[0].calories, 2100)
        XCTAssertEqual(estimates[0].proteinGrams, 140)
        XCTAssertEqual(estimates[1].calories, 1951)
        XCTAssertEqual(estimates[1].fiberGrams, 18)
    }

    func testMarkdownTableWithRangesAndOwnColumnOrder() {
        let answer = """
        | Date | Protein (g) | Calories | Fiber |
        |---|---|---|---|
        | 2026-10-06 | 120–140 | 1,900-2,200 | 22 g |
        """
        let estimate = EstimateParser.parse(answer)[0]
        XCTAssertEqual(estimate.proteinGrams, 130)
        XCTAssertEqual(estimate.calories, 2050)
        XCTAssertEqual(estimate.fiberGrams, 22)
        XCTAssertNil(estimate.fatGrams)
    }

    func testNutritionPromptsAskForTheBlock() {
        XCTAssertTrue(AIPromptTemplate.nutrition.asksForEstimates)
        XCTAssertFalse(AIPromptTemplate.grocery.asksForEstimates)
        let text = AIExportBuilder.build(AIExportBuilder.Input(
            template: .protein, days: [DayKey(year: 2026, month: 10, day: 6)], habits: [], log: [], aboutMe: nil,
            calendar: TestCalendar.utc))
        XCTAssertTrue(text.contains(EstimateParser.marker))
        XCTAssertTrue(EstimateParser.parse(text).isEmpty, "the template line must not parse as a day")
    }
}
