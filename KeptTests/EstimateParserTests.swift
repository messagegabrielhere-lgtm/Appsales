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

    func testHowAssistantsReallyWriteIt() {
        let answer = """
        From 2026-10-01 to 2026-10-07 you averaged about 2,050 kcal.

        | Day | Calories | Protein |
        | 2026-10-02 | 1800 | 90 g (20%) |

        ```
        **FUELPRINT-DAILY**
        date,calories,protein_g,carbs_g,fat_g,fiber_g
        2026-10-05,"1,850",112,,70,28
        2026-10-06,2,100,140,n/a,80,25
        2026-10-07,0,0,0,0,0
        END
        ```
        """
        let estimates = EstimateParser.parse(answer)
        XCTAssertEqual(estimates.map(\.day), [DayKey(year: 2026, month: 10, day: 5), DayKey(year: 2026, month: 10, day: 6)],
                       "only the block counts, and an all-zero day is skipped")
        XCTAssertEqual(estimates[0].calories, 1850)
        XCTAssertNil(estimates[0].carbsGrams, "an empty cell leaves its column empty")
        XCTAssertEqual(estimates[0].fatGrams, 70)
        XCTAssertEqual(estimates[0].fiberGrams, 28)
        XCTAssertEqual(estimates[1].calories, 2100)
        XCTAssertEqual(estimates[1].proteinGrams, 140)
        XCTAssertNil(estimates[1].carbsGrams)
        XCTAssertEqual(estimates[1].fiberGrams, 25)
    }

    func testTablePercentagesAndProseSpans() {
        let answer = """
        Over 2026-10-01 to 2026-10-07 you averaged 2,050 kcal.
        | Date | Calories | Protein | Carbs |
        | 2026-10-02 | 1800 | 140 g (27%) | 200 |
        """
        let estimates = EstimateParser.parse(answer)
        XCTAssertEqual(estimates.count, 1)
        XCTAssertEqual(estimates[0].proteinGrams, 140)
        XCTAssertEqual(estimates[0].carbsGrams, 200)
    }
}
