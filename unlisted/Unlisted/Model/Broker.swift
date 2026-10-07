import Foundation

enum BrokerCategory: String, Codable, CaseIterable, Identifiable {
    case peopleSearch, professional, marketing, searchEngine, archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .peopleSearch: return "People-search sites"
        case .professional: return "Professional contact databases"
        case .marketing: return "Marketing and data brokers"
        case .searchEngine: return "Search engines"
        case .archive: return "Archives"
        }
    }

    var footnote: String {
        switch self {
        case .peopleSearch: return "These publish addresses, phone numbers, ages and relatives. Start here."
        case .professional: return "These sell work emails and phone numbers to recruiters and sales teams."
        case .marketing: return "These feed junk mail, pre-approved offers and ad targeting."
        case .searchEngine: return "These remove results from search, not from the original site."
        case .archive: return "Old copies of pages you or others have deleted."
        }
    }
}

struct Broker: Identifiable, Hashable {
    let id: String
    let name: String
    let category: BrokerCategory
    let optOutURL: URL?
    let email: String?
    let instructions: String
    /// Brokers often re-list people; how long before checking again.
    let recheckDays: Int
    /// Hostnames used to recognise a pasted URL as this broker.
    let domains: [String]

    func matches(host: String) -> Bool {
        let host = host.lowercased()
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

enum BrokerStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted, notListed, submitted, confirmed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .notListed: return "Not listed"
        case .submitted: return "Request sent"
        case .confirmed: return "Removed"
        }
    }

    var symbol: String {
        switch self {
        case .notStarted: return "circle"
        case .notListed: return "minus.circle"
        case .submitted: return "clock"
        case .confirmed: return "checkmark.circle.fill"
        }
    }

    var isDone: Bool { self != .notStarted }
}

struct BrokerProgress: Codable, Hashable {
    var status: BrokerStatus = .notStarted
    var updated: Date = Date()
    var note: String = ""

    func isRecheckDue(for broker: Broker, now: Date = Date()) -> Bool {
        guard status == .submitted || status == .confirmed || status == .notListed else { return false }
        let due = updated.addingTimeInterval(TimeInterval(broker.recheckDays) * 86_400)
        return now >= due
    }
}
