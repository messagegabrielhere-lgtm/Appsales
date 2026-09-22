import XCTest
@testable import Kept

final class HabitCodableTests: XCTestCase {
    func testDecodesFileWrittenByVersionOne() throws {
        // Exactly the shape 1.0 wrote: no schedule, no reminder.
        let json = """
        [{"colorName":"blue","completions":["2026-09-19","2026-09-20"],"createdAt":"2026-09-01T10:00:00Z",
          "emoji":"💧","id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Drink water"}]
        """
        let habits = try JSONDecoder.kept.decode([Habit].self, from: Data(json.utf8))
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits[0].name, "Drink water")
        XCTAssertEqual(habits[0].scheduledWeekdays, Habit.everyDay)
        XCTAssertNil(habits[0].reminderMinutes)
        XCTAssertTrue(habits[0].isEveryDay)
    }

    func testRoundTripKeepsScheduleAndReminder() throws {
        // ISO 8601 drops sub-second precision, so use a whole-second timestamp.
        let original = Habit(
            name: "Read",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            scheduledWeekdays: Habit.weekdays,
            reminderMinutes: 21 * 60 + 15
        )
        let data = try JSONEncoder.kept.encode([original])
        let decoded = try JSONDecoder.kept.decode([Habit].self, from: data)
        XCTAssertEqual(decoded, [original])
    }

    func testEmptyScheduleBehavesAsEveryDay() {
        let habit = Habit(name: "X", scheduledWeekdays: [])
        XCTAssertTrue(habit.isEveryDay)
        XCTAssertEqual(habit.schedule, Habit.everyDay)
    }
}
