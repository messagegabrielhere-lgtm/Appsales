import XCTest
@testable import Kept

final class LogFileStoreTests: XCTestCase {
    private var directory: URL!
    private var logURL: URL { directory.appendingPathComponent(LogFileStore.fileName) }
    private var settingsURL: URL { directory.appendingPathComponent(SettingsFileStore.fileName) }

    override func setUp() {
        super.setUp()
        directory = TestCalendar.temporaryDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testMissingFileLoadsEmpty() {
        XCTAssertTrue(LogFileStore.load(from: logURL).isEmpty)
    }

    func testSaveAndLoadAreSortedOldestFirst() {
        let late = LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 19), text: "Dinner")
        let early = LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 7), text: "Breakfast")
        LogFileStore.save([late, early], to: logURL)
        XCTAssertEqual(LogFileStore.load(from: logURL).map(\.text), ["Breakfast", "Dinner"])
    }

    func testAppendKeepsOrderAndPersists() {
        LogFileStore.append(LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 12), text: "Lunch"), to: logURL)
        let all = LogFileStore.append(LogEntry(kind: .food, date: TestCalendar.date(2026, 9, 19, 8), text: "Breakfast"), to: logURL)
        XCTAssertEqual(all.map(\.text), ["Breakfast", "Lunch"])
        XCTAssertEqual(LogFileStore.load(from: logURL).map(\.text), ["Breakfast", "Lunch"])
    }

    /// One entry this version cannot read must not cost the user every other entry.
    func testOneUnreadableEntryDoesNotLoseTheRest() throws {
        let json = """
        [
          {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"food","date":"2026-09-19T07:45:00Z","text":"Eggs"},
          {"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"teleport","date":"2026-09-19T08:00:00Z","text":"??"},
          {"id":"8F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"drink","date":"2026-09-19T08:05:00Z","text":"Tea"}
        ]
        """
        try Data(json.utf8).write(to: logURL)
        XCTAssertEqual(LogFileStore.load(from: logURL).map(\.text), ["Eggs", "Tea"])
    }

    /// A file that is not readable at all is moved aside rather than left to be overwritten
    /// by the next save.
    func testUnreadableFileIsSetAsideNotOverwritten() throws {
        try Data("definitely not json".utf8).write(to: logURL)
        XCTAssertTrue(LogFileStore.load(from: logURL).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: logURL.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("log.unreadable-") && $0.hasSuffix(".json") }, "\(names)")
    }

    func testSettingsDefaultWhenMissingAndRoundTrip() {
        XCTAssertEqual(SettingsFileStore.load(from: settingsURL), KeptSettings())
        var settings = KeptSettings()
        settings.aboutMe = "Runner"
        settings.glassMilliliters = 330
        settings.hasOnboarded = true
        XCTAssertTrue(SettingsFileStore.save(settings, to: settingsURL))
        XCTAssertEqual(SettingsFileStore.load(from: settingsURL), settings)
    }
}
