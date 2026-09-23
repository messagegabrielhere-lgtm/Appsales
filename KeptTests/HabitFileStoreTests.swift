import XCTest
@testable import Kept

/// The widget extension and App Intents use `HabitFileStore` from background threads, so it
/// must work with no main actor and must never throw its way out of a widget refresh.
final class HabitFileStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeptFileTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("habits.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testMissingFileLoadsEmpty() {
        XCTAssertTrue(HabitFileStore.load(from: fileURL).isEmpty)
    }

    func testCorruptFileLoadsEmptyWithoutThrowing() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json at all".utf8).write(to: fileURL)
        XCTAssertTrue(HabitFileStore.load(from: fileURL).isEmpty)
    }

    func testSaveThenLoadRoundTrip() {
        let habits = [Habit(name: "Water", emoji: "💧"), Habit(name: "Read", scheduledWeekdays: Habit.weekdays)]
        XCTAssertTrue(HabitFileStore.save(habits, to: fileURL))
        XCTAssertEqual(HabitFileStore.load(from: fileURL), habits)
    }

    func testToggleFlipsAndPersists() throws {
        let today = DayKey.today()
        let habit = Habit(name: "Water")
        HabitFileStore.save([habit], to: fileURL)

        let after = try XCTUnwrap(HabitFileStore.toggle(habitID: habit.id, on: today, at: fileURL))
        XCTAssertTrue(after.isCompleted(on: today))
        XCTAssertTrue(HabitFileStore.load(from: fileURL)[0].isCompleted(on: today))

        HabitFileStore.toggle(habitID: habit.id, on: today, at: fileURL)
        XCTAssertFalse(HabitFileStore.load(from: fileURL)[0].isCompleted(on: today))
    }

    func testToggleUnknownHabitIsANoOp() {
        let habit = Habit(name: "Water")
        HabitFileStore.save([habit], to: fileURL)
        XCTAssertNil(HabitFileStore.toggle(habitID: UUID(), on: DayKey.today(), at: fileURL))
        XCTAssertEqual(HabitFileStore.load(from: fileURL), [habit])
    }

    /// A widget check-off runs off the main actor. This would trap if the type required one.
    func testLoadAndToggleOffTheMainActor() async {
        let habit = Habit(name: "Water")
        HabitFileStore.save([habit], to: fileURL)
        let url = fileURL!

        let done = await Task.detached { () -> Bool in
            XCTAssertFalse(Thread.isMainThread)
            HabitFileStore.toggle(habitID: habit.id, on: DayKey.today(), at: url)
            return HabitFileStore.load(from: url).first?.isCompleted(on: DayKey.today()) ?? false
        }.value

        XCTAssertTrue(done)
    }

    func testLegacyFileIsMigratedOnce() throws {
        let legacy = fileURL.deletingLastPathComponent().appendingPathComponent("legacy.json")
        let shared = fileURL!
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        let habits = [Habit(name: "From 1.0")]
        HabitFileStore.save(habits, to: legacy)

        // Stand in for the real legacy path by copying explicitly, then confirm a second
        // migration does not clobber newer data.
        try FileManager.default.copyItem(at: legacy, to: shared)
        XCTAssertEqual(HabitFileStore.load(from: shared), habits)

        HabitFileStore.save([Habit(name: "Newer")], to: shared)
        HabitFileStore.migrateLegacyFileIfNeeded(to: shared)
        XCTAssertEqual(HabitFileStore.load(from: shared).map(\.name), ["Newer"])
    }
}
