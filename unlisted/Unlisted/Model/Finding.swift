import Foundation

enum FindingKind: String, Codable, CaseIterable, Identifiable {
    case dataBroker, ownAccount, thirdParty, deadLink, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dataBroker: return "Data broker / people-search"
        case .ownAccount: return "My own account or profile"
        case .thirdParty: return "Someone else's site (news, blog, business)"
        case .deadLink: return "Dead link still in search results"
        case .other: return "Other"
        }
    }

    var nextStep: String {
        switch self {
        case .dataBroker:
            return "Use the site's opt-out page. If it's in the Remove tab, open it there so the app can track it and remind you to re-check."
        case .ownAccount:
            return "Log in, then delete the account or set the profile to private. Remove your full name, photo, city and phone first if you want to keep the account."
        case .thirdParty:
            return "Send a polite removal request. Ask them to delete the page, or remove your name and photo, and to add a noindex tag so search engines drop it."
        case .deadLink:
            return "Ask Google to refresh it with the Outdated Content tool, and Bing with its Content Removal tool."
        case .other:
            return "Decide whether it matters. If it shows your phone, address or email, Google's 'Results about you' can remove it from search."
        }
    }
}

enum FindingStatus: String, Codable, CaseIterable, Identifiable {
    case open, requested, removed, ignored

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "To do"
        case .requested: return "Requested"
        case .removed: return "Gone"
        case .ignored: return "Leave it"
        }
    }
}

/// A page the user found about a family member and logged by hand.
struct Finding: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var personID: UUID?
    var url: String = ""
    var title: String = ""
    var kind: FindingKind = .other
    var status: FindingStatus = .open
    var note: String = ""
    var created: Date = Date()

    var host: String? { URL(string: Finding.normalized(url))?.host?.lowercased() }

    static func normalized(_ raw: String) -> String {
        let value = raw.trimmed
        if value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://") { return value }
        return "https://" + value
    }

    /// Best guess at what kind of page this is, from its address alone.
    static func classify(_ raw: String, brokers: [Broker] = BrokerCatalog.all) -> (FindingKind, Broker?) {
        guard let host = URL(string: normalized(raw))?.host?.lowercased() else { return (.other, nil) }
        if let broker = brokers.first(where: { $0.matches(host: host) }) {
            return (.dataBroker, broker)
        }
        let ownAccountHosts = ["linkedin.com", "facebook.com", "instagram.com", "x.com", "twitter.com",
                               "tiktok.com", "pinterest.com", "github.com", "reddit.com", "youtube.com",
                               "gravatar.com", "medium.com", "about.me", "venmo.com"]
        if ownAccountHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            return (.ownAccount, nil)
        }
        return (.thirdParty, nil)
    }
}
