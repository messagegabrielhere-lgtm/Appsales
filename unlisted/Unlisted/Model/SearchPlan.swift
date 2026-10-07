import Foundation

enum SearchEngine: String, CaseIterable, Identifiable, Codable {
    case google, bing, duckDuckGo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .duckDuckGo: return "DuckDuckGo"
        }
    }

    private var base: String {
        switch self {
        case .google: return "https://www.google.com/search"
        case .bing: return "https://www.bing.com/search"
        case .duckDuckGo: return "https://duckduckgo.com/"
        }
    }

    func url(for query: String) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

struct SearchQuery: Identifiable, Hashable {
    var id: String { query }
    let label: String
    let query: String
}

/// Builds the list of searches a person should run on themselves.
/// The app never scrapes search engines; it opens each query in Safari.
enum SearchPlan {
    static func queries(for person: Person) -> [SearchQuery] {
        var out: [SearchQuery] = []
        var seen = Set<String>()

        func add(_ label: String, _ query: String) {
            if seen.insert(query.lowercased()).inserted {
                out.append(SearchQuery(label: label, query: query))
            }
        }

        let places = ([person.city] + person.pastLocations).cleaned

        for name in person.allNames {
            add("Name", quoted(name))
            for place in places {
                add("Name + place", "\(quoted(name)) \(quoted(place))")
            }
            add("Name on people-search sites", "\(quoted(name)) address OR phone OR relatives")
        }
        for email in person.emails.cleaned {
            add("Email", quoted(email))
        }
        for phone in person.phones.cleaned {
            for format in phoneFormats(phone) {
                add("Phone", quoted(format))
            }
        }
        for username in person.usernames.cleaned {
            add("Username", quoted(username))
        }
        return out
    }

    static func quoted(_ text: String) -> String { "\"\(text.trimmed)\"" }

    /// US numbers get the two common written forms; anything else is searched as typed.
    static func phoneFormats(_ raw: String) -> [String] {
        var digits = raw.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("1") { digits.removeFirst() }
        guard digits.count == 10 else { return [raw.trimmed] }
        let chars = Array(digits)
        let area = String(chars[0..<3]), prefix = String(chars[3..<6]), line = String(chars[6..<10])
        return ["\(area)-\(prefix)-\(line)", "(\(area)) \(prefix)-\(line)"]
    }
}
