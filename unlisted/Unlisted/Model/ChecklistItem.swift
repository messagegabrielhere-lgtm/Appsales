import Foundation

enum ChecklistSection: String, CaseIterable, Identifiable {
    case credit, accounts, phone, kids, home, scams, legal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .credit: return "Lock your credit and identity"
        case .accounts: return "Secure your accounts"
        case .phone: return "Protect your phone number"
        case .kids: return "Kids"
        case .home: return "Home and address"
        case .scams: return "Family scam defense"
        case .legal: return "Family safety net"
        }
    }

    var symbol: String {
        switch self {
        case .credit: return "lock.fill"
        case .accounts: return "key.fill"
        case .phone: return "phone.fill"
        case .kids: return "figure.and.child.holdinghands"
        case .home: return "house.fill"
        case .scams: return "exclamationmark.shield.fill"
        case .legal: return "doc.text.fill"
        }
    }
}

/// Who a checklist item is done for.
enum Audience {
    /// Done once per adult (credit freezes, passwords).
    case adult
    /// Done once per child (child credit freeze letters).
    case child
    /// Done once for the whole household (safe word, router).
    case household
}

struct ChecklistItem: Identifiable, Hashable {
    let id: String
    let section: ChecklistSection
    let audience: Audience
    let title: String
    let detail: String
    let url: URL?
    /// Optional letter the app can write for this step.
    var letter: LetterKind? = nil
}
