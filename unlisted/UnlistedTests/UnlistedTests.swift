import XCTest
@testable import Unlisted

final class SearchPlanTests: XCTestCase {
    func testQueriesCoverNamesPlacesEmailsPhonesAndUsernames() {
        var p = Person(relationship: .me)
        p.firstName = "Alex"
        p.lastName = "Example"
        p.city = "Springfield"
        p.emails = ["alex@example.com"]
        p.phones = ["+1 (555) 010-0199"]
        p.usernames = ["alexex"]

        let queries = SearchPlan.queries(for: p).map(\.query)

        XCTAssertTrue(queries.contains("\"Alex Example\""))
        XCTAssertTrue(queries.contains("\"Alex Example\" \"Springfield\""))
        XCTAssertTrue(queries.contains("\"alex@example.com\""))
        XCTAssertTrue(queries.contains("\"555-010-0199\""))
        XCTAssertTrue(queries.contains("\"(555) 010-0199\""))
        XCTAssertTrue(queries.contains("\"alexex\""))
        XCTAssertEqual(Set(queries).count, queries.count, "queries should be unique")
    }

    func testPhoneFormatsLeaveNonUSNumbersAlone() {
        XCTAssertEqual(SearchPlan.phoneFormats("+44 20 7946 0958"), ["+44 20 7946 0958"])
    }

    func testSearchURLsAreEncoded() {
        let url = SearchEngine.google.url(for: "\"Alex Example\" \"Springfield\"")
        XCTAssertEqual(url?.host, "www.google.com")
        XCTAssertTrue(url?.absoluteString.contains("%22Alex%20Example%22") ?? false)
    }
}

final class FindingTests: XCTestCase {
    func testClassifiesKnownBrokers() {
        let (kind, broker) = Finding.classify("www.spokeo.com/Alex-Example")
        XCTAssertEqual(kind, .dataBroker)
        XCTAssertEqual(broker?.id, "spokeo")
    }

    func testClassifiesPeopleConnectBrands() {
        XCTAssertEqual(Finding.classify("https://www.truthfinder.com/x").1?.id, "peopleconnect")
    }

    func testClassifiesSocialAsOwnAccount() {
        XCTAssertEqual(Finding.classify("https://www.linkedin.com/in/alex").0, .ownAccount)
    }

    func testUnknownSitesAreThirdParty() {
        XCTAssertEqual(Finding.classify("https://news.example.org/story").0, .thirdParty)
    }

    func testDoesNotMatchLookalikeDomains() {
        XCTAssertNil(Finding.classify("https://notspokeo.com/x").1)
    }
}

final class LetterTests: XCTestCase {
    private func sender() -> Person {
        var p = Person(relationship: .me)
        p.firstName = "Alex"
        p.lastName = "Example"
        p.emails = ["alex@example.com"]
        return p
    }

    func testEveryLetterRendersWithoutUnfilledSenderFields() {
        for kind in LetterKind.allCases {
            let letter = LetterRenderer.render(kind, LetterContext(sender: sender()))
            XCTAssertFalse(letter.body.isEmpty, "\(kind) is empty")
            XCTAssertFalse(letter.body.contains("[Your email]"), "\(kind) missed the email")
            XCTAssertFalse(letter.subject.isEmpty, "\(kind) has no subject")
        }
    }

    func testMissingDetailsBecomePlaceholders() {
        let letter = LetterRenderer.render(.dataBrokerDeletion, LetterContext(sender: Person()))
        XCTAssertTrue(letter.body.contains("[Your full name]"))
        XCTAssertTrue(letter.body.contains("[Link to your listing]"))
    }

    func testChildFreezeNeverPrintsAnSSNAndUsesBureauAddress() {
        var child = Person(relationship: .child)
        child.firstName = "Sam"
        child.lastName = "Example"
        let letter = LetterRenderer.render(.childCreditFreeze,
                                           LetterContext(sender: sender(), children: [child], bureau: .experian))
        XCTAssertTrue(letter.body.contains("Allen, TX 75013"))
        XCTAssertTrue(letter.body.contains("Sam Example"))
        XCTAssertTrue(letter.body.contains("[write in by hand]"))
        XCTAssertEqual(letter.to, "", "freeze letters are mailed, never emailed")
    }

    func testArchiveLetterDefaultsToArchiveAddress() {
        let letter = LetterRenderer.render(.archiveRemoval, LetterContext(sender: sender(), urls: ["example.com"]))
        XCTAssertEqual(letter.to, "info@archive.org")
        XCTAssertTrue(letter.body.contains("- example.com"))
    }
}

final class StoreTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    func testPersistsAndReloads() {
        let store = AppStore(fileURL: url)
        var p = Person(relationship: .me)
        p.firstName = "Alex"
        store.upsert(p)
        let broker = BrokerCatalog.all[0]
        store.setStatus(.submitted, broker: broker, person: p)

        let reloaded = AppStore(fileURL: url)
        XCTAssertEqual(reloaded.me?.firstName, "Alex")
        XCTAssertEqual(reloaded.progress(broker, for: p).status, .submitted)
    }

    func testRecheckBecomesDue() {
        let store = AppStore(fileURL: url)
        let p = Person(relationship: .me)
        store.upsert(p)
        let broker = BrokerCatalog.all[0]
        let long = Date().addingTimeInterval(-Double(broker.recheckDays + 1) * 86_400)
        store.setStatus(.confirmed, broker: broker, person: p, now: long)
        XCTAssertTrue(store.recheckDue(for: p).contains(broker))
    }

    func testChecklistCountsAdultsChildrenAndHousehold() {
        let store = AppStore(fileURL: url)
        store.upsert(Person(relationship: .me))
        store.upsert(Person(relationship: .spouse))
        store.upsert(Person(relationship: .child))

        let adultItems = ChecklistCatalog.all.filter { $0.audience == .adult }.count
        let childItems = ChecklistCatalog.all.filter { $0.audience == .child }.count
        let householdItems = ChecklistCatalog.all.filter { $0.audience == .household }.count
        XCTAssertEqual(store.checklistProgress.total, adultItems * 2 + childItems + householdItems)

        let item = ChecklistCatalog.all.first { $0.audience == .adult }!
        store.toggle(item, person: store.me)
        XCTAssertEqual(store.checklistProgress.done, 1)
        XCTAssertTrue(store.isDone(item, person: store.me))
        XCTAssertFalse(store.isDone(item, person: store.adults.first { $0.relationship == .spouse }))
    }

    func testRemovingPersonClearsTheirProgress() {
        let store = AppStore(fileURL: url)
        let p = Person(relationship: .spouse)
        store.upsert(p)
        store.setStatus(.submitted, broker: BrokerCatalog.all[0], person: p)
        store.upsert(Finding(personID: p.id, url: "https://example.com"))
        store.remove(p)
        XCTAssertTrue(store.data.brokerProgress.isEmpty)
        XCTAssertTrue(store.data.findings.isEmpty)
    }

    func testDeleteEverything() {
        let store = AppStore(fileURL: url)
        store.upsert(Person(relationship: .me))
        store.deleteEverything()
        XCTAssertNil(store.me)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

final class CatalogTests: XCTestCase {
    func testBrokerIDsAreUniqueAndLinksAreHTTPS() {
        let ids = BrokerCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for broker in BrokerCatalog.all {
            XCTAssertTrue(broker.optOutURL != nil || broker.email != nil, "\(broker.id) has no way to opt out")
            if let url = broker.optOutURL { XCTAssertEqual(url.scheme, "https", broker.id) }
        }
    }

    func testChecklistIDsAreUnique() {
        let ids = ChecklistCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}

final class LaunchTests: XCTestCase {
    func testLaunchArguments() {
        let options = LaunchOptions(arguments: ["Unlisted", "-demo", "-tab", "3"])
        XCTAssertTrue(options.demo)
        XCTAssertEqual(options.tab, 3)
        XCTAssertFalse(LaunchOptions(arguments: ["Unlisted"]).demo)
    }

    func testDemoFamilyIsFictionalAndComplete() {
        let store = AppStore.demo()
        XCTAssertEqual(store.data.people.count, 4)
        XCTAssertEqual(store.children.count, 2)
        XCTAssertNotNil(store.me)
        XCTAssertGreaterThan(store.checklistProgress.done, 0)
        XCTAssertFalse(store.data.findings.isEmpty)
        for person in store.data.people {
            XCTAssertEqual(person.lastName, "Avery")
        }
    }
}
