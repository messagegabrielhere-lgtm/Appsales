import Foundation

/// Turns the websites a user typed or pasted into Wayback Machine exclusion
/// requests, one per site, with the exact answers the Internet Archive's form asks for.
/// The form takes one domain or account per submission and has a CAPTCHA,
/// so the app fills in the answers and the user submits each one.
enum ArchiveExclusion {
    static let formURL = URL(string: "https://archive.org/forms/wayback-machine-exclusion")!

    /// The form's three choices for "What type of URL are you wishing to have excluded?", verbatim.
    enum URLType: String, CaseIterable {
        case account = "Account on a platform"
        case ownDomain = "Website / Domain / Subdomain (not an account)"
        case notMyDomain = "Subdirectory / Subdomain — domain NOT controlled by me"
    }

    struct Request: Identifiable, Equatable {
        /// What goes in the form's URL box, e.g. https://example.com
        var url: String
        var host: String
        var type: URLType
        /// Other spellings of the same site found in the input (www, paths, old captures).
        var alsoCovers: [String]

        var id: String { host }

        /// Lists every capture of the site and its pages.
        var capturesURL: URL? { URL(string: "https://web.archive.org/web/*/\(host)/*") }

        var proofHint: String {
            switch type {
            case .ownDomain:
                return "Be ready to prove you control the domain: a DNS TXT record or a file on the site, from your registrar or host."
            case .account, .notMyDomain:
                return "Be ready to prove you control the account that posted it, for example by signing in or posting a code the Archive sends you."
            }
        }

        /// The answers for the form, ready to copy.
        func answers(email: String) -> String {
            """
            Contact Email: \(email)
            What type of URL are you wishing to have excluded? \(type.rawValue)
            URL to exclude: \(url)
            """
        }
    }

    /// Sites hosted under someone else's domain: the user controls the account, not the domain.
    static let platformDomains = [
        "wordpress.com", "blogspot.com", "tumblr.com", "wixsite.com", "squarespace.com",
        "weebly.com", "github.io", "substack.com", "medium.com", "neocities.org", "webflow.io",
    ]

    /// Builds one request per site, merging www, paths and old captures of the same site.
    static func requests(from inputs: [String]) -> [Request] {
        var order: [String] = []
        var byHost: [String: Request] = [:]
        for input in inputs {
            guard let url = clean(input), let rawHost = url.host?.lowercased() else { continue }
            let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
            let spelled = url.absoluteString
            if var existing = byHost[host] {
                if spelled != existing.url, !existing.alsoCovers.contains(spelled) { existing.alsoCovers.append(spelled) }
                byHost[host] = existing
            } else {
                let base = "https://\(host)"
                byHost[host] = Request(url: base, host: host, type: type(for: host),
                                       alsoCovers: spelled == base || spelled == base + "/" ? [] : [spelled])
                order.append(host)
            }
        }
        return order.compactMap { byHost[$0] }
    }

    static func type(for host: String) -> URLType {
        platformDomains.contains { host.hasSuffix("." + $0) } ? .notMyDomain : .ownDomain
    }

    /// Cleans a pasted link: unwraps Google, Outlook and Facebook redirect links
    /// (common when copying from email), strips Wayback capture prefixes, and adds https://.
    /// Returns nil for anything that isn't a web address.
    static func clean(_ raw: String) -> URL? {
        var text = raw.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]\"'.,;"))
        guard !text.isEmpty, !text.contains(" ") else { return nil }

        // Unwrap redirect links, possibly nested.
        for _ in 0..<3 {
            guard let url = URL(string: text.contains("://") ? text : "https://" + text),
                  let host = url.host?.lowercased(),
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { break }
            let key: String?
            if (host == "google.com" || host.hasSuffix(".google.com")) && url.path == "/url" { key = "q" }
            else if host.hasSuffix("safelinks.protection.outlook.com") { key = "url" }
            else if host == "l.facebook.com" || host == "lm.facebook.com" { key = "u" }
            else { key = nil }
            guard let key, let inner = items.first(where: { $0.name == key || (key == "q" && $0.name == "url") })?.value,
                  !inner.isEmpty else { break }
            text = inner
        }

        // web.archive.org/web/20241218191145/https://example.com/ -> https://example.com/
        if let range = text.range(of: #"^(https?://)?(web\.)?archive\.org/web/[0-9a-z_*]+/"#,
                                  options: [.regularExpression, .caseInsensitive]) {
            text = String(text[range.upperBound...])
        }

        if !text.contains("://") { text = "https://" + text }
        guard var parts = URLComponents(string: text),
              let host = parts.host?.lowercased(), host.contains("."),
              !host.hasSuffix("archive.org"),
              host.range(of: #"^[a-z0-9.-]+$"#, options: .regularExpression) != nil else { return nil }
        parts.scheme = "https"
        parts.host = host
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }
}
