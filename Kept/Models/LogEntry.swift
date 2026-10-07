import Foundation

/// What a log entry records.
enum LogKind: String, Codable, CaseIterable, Identifiable {
    case food
    case drink
    case activity
    case feeling
    case supplement
    case note

    var id: String { rawValue }

    /// The big buttons on Today and the widget. Supplements are usually ticked on the
    /// checklist, and notes are rare, so both are a tap away in the editor instead.
    static let quickAdd: [LogKind] = [.food, .drink, .activity, .feeling]

    var title: String {
        switch self {
        case .food: return "Food"
        case .drink: return "Drink"
        case .activity: return "Activity"
        case .feeling: return "Feeling"
        case .supplement: return "Supplement"
        case .note: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .drink: return "cup.and.saucer.fill"
        case .activity: return "figure.walk"
        case .feeling: return "heart.fill"
        case .supplement: return "pills.fill"
        case .note: return "note.text"
        }
    }

    var colorName: String {
        switch self {
        case .food: return "orange"
        case .drink: return "blue"
        case .activity: return "green"
        case .feeling: return "pink"
        case .supplement: return "purple"
        case .note: return "gray"
        }
    }

    var question: String {
        switch self {
        case .food: return "What did you eat?"
        case .drink: return "What did you drink?"
        case .activity: return "What did you do?"
        case .feeling: return "Anything to note?"
        case .supplement: return "What did you take?"
        case .note: return "What happened?"
        }
    }

    var placeholder: String {
        switch self {
        case .food: return "e.g. Oatmeal with berries and honey"
        case .drink: return "e.g. Flat white"
        case .activity: return "e.g. Run, easy pace"
        case .feeling: return "Energy, mood, sleep, digestion…"
        case .supplement: return "e.g. Creatine 5 g"
        case .note: return "e.g. Dentist check-up, all clear"
        }
    }
}

/// One thing that happened at a point in time: a meal, a drink, some activity, a supplement,
/// a note on how the user feels, or anything else worth telling the AI. Deliberately free text. Kept does not look up nutrition; the AI the
/// user shares with does that far better than a manual database lookup.
struct LogEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: LogKind
    var date: Date
    var text: String
    /// Free-text portion for food, such as "1 bowl".
    var amount: String?
    /// Volume for drinks.
    var milliliters: Int?
    /// Duration for activity.
    var minutes: Int?
    /// 1 (awful) to 5 (great), for feelings.
    var rating: Int?
    /// Added from a typed or pasted list without a time. Kept in the order written; the
    /// timeline and AI export show no time for it rather than inventing one.
    var untimed: Bool


    init(
        id: UUID = UUID(),
        kind: LogKind,
        date: Date = Date(),
        text: String,
        amount: String? = nil,
        milliliters: Int? = nil,
        minutes: Int? = nil,
        rating: Int? = nil,
        untimed: Bool = false
    ) {
        self.id = id
        self.kind = kind
        // Stored at the resolution the file keeps, so a saved entry equals this one.
        self.date = KeptDateCoding.canonical(date)
        self.text = text
        self.amount = amount
        self.milliliters = milliliters
        self.minutes = minutes
        self.rating = rating.map(LogEntry.clampRating)
        self.untimed = untimed
    }

    static func clampRating(_ value: Int) -> Int {
        min(5, max(1, value))
    }

    func day(calendar: Calendar = .current) -> DayKey {
        DayKey(date, calendar: calendar)
    }

    var isWater: Bool {
        kind == .drink && text.localizedCaseInsensitiveContains("water")
    }

    static let ratingFaces = ["😣", "🙁", "😐", "🙂", "😄"]
    static let ratingLabels = ["Awful", "Poor", "OK", "Good", "Great"]

    static func face(for rating: Int) -> String {
        ratingFaces[clampRating(rating) - 1]
    }

    static func label(for rating: Int) -> String {
        ratingLabels[clampRating(rating) - 1]
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, kind, date, text, amount, milliliters, minutes, rating, untimed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(LogKind.self, forKey: .kind)
        date = KeptDateCoding.canonical(try container.decode(Date.self, forKey: .date))
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        amount = try container.decodeIfPresent(String.self, forKey: .amount)
        milliliters = try container.decodeIfPresent(Int.self, forKey: .milliliters)
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating).map(LogEntry.clampRating)
        untimed = try container.decodeIfPresent(Bool.self, forKey: .untimed) ?? false
    }

    /// Only written when true, so files stay identical for entries logged with a time.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(date, forKey: .date)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(milliliters, forKey: .milliliters)
        try container.encodeIfPresent(minutes, forKey: .minutes)
        try container.encodeIfPresent(rating, forKey: .rating)
        if untimed { try container.encode(true, forKey: .untimed) }
    }

    /// Where an untimed entry sits: midday, one second apart, so a pasted list keeps its
    /// order and stays inside its day in any time zone.
    static func untimedDate(on day: DayKey, index: Int, calendar: Calendar = .current) -> Date {
        let start = day.date(calendar: calendar)
        let noon = calendar.date(byAdding: .hour, value: 12, to: start) ?? start
        return noon.addingTimeInterval(TimeInterval(index))
    }
}
