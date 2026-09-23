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
        let original = Habit(
            name: "Read",
            scheduledWeekdays: Habit.weekdays,
            reminderMinutes: 21 * 60 + 15
        )
        let data = try JSONEncoder.kept.encode([original])
        let decoded = try JSONDecoder.kept.decode([Habit].self, from: data)
        XCTAssertEqual(decoded, [original])
    }

    /// `Date()` carries finer precision than the file format stores, so `Habit` canonicalises
    /// `createdAt` on the way in. Without that a saved habit never compares equal to the one it
    /// came from, which is easy to miss because printed dates show only whole seconds.
    func testCreatedAtSurvivesRoundTripExactly() throws {
        let original = Habit(name: "Now")
        let decoded = try JSONDecoder.kept.decode([Habit].self, from: JSONEncoder.kept.encode([original]))
        XCTAssertEqual(decoded[0].createdAt, original.createdAt)
        XCTAssertEqual(decoded, [original])
    }

    /// A second round trip must not drift further.
    func testRoundTripIsIdempotent() throws {
        var habits = [Habit(name: "Now"), Habit(name: "Later", scheduledWeekdays: Habit.weekdays)]
        for _ in 0..<3 {
            habits = try JSONDecoder.kept.decode([Habit].self, from: JSONEncoder.kept.encode(habits))
        }
        let again = try JSONDecoder.kept.decode([Habit].self, from: JSONEncoder.kept.encode(habits))
        XCTAssertEqual(again, habits)
    }

    func testRejectsANonDateString() {
        let json = """
        [{"colorName":"teal","completions":[],"createdAt":"yesterday","emoji":"✅",
          "id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"X"}]
        """
        XCTAssertThrowsError(try JSONDecoder.kept.decode([Habit].self, from: Data(json.utf8)))
    }

    func testEmptyScheduleBehavesAsEveryDay() {
        let habit = Habit(name: "X", scheduledWeekdays: [])
        XCTAssertTrue(habit.isEveryDay)
        XCTAssertEqual(habit.schedule, Habit.everyDay)
    }
}
