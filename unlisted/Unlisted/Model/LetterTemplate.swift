import Foundation

enum CreditBureau: String, CaseIterable, Identifiable, Codable {
    case equifax, experian, transUnion

    var id: String { rawValue }

    var name: String {
        switch self {
        case .equifax: return "Equifax"
        case .experian: return "Experian"
        case .transUnion: return "TransUnion"
        }
    }

    /// Mail-in address for a security freeze on a minor's file.
    var minorFreezeAddress: String {
        switch self {
        case .equifax: return "Equifax Information Services LLC\nP.O. Box 105788\nAtlanta, GA 30348-5788"
        case .experian: return "Experian\nP.O. Box 9554\nAllen, TX 75013"
        case .transUnion: return "TransUnion\nP.O. Box 380\nWoodlyn, PA 19094"
        }
    }
}

enum LetterKind: String, CaseIterable, Identifiable, Hashable {
    case dataBrokerDeletion, websiteRemoval, doNotShare, childCreditFreeze, archiveRemoval, plateReaderDeletion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dataBrokerDeletion: return "Data broker deletion"
        case .websiteRemoval: return "Website or news removal request"
        case .doNotShare: return "Bank or insurer: do not share"
        case .childCreditFreeze: return "Child credit freeze"
        case .archiveRemoval: return "Wayback Machine removal"
        case .plateReaderDeletion: return "License plate camera data"
        }
    }

    var summary: String {
        switch self {
        case .dataBrokerDeletion: return "Delete my records, stop selling them, and don't re-list me."
        case .websiteRemoval: return "Ask a site to remove a page, or your name and photo from it."
        case .doNotShare: return "Use every opt-out a bank, card or insurance company must offer."
        case .childCreditFreeze: return "Freeze a child's credit by mail. One letter per bureau."
        case .archiveRemoval: return "Ask the Internet Archive to remove copies of a site you own."
        case .plateReaderDeletion: return "Ask a camera company or agency what it holds on your car."
        }
    }

    var symbol: String {
        switch self {
        case .dataBrokerDeletion: return "person.crop.circle.badge.xmark"
        case .websiteRemoval: return "doc.text.magnifyingglass"
        case .doNotShare: return "building.columns"
        case .childCreditFreeze: return "figure.child"
        case .archiveRemoval: return "archivebox"
        case .plateReaderDeletion: return "car"
        }
    }

    /// Fields the composer should show.
    var usesRecipient: Bool { self != .childCreditFreeze && self != .archiveRemoval }
    var usesURLs: Bool { self == .dataBrokerDeletion || self == .websiteRemoval || self == .archiveRemoval }
    var usesAccount: Bool { self == .doNotShare }
    var usesPlates: Bool { self == .plateReaderDeletion }
    var usesChildren: Bool { self == .childCreditFreeze }
    var isMailedOnly: Bool { self == .childCreditFreeze }

    var defaultRecipientEmail: String {
        self == .archiveRemoval ? "info@archive.org" : ""
    }
}

struct LetterContext {
    var sender: Person
    var children: [Person] = []
    var recipientName: String = ""
    var recipientAddress: String = ""
    var recipientEmail: String = ""
    var urls: [String] = []
    var accountHint: String = ""
    var plates: [String] = []
    var bureau: CreditBureau = .equifax
    var date: Date = Date()
}

struct Letter: Equatable {
    var to: String
    var subject: String
    var body: String
}

enum LetterRenderer {
    static func render(_ kind: LetterKind, _ c: LetterContext) -> Letter {
        switch kind {
        case .dataBrokerDeletion: return dataBroker(c)
        case .websiteRemoval: return websiteRemoval(c)
        case .doNotShare: return doNotShare(c)
        case .childCreditFreeze: return childFreeze(c)
        case .archiveRemoval: return archive(c)
        case .plateReaderDeletion: return plateReader(c)
        }
    }

    // MARK: Shared pieces

    static func fill(_ value: String, _ placeholder: String) -> String {
        value.trimmed.isEmpty ? "[\(placeholder)]" : value.trimmed
    }

    static func name(_ p: Person) -> String { fill(p.fullName, "Your full name") }

    static func replyEmail(_ p: Person) -> String { fill(p.emails.cleaned.first ?? "", "Your email") }

    static func dateLine(_ d: Date) -> String { d.formatted(date: .long, time: .omitted) }

    static func dob(_ p: Person) -> String {
        guard let d = p.birthDate else { return "[MM/DD/YYYY]" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM/dd/yyyy"
        return f.string(from: d)
    }

    static func bullets(_ items: [String], _ placeholder: String) -> String {
        let list = items.cleaned
        if list.isEmpty { return "- [\(placeholder)]" }
        return list.map { "- \($0)" }.joined(separator: "\n")
    }

    static func identifiers(_ p: Person) -> String {
        var lines = ["- Name: \(name(p))"]
        let aliases = p.otherNames.cleaned
        if !aliases.isEmpty { lines.append("- Also known as: \(aliases.joined(separator: ", "))") }
        if !p.location.isEmpty { lines.append("- Location: \(p.location)") }
        let emails = p.emails.cleaned
        if !emails.isEmpty { lines.append("- Email(s): \(emails.joined(separator: ", "))") }
        let phones = p.phones.cleaned
        if !phones.isEmpty { lines.append("- Phone(s): \(phones.joined(separator: ", "))") }
        return lines.joined(separator: "\n")
    }

    static func header(_ c: LetterContext) -> String {
        var parts = [dateLine(c.date), ""]
        if !c.recipientName.trimmed.isEmpty || !c.recipientAddress.trimmed.isEmpty {
            parts.append(fill(c.recipientName, "Company name"))
            if !c.recipientAddress.trimmed.isEmpty { parts.append(c.recipientAddress.trimmed) }
            parts.append("")
        }
        return parts.joined(separator: "\n")
    }

    static func signature(_ p: Person) -> String {
        "Sincerely,\n\n\(name(p))\n\(replyEmail(p))"
    }

    // MARK: Letters

    static func dataBroker(_ c: LetterContext) -> Letter {
        let company = fill(c.recipientName, "Company name")
        let body = """
        \(header(c))To \(company) Privacy Team:

        I am requesting that you delete all personal information you hold about me and stop selling or sharing it. This includes the listing(s) below and any other records under my name:

        \(bullets(c.urls, "Link to your listing"))

        Please:
        1. Delete every record about me, including addresses, phone numbers, emails, relatives, photos and age.
        2. Opt me out of any sale or sharing of my personal information.
        3. Suppress my information so it is not re-collected or re-published.
        4. Remove the listing page and let search engines know it is gone.

        Information to help you find my records (use it only for this request):
        \(identifiers(c.sender))

        Please confirm in writing to \(replyEmail(c.sender)) within 15 days. If you need to verify my identity, tell me what you require.

        \(signature(c.sender))
        """
        return Letter(to: c.recipientEmail.trimmed, subject: "Deletion and opt-out request - \(name(c.sender))", body: body)
    }

    static func websiteRemoval(_ c: LetterContext) -> Letter {
        let site = fill(c.recipientName, "Site or publisher name")
        let body = """
        \(header(c))To the team at \(site):

        I am \(name(c.sender)), and I am named on the following page(s):

        \(bullets(c.urls, "Link to the page"))

        I am a private individual, and I'm asking you to remove this content. If you can't remove the page, please:
        1. Remove my name, photo and any personal details from it.
        2. Add a "noindex" tag so search engines stop showing it, and ask Google to refresh it.
        3. Remove the same content from any copies, feeds or social posts you control.

        I'd appreciate a reply to \(replyEmail(c.sender)) within 10 business days letting me know what you're able to do.

        Thank you for your help.

        \(signature(c.sender))
        """
        return Letter(to: c.recipientEmail.trimmed, subject: "Removal request - \(name(c.sender))", body: body)
    }

    static func doNotShare(_ c: LetterContext) -> Letter {
        let account = fill(c.accountHint, "Last 4 digits of account or policy")
        let body = """
        \(header(c))Re: Privacy opt-out and do-not-share request
        Account or policy: \(account)

        To Whom It May Concern:

        I am using every privacy choice available to me under your privacy notice, the Gramm-Leach-Bliley Act, the Fair Credit Reporting Act, and any state privacy or insurance laws that apply. Please apply the following to all of my accounts with you and your affiliates:

        1. Do not share my personal information with companies outside your corporate family, except as the law requires.
        2. Do not share information about my creditworthiness with your affiliates.
        3. Do not let affiliates use my information to market to me.
        4. Do not sell or share my personal information for advertising, and remove me from marketing and prescreened-offer lists.
        5. Stop marketing calls, texts, emails and mail.

        Please apply this to every version of my name on file:
        \(identifiers(c.sender))

        Please confirm in writing to \(replyEmail(c.sender)) within 30 days.

        \(signature(c.sender))
        """
        return Letter(to: c.recipientEmail.trimmed, subject: "Privacy opt-out request - \(name(c.sender))", body: body)
    }

    static func childFreeze(_ c: LetterContext) -> Letter {
        let kids: String
        if c.children.isEmpty {
            kids = "Child:\n- Full name: [Child's full name]\n- Date of birth: [MM/DD/YYYY]\n- Social Security number: [write in by hand]\n- Address: [Address]"
        } else {
            kids = c.children.enumerated().map { index, child in
                """
                Child \(index + 1):
                - Full name: \(name(child))
                - Date of birth: \(dob(child))
                - Social Security number: [write in by hand]
                - Address: [Address]
                """
            }.joined(separator: "\n\n")
        }
        let plural = c.children.count == 1 ? "child" : "children"
        let body = """
        \(name(c.sender))
        [Your mailing address]
        \(replyEmail(c.sender))

        \(dateLine(c.date))

        \(c.bureau.minorFreezeAddress)

        Re: Security freeze request for my minor \(plural)

        To Whom It May Concern:

        I am the parent and legal guardian of the minor \(plural) listed below. Under 15 U.S.C. 1681c-1, I request that \(c.bureau.name) create a credit file for each child if one does not exist, and place a security freeze on it.

        \(kids)

        Parent or guardian:
        - Full name: \(name(c.sender))
        - Date of birth: \(dob(c.sender))
        - Social Security number: [write in by hand]
        - Address: [Address]

        Please mail written confirmation of each freeze, with the PIN or instructions to lift it, to the address above.

        Sincerely,


        ______________________
        \(name(c.sender))

        Enclosed (copies, not originals):
        [ ] My driver's license or state ID
        [ ] Proof of my address (utility bill or insurance statement)
        [ ] Each child's birth certificate showing me as parent
        [ ] Each child's Social Security card
        """
        return Letter(to: "", subject: "Minor security freeze request - \(c.bureau.name)", body: body)
    }

    static func archive(_ c: LetterContext) -> Letter {
        let body = """
        Hello Internet Archive team,

        I own the website(s) below and have taken them offline. I'm requesting that all archived copies be removed from the Wayback Machine and excluded from future crawling:

        \(bullets(c.urls, "yourdomain.com"))

        The archived pages contain personal information I no longer want public. I'm glad to verify ownership with a DNS TXT record or a file on the domain if you send me the value to use.

        Please confirm once the captures are removed. You can reach me at \(replyEmail(c.sender)).

        Thank you,
        Site owner
        \(replyEmail(c.sender))
        """
        return Letter(to: c.recipientEmail.trimmed.isEmpty ? "info@archive.org" : c.recipientEmail.trimmed,
                      subject: "Removal request - exclude my site from the Wayback Machine",
                      body: body)
    }

    static func plateReader(_ c: LetterContext) -> Letter {
        let company = fill(c.recipientName, "Company or agency name")
        let body = """
        \(header(c))To \(company) Privacy Team:

        I'm requesting deletion of personal information you hold about me and my vehicle(s), and an opt-out from any further retention, sharing or sale.

        Vehicle(s) and license plate(s):
        \(bullets(c.plates, "State and plate number"))

        Please:
        1. Delete images, plate reads, vehicle details and location records tied to the plate(s) above, including in any shared search network or backup.
        2. Stop retaining or sharing this data where you control it.
        3. If your customers (such as police departments or HOAs) control this data, tell me which ones hold data about my vehicle(s) and forward this request to them.
        4. Confirm in writing what was deleted, what wasn't and why, and how long anything remaining will be kept.

        My details:
        \(identifiers(c.sender))

        Please respond within 30 days to \(replyEmail(c.sender)).

        \(signature(c.sender))
        """
        return Letter(to: c.recipientEmail.trimmed, subject: "Personal data deletion request - \(name(c.sender))", body: body)
    }
}
