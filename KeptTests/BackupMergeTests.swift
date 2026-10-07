import XCTest
@testable import Kept

final class BackupMergeTests: XCTestCase {
    func testMergeAddsOnlyWhatIsNewAndCombinesTicks() {
        let shared = LogEntry(kind: .food, date: TestCalendar.date(2026, 10, 1, 8), text: "Toast")
        let sameTimeAndText = LogEntry(kind: .food, date: TestCalendar.date(2026, 10, 1, 8), text: "toast")
        let new = LogEntry(kind: .drink, date: TestCalendar.date(2026, 10, 2, 9), text: "Coffee")

        let mine = Habit(name: "Creatine", createdAt: TestCalendar.date(2026, 1, 1), completions: [TestCalendar.day(2026, 10, 1)])
        let theirsSameName = Habit(name: "creatine ", createdAt: TestCalendar.date(2026, 1, 1),
                                   completions: [TestCalendar.day(2026, 10, 1), TestCalendar.day(2026, 10, 2)])
        let theirsNew = Habit(name: "Fish oil", createdAt: TestCalendar.date(2026, 1, 1))

        let result = BackupMerge.merge(
            habits: [mine], log: [shared],
            backupHabits: [theirsSameName, theirsNew], backupLog: [shared, sameTimeAndText, new]
        )
        XCTAssertEqual(result.addedEntries, 1)
        XCTAssertEqual(result.log.map(\.text), ["Toast", "Coffee"])
        XCTAssertEqual(result.addedHabits, 1)
        XCTAssertEqual(result.addedTicks, 1)
        XCTAssertEqual(result.habits.count, 2)
        XCTAssertEqual(result.habits[0].completions.count, 2)
        XCTAssertTrue(result.changed)

        let again = BackupMerge.merge(habits: result.habits, log: result.log,
                                      backupHabits: [theirsSameName, theirsNew], backupLog: [shared, new])
        XCTAssertFalse(again.changed)
    }
}
