import XCTest
@testable import Kept

final class LogEntryTests: XCTestCase {
    func testRoundTripIsExact() throws {
        let original = LogEntry(
            kind: .drink,
            date: Date(),
            text: "Flat white",
            amount: "large",
            milliliters: 350,
            minutes: nil,
            rating: nil
        )
        let decoded = try JSONDecoder.kept.decode([LogEntry].self, from: JSONEncoder.kept.encode([original]))
        XCTAssertEqual(decoded, [original])
    }

    func testRatingIsClampedToOneThroughFive() {
        XCTAssertEqual(LogEntry(kind: .feeling, text: "", rating: 9).rating, 5)
        XCTAssertEqual(LogEntry(kind: .feeling, text: "", rating: 0).rating, 1)
        XCTAssertEqual(LogEntry(kind: .feeling, text: "", rating: 3).rating, 3)
        XCTAssertNil(LogEntry(kind: .feeling, text: "fine").rating)
    }

    func testDecodingToleratesMissingOptionalFields() throws {
        let json = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"food","date":"2026-09-19T07:45:00Z"}]
        """
        let entries = try JSONDecoder.kept.decode([LogEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].text, "")
        XCTAssertNil(entries[0].amount)
        XCTAssertNil(entries[0].milliliters)
    }

    func testIsWater() {
        XCTAssertTrue(LogEntry(kind: .drink, text: "Water").isWater)
        XCTAssertTrue(LogEntry(kind: .drink, text: "Sparkling water").isWater)
        XCTAssertFalse(LogEntry(kind: .drink, text: "Coffee").isWater)
        XCTAssertFalse(LogEntry(kind: .food, text: "Watermelon").isWater)
    }

    func testRatingFacesAndLabels() {
        XCTAssertEqual(LogEntry.face(for: 1), "😣")
        XCTAssertEqual(LogEntry.label(for: 5), "Great")
        XCTAssertEqual(LogEntry.label(for: 42), "Great")
    }

    func testSettingsDecodeWithNoKeysGivesDefaults() throws {
        let settings = try JSONDecoder.kept.decode(KeptSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(settings, KeptSettings())
        XCTAssertEqual(settings.glassMilliliters, 250)
        XCTAssertTrue(settings.includeAboutMe)
        XCTAssertFalse(settings.hasOnboarded)
    }

    func testSettingsClampGlassSize() throws {
        let tiny = try JSONDecoder.kept.decode(KeptSettings.self, from: Data(#"{"glassMilliliters":5}"#.utf8))
        XCTAssertEqual(tiny.glassMilliliters, 50)
        let huge = try JSONDecoder.kept.decode(KeptSettings.self, from: Data(#"{"glassMilliliters":99999}"#.utf8))
        XCTAssertEqual(huge.glassMilliliters, 2000)
    }

    func testHabitDoseRoundTripsAndIsNilInOldFiles() throws {
        let habit = Habit(name: "Vitamin D", dose: "2000 IU")
        let decoded = try JSONDecoder.kept.decode([Habit].self, from: JSONEncoder.kept.encode([habit]))
        XCTAssertEqual(decoded, [habit])
        XCTAssertEqual(decoded[0].dose, "2000 IU")

        let legacy = """
        [{"colorName":"blue","completions":[],"createdAt":"2026-09-01T10:00:00Z",
          "emoji":"💧","id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Drink water"}]
        """
        let old = try JSONDecoder.kept.decode([Habit].self, from: Data(legacy.utf8))
        XCTAssertNil(old[0].dose)
    }

    func testUntimedRoundTripsAndIsOnlyWrittenWhenTrue() throws {
        let untimed = LogEntry(kind: .supplement, date: Date(), text: "Fish oil", untimed: true)
        let timed = LogEntry(kind: .note, date: Date(), text: "Dentist")
        let data = try JSONEncoder.kept.encode([untimed, timed])
        XCTAssertEqual(try JSONDecoder.kept.decode([LogEntry].self, from: data), [untimed, timed])
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(json.components(separatedBy: "untimed").count - 1, 1)
    }

    func testNewKindsHaveTitlesAndQuickAddKeepsTheOriginalFour() {
        XCTAssertEqual(LogKind.supplement.title, "Supplement")
        XCTAssertEqual(LogKind.note.title, "Other")
        XCTAssertEqual(LogKind.quickAdd, [.food, .drink, .activity, .feeling])
    }
}
