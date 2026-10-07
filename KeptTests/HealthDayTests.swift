import XCTest
@testable import Kept

final class HealthDayTests: XCTestCase {
    func testLineListsWhatIsThere() {
        var day = HealthDay()
        XCTAssertNil(day.line(usesPounds: true))
        day.steps = 8432
        day.sleepHours = 7.2
        day.workouts = ["Running 32 min"]
        day.weightKilograms = 127
        day.restingHeartRate = 61
        XCTAssertEqual(day.line(usesPounds: true),
                       "Apple Health: slept 7.2 h; 8,432 steps; workouts: Running 32 min; weight 280.0 lb (127.0 kg); resting heart rate 61 bpm")
        XCTAssertEqual(day.line(usesPounds: false),
                       "Apple Health: slept 7.2 h; 8,432 steps; workouts: Running 32 min; weight 127.0 kg; resting heart rate 61 bpm")
    }

    func testHealthAppearsInThePromptAndKeepsOtherwiseEmptyDays() {
        let day = TestCalendar.day(2026, 10, 6)
        var health = HealthDay()
        health.steps = 12000
        let text = AIExportBuilder.build(AIExportBuilder.Input(
            template: .sleep,
            days: AIExportRange.quarter.days(endingAt: TestCalendar.day(2026, 10, 8), calendar: TestCalendar.utc),
            habits: [],
            log: [],
            aboutMe: nil,
            health: [day: health],
            calendar: TestCalendar.utc
        ))
        XCTAssertTrue(text.contains("## Tuesday 6 October 2026\nApple Health: 12,000 steps"), text)
        XCTAssertTrue(text.contains("Apple Health lines come from the iPhone"))
    }
}
