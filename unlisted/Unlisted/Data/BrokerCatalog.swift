import Foundation

/// Opt-out pages checked in October 2026. Brokers move these pages often;
/// if one breaks, the footer of the broker's site usually has an
/// "Opt out" or "Do Not Sell" link.
enum BrokerCatalog {
    static let all: [Broker] = peopleSearch + professional + marketing + searchEngines + archives

    static func broker(id: String) -> Broker? { all.first { $0.id == id } }

    private static func url(_ s: String) -> URL? { URL(string: s) }

    static let peopleSearch: [Broker] = [
        Broker(id: "spokeo", name: "Spokeo", category: .peopleSearch,
               optOutURL: url("https://www.spokeo.com/optout"), email: nil,
               instructions: "Search your name on spokeo.com, copy your listing's link, paste it into the opt-out form with your email, then click the confirmation link they send.",
               recheckDays: 90, domains: ["spokeo.com"]),
        Broker(id: "whitepages", name: "Whitepages", category: .peopleSearch,
               optOutURL: url("https://www.whitepages.com/suppression-requests"), email: nil,
               instructions: "Paste the link to your Whitepages listing, then confirm with the automated phone call.",
               recheckDays: 90, domains: ["whitepages.com"]),
        Broker(id: "peopleconnect", name: "Intelius, TruthFinder, Instant Checkmate, US Search, ZabaSearch (PeopleConnect)", category: .peopleSearch,
               optOutURL: url("https://suppression.peopleconnect.us/login"), email: nil,
               instructions: "One request covers all PeopleConnect brands. Verify your email, search for your record, and suppress it.",
               recheckDays: 120,
               domains: ["intelius.com", "truthfinder.com", "instantcheckmate.com", "ussearch.com", "zabasearch.com", "peopleconnect.us", "classmates.com"]),
        Broker(id: "beenverified", name: "BeenVerified", category: .peopleSearch,
               optOutURL: url("https://www.beenverified.com/app/optout/search"), email: nil,
               instructions: "Search for your record, select it, and confirm by email. The same request also covers PeopleLooker and related sites.",
               recheckDays: 90, domains: ["beenverified.com", "peoplelooker.com"]),
        Broker(id: "truepeoplesearch", name: "TruePeopleSearch", category: .peopleSearch,
               optOutURL: url("https://www.truepeoplesearch.com/removal"), email: nil,
               instructions: "Enter your email, confirm it, find your record and choose Remove This Record.",
               recheckDays: 60, domains: ["truepeoplesearch.com"]),
        Broker(id: "fastpeoplesearch", name: "FastPeopleSearch", category: .peopleSearch,
               optOutURL: url("https://www.fastpeoplesearch.com/removal"), email: nil,
               instructions: "Enter your email, complete the check, find your record and choose Remove My Record.",
               recheckDays: 60, domains: ["fastpeoplesearch.com"]),
        Broker(id: "peoplefinders", name: "PeopleFinders", category: .peopleSearch,
               optOutURL: url("https://www.peoplefinders.com/opt-out"), email: nil,
               instructions: "Find your record and submit the opt-out form, then confirm by email.",
               recheckDays: 90, domains: ["peoplefinders.com"]),
        Broker(id: "nuwber", name: "Nuwber", category: .peopleSearch,
               optOutURL: url("https://nuwber.com/removal/link"), email: nil,
               instructions: "Search your name on nuwber.com, copy your profile link, paste it into the removal form with your email, then confirm.",
               recheckDays: 90, domains: ["nuwber.com"]),
        Broker(id: "socialcatfish", name: "Social Catfish", category: .peopleSearch,
               optOutURL: url("https://socialcatfish.com/opt-out/"), email: nil,
               instructions: "Choose your state, open the Deletion tab, and paste your listing link. They promise removal within 15 days.",
               recheckDays: 90, domains: ["socialcatfish.com"]),
        Broker(id: "thatsthem", name: "ThatsThem", category: .peopleSearch,
               optOutURL: url("https://thatsthem.com/optout"), email: "optout@thatsthem.com",
               instructions: "Fill in the opt-out form with the details shown on your listing.",
               recheckDays: 90, domains: ["thatsthem.com"]),
        Broker(id: "idcrawl", name: "IDCrawl", category: .peopleSearch,
               optOutURL: url("https://www.idcrawl.com/remove-my-information"), email: "support@idcrawl.com",
               instructions: "Paste the link to the page that shows you and enter your email.",
               recheckDays: 90, domains: ["idcrawl.com"]),
        Broker(id: "usphonebook", name: "USPhoneBook", category: .peopleSearch,
               optOutURL: url("https://www.usphonebook.com/opt-out"), email: nil,
               instructions: "Submit your email, then use the confirmation link (it expires in 24 hours) to pick your record.",
               recheckDays: 90, domains: ["usphonebook.com"]),
        Broker(id: "cyberbackgroundchecks", name: "CyberBackgroundChecks", category: .peopleSearch,
               optOutURL: url("https://www.cyberbackgroundchecks.com/removal"), email: nil,
               instructions: "Enter your name and email, verify, then complete the second form with your record's details.",
               recheckDays: 90, domains: ["cyberbackgroundchecks.com"]),
        Broker(id: "clustrmaps", name: "ClustrMaps", category: .peopleSearch,
               optOutURL: url("https://clustrmaps.com/bl/opt-out"), email: "support@clustrmaps.com",
               instructions: "Paste your listing link with your name and address.",
               recheckDays: 90, domains: ["clustrmaps.com"]),
        Broker(id: "peekyou", name: "PeekYou", category: .peopleSearch,
               optOutURL: url("https://www.peekyou.com/about/contact/optout/"), email: nil,
               instructions: "Paste your profile's unique ID from the listing link, then confirm by email.",
               recheckDays: 90, domains: ["peekyou.com"]),
        Broker(id: "mylife", name: "MyLife", category: .peopleSearch,
               optOutURL: url("https://www.mylife.com/privacyrequest"), email: nil,
               instructions: "Submit a privacy request to remove your profile.",
               recheckDays: 90, domains: ["mylife.com"]),
    ]

    static let professional: [Broker] = [
        Broker(id: "contactout", name: "ContactOut", category: .professional,
               optOutURL: url("https://contactout.com/optout"), email: nil,
               instructions: "Enter the email on your record. The verification link goes to that inbox, so use an address you can still open.",
               recheckDays: 120, domains: ["contactout.com"]),
        Broker(id: "signalhire", name: "SignalHire", category: .professional,
               optOutURL: url("https://www.signalhire.com/opt-out"), email: "support@signalhire.com",
               instructions: "Submit the form with your profile link, or email support.",
               recheckDays: 120, domains: ["signalhire.com"]),
        Broker(id: "zoominfo", name: "ZoomInfo", category: .professional,
               optOutURL: url("https://privacyrequest.zoominfo.com/remove/verify"), email: nil,
               instructions: "Verify your email, then confirm the profile to remove.",
               recheckDays: 120, domains: ["zoominfo.com"]),
    ]

    static let marketing: [Broker] = [
        Broker(id: "lexisnexis", name: "LexisNexis Risk Solutions", category: .marketing,
               optOutURL: url("https://consumer.risk.lexisnexis.com/optrequest"), email: nil,
               instructions: "Opt out of their people-search products. While there, order your free consumer report to see what insurers see.",
               recheckDays: 365, domains: ["lexisnexis.com"]),
        Broker(id: "acxiom", name: "Acxiom", category: .marketing,
               optOutURL: url("https://isapps.acxiom.com/optout/optout.aspx"), email: nil,
               instructions: "Opt out of Acxiom's marketing data. You can also call 1-877-774-2094.",
               recheckDays: 365, domains: ["acxiom.com"]),
        Broker(id: "optoutprescreen", name: "Pre-approved credit and insurance offers", category: .marketing,
               optOutURL: url("https://www.optoutprescreen.com"), email: nil,
               instructions: "The credit bureaus' official site. Opt out for 5 years online, or permanently by mailing the form.",
               recheckDays: 1825, domains: ["optoutprescreen.com"]),
        Broker(id: "dmachoice", name: "Junk mail (DMAchoice)", category: .marketing,
               optOutURL: url("https://www.dmachoice.org"), email: nil,
               instructions: "Remove your name from mailing lists for catalogs, offers and magazines.",
               recheckDays: 365, domains: ["dmachoice.org"]),
    ]

    static let searchEngines: [Broker] = [
        Broker(id: "google-results-about-you", name: "Google - Results about you", category: .searchEngine,
               optOutURL: url("https://myactivity.google.com/results-about-you"), email: nil,
               instructions: "Ask Google to remove results showing your phone, address or email, and get alerts when new ones appear.",
               recheckDays: 90, domains: []),
        Broker(id: "google-outdated", name: "Google - Outdated content", category: .searchEngine,
               optOutURL: url("https://search.google.com/search-console/remove-outdated-content"), email: nil,
               instructions: "Paste a link that's already gone or changed so Google drops the old version.",
               recheckDays: 30, domains: []),
        Broker(id: "bing-removal", name: "Bing - Content removal", category: .searchEngine,
               optOutURL: url("https://www.bing.com/webmaster/tools/contentremoval"), email: nil,
               instructions: "Ask Bing to drop pages that are gone or changed.",
               recheckDays: 30, domains: []),
    ]

    static let archives: [Broker] = [
        Broker(id: "wayback", name: "Internet Archive (Wayback Machine)", category: .archive,
               optOutURL: nil, email: "info@archive.org",
               instructions: "Email a removal request for sites you own. Use the Wayback Machine letter in the Letters tab.",
               recheckDays: 180, domains: ["archive.org"]),
    ]
}
