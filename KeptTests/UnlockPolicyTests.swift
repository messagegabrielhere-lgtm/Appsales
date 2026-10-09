import XCTest
@testable import Kept

final class UnlockPolicyTests: XCTestCase {
    func testEveryoneWhoBoughtThePaidAppIsUnlocked() {
        XCTAssertTrue(UnlockPolicy.paidForApp(originalAppVersion: "1"))
        XCTAssertTrue(UnlockPolicy.paidForApp(originalAppVersion: "1.0"))
        XCTAssertTrue(UnlockPolicy.paidForApp(originalAppVersion: "202609221830"))
        XCTAssertTrue(UnlockPolicy.paidForApp(originalAppVersion: "202610071827"), "the 2.1 build")
        XCTAssertFalse(UnlockPolicy.paidForApp(originalAppVersion: "202610101200"), "a 2.3 build")
        XCTAssertFalse(UnlockPolicy.paidForApp(originalAppVersion: ""))
    }

    func testFreeQuestionsAndPeriods() {
        XCTAssertTrue(UnlockPolicy.canAsk(unlocked: false, used: 4))
        XCTAssertFalse(UnlockPolicy.canAsk(unlocked: false, used: 5))
        XCTAssertTrue(UnlockPolicy.canAsk(unlocked: true, used: 500))
        XCTAssertEqual(UnlockPolicy.questionsLeft(used: 7), 0)
        XCTAssertEqual(AIExportRange.allCases.filter(UnlockPolicy.isFree), [.today, .yesterday, .week])
    }
}
