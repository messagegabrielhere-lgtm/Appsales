import Foundation

/// AI assistants the prompt can be sent to in one tap. The app still never contacts any of
/// them: it copies the prompt and opens the assistant's site or app, which the user is
/// already signed in to. Where the site accepts a prompt in its address, it arrives typed.
enum AIAssistant: String, CaseIterable, Identifiable {
    case chatgpt
    case claude
    case gemini
    case perplexity
    case copilot
    case grok

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chatgpt: return "ChatGPT"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .perplexity: return "Perplexity"
        case .copilot: return "Copilot"
        case .grok: return "Grok"
        }
    }

    /// Plain system symbols. Other companies' logos are theirs, so the app doesn't use them.
    var symbol: String {
        switch self {
        case .chatgpt: return "bubble.left.and.text.bubble.right"
        case .claude: return "sparkle"
        case .gemini: return "diamond"
        case .perplexity: return "magnifyingglass"
        case .copilot: return "person.2"
        case .grok: return "bolt"
        }
    }

    private var base: String {
        switch self {
        case .chatgpt: return "https://chatgpt.com/"
        case .claude: return "https://claude.ai/new"
        case .gemini: return "https://gemini.google.com/app"
        case .perplexity: return "https://www.perplexity.ai/search"
        case .copilot: return "https://copilot.microsoft.com/"
        case .grok: return "https://grok.com/"
        }
    }

    /// Gemini doesn't take a prompt in its address, so its prompt is pasted.
    var acceptsPrompt: Bool { self != .gemini }

    /// Long addresses are cut off by some sites, so a month of entries is pasted instead.
    static let maxAddressLength = 7000

    struct Destination: Equatable {
        var url: URL
        /// The prompt is in the address. Otherwise the user pastes it from the clipboard.
        var prefilled: Bool
    }

    func destination(for prompt: String) -> Destination {
        let plain = URL(string: base)!
        guard acceptsPrompt else { return Destination(url: plain, prefilled: false) }
        // RFC 3986 unreserved characters only, so every other character is encoded.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        guard let encoded = prompt.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return Destination(url: plain, prefilled: false)
        }
        let address = base + "?q=" + encoded
        guard address.count <= Self.maxAddressLength, let url = URL(string: address) else {
            return Destination(url: plain, prefilled: false)
        }
        return Destination(url: url, prefilled: true)
    }
}
