import XCTest
@testable import Kept

@MainActor
final class HabitStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeptTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("habits.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testAddToggleAndReload() {
        let today = DayKey.today()
        let habit = Habit(name: "Water", emoji: "💧", colorName: "blue")

        let store = HabitStore(fileURL: fileURL)
        store.add(habit)
        store.toggle(habit, on: today)

        let reloaded = HabitStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.habits.count, 1)
        XCTAssertEqual(reloaded.habits[0].id, habit.id)
        XCTAssertEqual(reloaded.habits[0].name, "Water")
        XCTAssertTrue(reloaded.habits[0].isCompleted(on: today))
    }

    func testToggleTwiceClears() {
        let today = DayKey.today()
        let habit = Habit(name: "Read")
        let store = HabitStore(fileURL: nil)
        store.add(habit)
        store.toggle(habit, on: today)
        store.toggle(habit, on: today)
        XCTAssertFalse(store.habits[0].isCompleted(on: today))
    }

    func testUpdatePreservesCompletions() throws {
        let today = DayKey.today()
        let habit = Habit(name: "Old name")
        let store = HabitStore(fileURL: nil)
        store.add(habit)
        store.toggle(habit, on: today)

        var latest = try XCTUnwrap(store.habit(id: habit.id))
        latest.name = "New name"
        store.update(latest)

        XCTAssertEqual(store.habits[0].name, "New name")
        XCTAssertTrue(store.habits[0].isCompleted(on: today))
    }

    func testDeleteAndMove() {
        let store = HabitStore(fileURL: nil)
        let a = Habit(name: "A")
        let b = Habit(name: "B")
        let c = Habit(name: "C")
        store.add(a)
        store.add(b)
        store.add(c)

        store.move(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(store.habits.map(\.name), ["C", "A", "B"])

        store.delete(a)
        XCTAssertEqual(store.habits.map(\.name), ["C", "B"])

        store.delete(at: IndexSet(integer: 0))
        XCTAssertEqual(store.habits.map(\.name), ["B"])
    }

    func testCorruptFileLoadsEmpty() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: fileURL)
        let store = HabitStore(fileURL: fileURL)
        XCTAssertTrue(store.habits.isEmpty)
    }

    /// The widget writes through HabitFileStore while the app is backgrounded; coming back
    /// to the foreground must pick those changes up.
    func testReloadFromDiskSeesExternalWrites() {
        let today = DayKey.today()
        let habit = Habit(name: "Water")
        let store = HabitStore(fileURL: fileURL)
        store.add(habit)

        HabitFileStore.toggle(habitID: habit.id, on: today, at: fileURL)
        XCTAssertFalse(store.habits[0].isCompleted(on: today))

        store.reloadFromDisk()
        XCTAssertTrue(store.habits[0].isCompleted(on: today))
    }
}
