import Foundation
import Observation

/// Everything the app remembers. Saved as one JSON file on the device,
/// protected by iOS file encryption. Nothing is sent anywhere.
struct AppData: Codable, Equatable {
    var people: [Person] = []
    var brokerProgress: [String: BrokerProgress] = [:]
    /// Checklist key -> date completed.
    var checklist: [String: Date] = [:]
    var findings: [Finding] = []
    var remindersEnabled: Bool = false
    var weeklyScanReminder: Bool = false
}

@Observable
final class AppStore {
    private(set) var data: AppData
    private let fileURL: URL

    init(fileURL: URL = AppStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.data = AppStore.load(from: fileURL)
    }

    // MARK: Persistence

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Unlisted", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("data.json")
    }

    private static func load(from url: URL) -> AppData {
        guard let raw = try? Data(contentsOf: url) else { return AppData() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AppData.self, from: raw)) ?? AppData()
    }

    func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(data)) ?? Data()
    }

    private func save() {
        try? encoded().write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        save()
    }

    func deleteEverything() {
        data = AppData()
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: People

    var me: Person? { data.people.first { $0.relationship == .me } }
    /// Adults, with "me" first so pickers default to the user.
    var adults: [Person] {
        let all = data.people.filter { !$0.isMinor }
        return all.filter { $0.relationship == .me } + all.filter { $0.relationship != .me }
    }
    var children: [Person] { data.people.filter(\.isMinor) }

    func person(_ id: UUID?) -> Person? {
        guard let id else { return nil }
        return data.people.first { $0.id == id }
    }

    func upsert(_ person: Person) {
        update { data in
            if let index = data.people.firstIndex(where: { $0.id == person.id }) {
                data.people[index] = person
            } else {
                data.people.append(person)
            }
        }
    }

    func remove(_ person: Person) {
        update { data in
            data.people.removeAll { $0.id == person.id }
            data.findings.removeAll { $0.personID == person.id }
            let suffix = "|\(person.id.uuidString)"
            data.brokerProgress = data.brokerProgress.filter { !$0.key.hasSuffix(suffix) }
            data.checklist = data.checklist.filter { !$0.key.hasSuffix(suffix) }
        }
    }

    // MARK: Brokers

    static func key(_ itemID: String, _ personID: UUID) -> String { "\(itemID)|\(personID.uuidString)" }

    func progress(_ broker: Broker, for person: Person) -> BrokerProgress {
        data.brokerProgress[AppStore.key(broker.id, person.id)] ?? BrokerProgress()
    }

    func setStatus(_ status: BrokerStatus, note: String? = nil, broker: Broker, person: Person, now: Date = Date()) {
        update { data in
            let key = AppStore.key(broker.id, person.id)
            var progress = data.brokerProgress[key] ?? BrokerProgress()
            progress.status = status
            progress.updated = now
            if let note { progress.note = note }
            data.brokerProgress[key] = progress
        }
    }

    func brokersDone(for person: Person) -> Int {
        BrokerCatalog.all.filter { progress($0, for: person).status.isDone }.count
    }

    func recheckDue(for person: Person, now: Date = Date()) -> [Broker] {
        BrokerCatalog.all.filter { progress($0, for: person).isRecheckDue(for: $0, now: now) }
    }

    // MARK: Checklist

    static let householdKey = "household"

    func checklistKey(_ item: ChecklistItem, person: Person?) -> String {
        if item.audience == .household || person == nil { return "\(item.id)|\(AppStore.householdKey)" }
        return AppStore.key(item.id, person!.id)
    }

    func isDone(_ item: ChecklistItem, person: Person?) -> Bool {
        data.checklist[checklistKey(item, person: person)] != nil
    }

    func toggle(_ item: ChecklistItem, person: Person?, now: Date = Date()) {
        let key = checklistKey(item, person: person)
        update { data in
            if data.checklist[key] == nil { data.checklist[key] = now } else { data.checklist.removeValue(forKey: key) }
        }
    }

    /// Every checklist step that applies to the family right now.
    func applicableSteps() -> [(ChecklistItem, Person?)] {
        var steps: [(ChecklistItem, Person?)] = []
        for item in ChecklistCatalog.all {
            switch item.audience {
            case .household: steps.append((item, nil))
            case .adult: steps += adults.map { (item, Optional($0)) }
            case .child: steps += children.map { (item, Optional($0)) }
            }
        }
        return steps
    }

    var checklistProgress: (done: Int, total: Int) {
        let steps = applicableSteps()
        return (steps.filter { isDone($0.0, person: $0.1) }.count, steps.count)
    }

    // MARK: Findings

    func upsert(_ finding: Finding) {
        update { data in
            if let index = data.findings.firstIndex(where: { $0.id == finding.id }) {
                data.findings[index] = finding
            } else {
                data.findings.insert(finding, at: 0)
            }
        }
    }

    func remove(_ finding: Finding) {
        update { $0.findings.removeAll { $0.id == finding.id } }
    }

    var openFindings: [Finding] {
        data.findings.filter { $0.status == .open || $0.status == .requested }
    }
}
