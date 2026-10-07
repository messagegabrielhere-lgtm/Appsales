import XCTest
@testable import Kept

final class ReviewPromptTests: XCTestCase {
    private let now = TestCalendar.date(2026, 10, 8, 12)

    func testNeedsFiveDaysOfUse() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(daysLogged: 4, lastAskedAt: nil, lastAskedVersion: nil, currentVersion: "2.2.0", now: now))
        XCTAssertTrue(ReviewPrompt.shouldAsk(daysLogged: 5, lastAskedAt: nil, lastAskedVersion: nil, currentVersion: "2.2.0", now: now))
    }

    func testOncePerVersionAndNinetyDays() {
        let recently = now.addingTimeInterval(-30 * 86_400)
        let longAgo = now.addingTimeInterval(-120 * 86_400)
        XCTAssertFalse(ReviewPrompt.shouldAsk(daysLogged: 20, lastAskedAt: longAgo, lastAskedVersion: "2.2.0", currentVersion: "2.2.0", now: now))
        XCTAssertFalse(ReviewPrompt.shouldAsk(daysLogged: 20, lastAskedAt: recently, lastAskedVersion: "2.1.0", currentVersion: "2.2.0", now: now))
        XCTAssertTrue(ReviewPrompt.shouldAsk(daysLogged: 20, lastAskedAt: longAgo, lastAskedVersion: "2.1.0", currentVersion: "2.2.0", now: now))
    }
}
