import Foundation

extension AppStore {
    /// A fictional family for App Store screenshots. Saved to a temporary file
    /// so it never mixes with real data.
    static func demo() -> AppStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("unlisted-demo.json")
        try? FileManager.default.removeItem(at: url)
        let store = AppStore(fileURL: url)
        let calendar = Calendar.current
        func yearsAgo(_ years: Int) -> Date? { calendar.date(byAdding: .year, value: -years, to: Date()) }

        var me = Person(relationship: .me)
        me.firstName = "Jordan"
        me.lastName = "Avery"
        me.city = "Springfield"
        me.state = "IL"
        me.emails = ["jordan.avery@example.com"]
        me.phones = ["555-010-0142"]
        me.usernames = ["javery"]
        me.birthDate = yearsAgo(38)

        var partner = Person(relationship: .spouse)
        partner.firstName = "Casey"
        partner.lastName = "Avery"
        partner.birthDate = yearsAgo(36)

        var son = Person(relationship: .child)
        son.firstName = "Riley"
        son.lastName = "Avery"
        son.birthDate = yearsAgo(7)

        var daughter = Person(relationship: .child)
        daughter.firstName = "Morgan"
        daughter.lastName = "Avery"
        daughter.birthDate = yearsAgo(4)

        for person in [me, partner, son, daughter] { store.upsert(person) }

        let statuses: [(String, BrokerStatus)] = [
            ("spokeo", .confirmed), ("whitepages", .confirmed), ("peopleconnect", .submitted),
            ("beenverified", .submitted), ("truepeoplesearch", .confirmed), ("fastpeoplesearch", .notListed),
            ("socialcatfish", .submitted), ("optoutprescreen", .confirmed),
        ]
        for (id, status) in statuses {
            if let broker = BrokerCatalog.broker(id: id) { store.setStatus(status, broker: broker, person: me) }
        }

        for id in ["freeze-equifax", "freeze-experian", "freeze-transunion", "irs-ippin", "password-manager", "port-pin"] {
            if let item = ChecklistCatalog.all.first(where: { $0.id == id }) { store.toggle(item, person: me) }
        }
        if let safeWord = ChecklistCatalog.all.first(where: { $0.id == "safe-word" }) { store.toggle(safeWord, person: nil) }

        store.upsert(Finding(personID: me.id, url: "https://www.spokeo.com/Jordan-Avery", title: "Spokeo listing",
                             kind: .dataBroker, status: .removed))
        store.upsert(Finding(personID: me.id, url: "https://news.example.com/2016/local-feature", title: "Old local news story",
                             kind: .thirdParty, status: .requested))
        store.upsert(Finding(personID: me.id, url: "https://www.example-directory.com/jordan-avery", title: "Directory listing",
                             kind: .thirdParty, status: .open))
        return store
    }
}
