import Foundation

/// Turns a typed or pasted list into log entries: one line per thing, with optional date lines
/// ("10/06/26 -", "Oct 6", "Yesterday") starting each day. This is how many people already
/// keep a food diary in their notes app, so they can keep writing that way, or paste a month
/// of it in at once.
///
/// Each line's type is guessed from its words ("5g creatine" is a supplement, "Two glasses of
/// Merlot" a drink, "1.5 mile walk" activity) and the user can change any guess before adding.
/// Pure and deterministic, so it is unit-tested directly.
enum BulkEntryParser {
    struct Item: Equatable, Identifiable {
        var id: String
        var text: String
        var kind: LogKind
        var milliliters: Int?
        var minutes: Int?
        /// A checklist item this line refers to, ticked when the list is added.
        var habitID: UUID?
    }

    struct Day: Equatable, Identifiable {
        var day: DayKey
        var items: [Item]
        var id: DayKey { day }
    }

    struct Result: Equatable {
        var days: [Day] = []
        /// Lines before the first date, such as a title or "39, 6 ft 4 in, 280 lb".
        var preamble: [String] = []
        /// Lines under a date after today, which are left out.
        var futureLines = 0

        var itemCount: Int { days.reduce(0) { $0 + $1.items.count } }
    }

    static func parse(
        _ text: String,
        defaultDay: DayKey,
        today: DayKey = DayKey.today(),
        habits: [Habit] = [],
        glassMilliliters: Int = 250,
        monthFirst: Bool = BulkEntryParser.monthFirstLocale,
        calendar: Calendar = .current
    ) -> Result {
        let lines = text.components(separatedBy: .newlines)
        let hasDates = lines.contains {
            dateHeader($0, today: today, monthFirst: monthFirst, calendar: calendar) != nil
        }

        var result = Result()
        var order: [DayKey] = []
        var buckets: [DayKey: [Item]] = [:]
        var current: DayKey? = hasDates ? nil : defaultDay

        func add(_ line: String, to day: DayKey) {
            if day > today {
                result.futureLines += 1
                return
            }
            if buckets[day] == nil {
                buckets[day] = []
                order.append(day)
            }
            let index = buckets[day]?.count ?? 0
            buckets[day]?.append(item(
                for: line, id: "\(day)#\(index)", habits: habits, glassMilliliters: glassMilliliters))
        }

        for raw in lines {
            if let header = dateHeader(raw, today: today, monthFirst: monthFirst, calendar: calendar) {
                current = header.day
                if let rest = header.remainder {
                    add(rest, to: header.day)
                }
                continue
            }
            let line = clean(raw)
            guard !line.isEmpty else { continue }
            if let day = current {
                add(line, to: day)
            } else if isPreamble(line) {
                result.preamble.append(line)
            } else {
                // "3 eggs" above a "Yesterday" line was eaten on the day being logged.
                add(line, to: defaultDay)
            }
        }

        result.days = order.map { Day(day: $0, items: buckets[$0] ?? []) }
        return result
    }

    // MARK: Lines

    /// A title or profile line above the first date, such as "Food log", "39, 6 ft 4 in,
    /// 280 lb" or "Goal: lose 20 lb". Anything else is something eaten, drunk or done.
    static func isPreamble(_ line: String) -> Bool {
        let lower = line.lowercased()
        let words = Set(tokens(lower))
        let titleWords: Set<String> = ["log", "diary", "journal", "tracker", "notes", "list", "intake"]
        if !words.isDisjoint(with: titleWords) && classify(line) == .food && line.rangeOfCharacter(from: .decimalDigits) == nil {
            return true
        }
        let profilePattern = #"\b(\d{2,3}\s*(lb|lbs|kg|pounds)|\d\s*(ft|')\s*\d+|\d{2}\s*(years?|yrs?|yo)\b|age|height|weight|goals?|bmi|diagnos|allerg|medication)"#
        return lower.range(of: profilePattern, options: .regularExpression) != nil
    }

    /// Strips list bullets, numbering and checkboxes, so "- [x] 2 eggs" becomes "2 eggs".
    static func clean(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            #"^[-*•·▪◦‣–—]\s+"#,
            #"^\d{1,3}[.)]\s+"#,
            #"^\[[ xX✓✔]?\]\s*"#,
            #"^[☐☑✅✔️✔︎✓]\s*"#,
        ]
        var changed = true
        while changed {
            changed = false
            for pattern in prefixes {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    line.removeSubrange(range)
                    line = line.trimmingCharacters(in: .whitespaces)
                    changed = true
                }
            }
        }
        return line
    }

    static func item(for line: String, id: String, habits: [Habit], glassMilliliters: Int) -> Item {
        let (text, forced) = explicitKind(line)
        var item = Item(id: id, text: text, kind: .food)
        let lower = text.lowercased()
        if let habit = habits.first(where: { habit in
            let name = habit.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard name.count >= 3 else { return false }
            // Whole words, so a "Tea" checklist item isn't ticked by "steak".
            let pattern = "(^|[^a-z0-9])" + NSRegularExpression.escapedPattern(for: name) + "($|[^a-z0-9])"
            return lower.range(of: pattern, options: .regularExpression) != nil
        }) {
            item.habitID = habit.id
        }
        return with(item, kind: forced ?? classify(text), glassMilliliters: glassMilliliters)
    }

    /// "Activity: yard work" and "Supplement: fish oil" set the type and drop the label.
    /// "Breakfast: eggs" and "Mood: good" set the type and keep the label, which the AI uses.
    static func explicitKind(_ line: String) -> (text: String, kind: LogKind?) {
        guard let colon = line.firstIndex(of: ":") else { return (line, nil) }
        let label = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
        let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty, !label.isEmpty, label.allSatisfy({ $0.isLetter }) else { return (line, nil) }
        if let kind = typeLabels[label] { return (rest, kind) }
        if let kind = keptLabels[label] { return (line, kind) }
        return (line, nil)
    }

    private static let typeLabels: [String: LogKind] = [
        "food": .food, "drink": .drink, "drinks": .drink, "supplement": .supplement,
        "supplements": .supplement, "vitamin": .supplement, "vitamins": .supplement,
        "medication": .supplement, "meds": .supplement, "activity": .activity, "exercise": .activity,
        "workout": .activity, "feeling": .feeling, "symptom": .feeling, "note": .note, "other": .note,
    ]
    private static let keptLabels: [String: LogKind] = [
        "breakfast": .food, "lunch": .food, "dinner": .food, "snack": .food, "snacks": .food,
        "supper": .food, "brunch": .food, "dessert": .food, "mood": .feeling, "energy": .feeling,
        "sleep": .feeling,
    ]

    /// The item as another kind, with the amount that kind records: volume for drinks,
    /// duration for activity. Used when the user corrects a guess.
    static func with(_ item: Item, kind: LogKind, glassMilliliters: Int) -> Item {
        var copy = item
        let lower = item.text.lowercased()
        copy.kind = kind
        copy.milliliters = kind == .drink
            ? (milliliters(in: lower) ?? (isPlainWater(lower) ? glassMilliliters * waterCount(in: lower) : nil))
            : nil
        copy.minutes = kind == .activity ? minutes(in: lower) : nil
        return copy
    }

    /// Leaves out lines already logged on that day, so pasting a running note again only adds
    /// what's new. Counts repeats: two "Water" lines against one logged "Water" keeps one.
    static func removingDuplicates(
        of days: [Day], in log: [LogEntry], calendar: Calendar = .current
    ) -> (days: [Day], skipped: Int) {
        var skipped = 0
        var kept: [Day] = []
        let wanted = Set(days.map(\.day))
        var existing: [DayKey: [String: Int]] = [:]
        for entry in log {
            let day = entry.day(calendar: calendar)
            guard wanted.contains(day) else { continue }
            existing[day, default: [:]][normalized(entry.text), default: 0] += 1
        }
        for parsed in days {
            var counts = existing[parsed.day] ?? [:]
            var items: [Item] = []
            for item in parsed.items {
                let key = normalized(item.text)
                if let count = counts[key], count > 0 {
                    counts[key] = count - 1
                    skipped += 1
                } else {
                    items.append(item)
                }
            }
            if !items.isEmpty { kept.append(Day(day: parsed.day, items: items)) }
        }
        return (kept, skipped)
    }

    private static func normalized(_ text: String) -> String {
        tokens(text).joined(separator: " ")
    }

    // MARK: Classification

    static func classify(_ line: String) -> LogKind {
        let words = tokens(line)
        guard let first = words.first else { return .food }
        let phrase = " " + words.joined(separator: " ") + " "

        func hits(_ set: Set<String>, _ phrases: [String] = []) -> Bool {
            words.contains(where: set.contains) || phrases.contains { phrase.contains(" \($0) ") }
        }

        if feelingOpeners.contains(first) { return .feeling }
        if hits(supplementWords, supplementPhrases)
            || words.contains(where: { $0.hasPrefix("ashwa") || $0.hasPrefix("ashwh") || isSupplementDose($0) }) {
            return .supplement
        }
        if hits(activityWords, activityPhrases) { return .activity }
        if hits(noteWords, notePhrases) { return .note }
        if hits(feelingWords, feelingPhrases) { return .feeling }
        if hits(drinkWords, drinkPhrases) { return .drink }
        return .food
    }

    /// Lowercase words, so "steak" never matches "tea" and "ginger" never matches "gin".
    static func tokens(_ line: String) -> [String] {
        line.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// "400mg", "2000iu", "50mcg".
    private static func isSupplementDose(_ word: String) -> Bool {
        word.range(of: #"^\d+(\.\d+)?(mg|mcg|ug|iu)$"#, options: .regularExpression) != nil
            || ["mg", "mcg", "iu"].contains(word)
    }

    private static let feelingOpeners: Set<String> = ["felt", "feel", "feeling", "mood", "energy", "slept", "sleep"]

    private static let supplementWords: Set<String> = [
        "creatine", "vitamin", "vitamins", "multivitamin", "biotin", "magnesium", "zinc", "iron",
        "calcium", "potassium", "omega", "omega3", "krill", "collagen", "melatonin", "glycinate",
        "citrate", "lysine", "b12", "b6", "d3", "k2", "turmeric", "curcumin", "coq10", "theanine",
        "berberine", "psyllium", "metamucil", "supplement", "supplements", "capsule", "capsules",
        "pill", "pills", "tablet", "tablets", "gummy", "gummies", "softgel", "softgels", "selenium",
        "ginkgo", "rhodiola", "electrolyte", "electrolytes", "nac", "glucosamine", "spirulina",
    ]
    private static let supplementPhrases = ["fish oil", "cod liver oil", "multi vitamin", "vitamin d", "vitamin c"]

    private static let activityWords: Set<String> = [
        "walk", "walked", "walking", "run", "ran", "running", "jog", "jogged", "jogging", "hike",
        "hiked", "hiking", "swim", "swam", "swimming", "bike", "biked", "biking", "cycled",
        "cycling", "spin", "peloton", "gym", "workout", "exercise", "exercised", "lift", "lifted",
        "lifting", "weights", "squats", "deadlifts", "pushups", "pullups", "yoga", "pilates",
        "stretch", "stretched", "stretching", "tennis", "pickleball", "golf", "basketball",
        "soccer", "volleyball", "hockey", "skiing", "snowboarding", "surfing", "rowing",
        "elliptical", "treadmill", "stairmaster", "steps", "mile", "miles", "km", "5k", "10k",
        "marathon", "cardio", "hiit", "crossfit", "training", "dance", "danced", "dancing",
        "boxing", "climbing", "sauna", "yardwork", "mowed", "mowing", "gardening", "meditated",
        "meditation", "stairs",
    ]
    private static let activityPhrases = ["yard work", "worked out", "work out", "cold plunge", "ice bath"]

    private static let noteWords: Set<String> = [
        "cigar", "cigars", "cigarette", "cigarettes", "vape", "vaped", "vaping", "nicotine", "zyn",
        "dentist", "dental", "doctor", "appointment", "checkup", "physical", "bloodwork", "labs",
        "massage", "chiropractor", "therapy", "therapist", "weighed", "weight", "bp", "glucose",
        "period", "travel", "flight",
    ]
    private static let notePhrases = ["check up", "blood work", "blood pressure", "weigh in"]

    private static let feelingWords: Set<String> = [
        "felt", "tired", "exhausted", "fatigued", "anxious", "stressed", "headache", "migraine",
        "bloated", "bloating", "nausea", "nauseous", "sore", "insomnia", "groggy", "foggy",
        "crash", "crashed", "cramps", "heartburn", "reflux", "constipated", "diarrhea", "sick",
        "irritable", "moody", "energized", "wired", "restless", "rested", "refreshed",
    ]
    private static let feelingPhrases = ["brain fog", "low energy", "high energy", "slept well", "slept badly"]

    private static let drinkWords: Set<String> = [
        "water", "coffee", "coffees", "espresso", "latte", "cappuccino", "americano", "macchiato",
        "mocha", "tea", "chai", "matcha", "juice", "soda", "pop", "cola", "coke", "sprite",
        "lemonade", "kombucha", "smoothie", "shake", "shakes", "milkshake", "beer", "beers", "ipa",
        "lager", "wine", "chianti", "merlot", "shiraz", "syrah", "cabernet", "pinot", "chardonnay",
        "sauvignon", "riesling", "rose", "prosecco", "champagne", "cava", "sangria", "martini",
        "margarita", "mojito", "cocktail", "cocktails", "vodka", "whiskey", "whisky", "bourbon",
        "scotch", "tequila", "mezcal", "gin", "rum", "sake", "cider", "seltzer", "lacroix",
        "sparkling", "bubbly", "gatorade", "powerade", "bodyarmor", "hydration", "lmnt",
        "celsius", "redbull", "monster", "poppi", "olipop", "ollipop", "drink", "drinks", "glass",
        "glasses", "bottle", "pint", "pints", "cocoa",
    ]
    private static let drinkPhrases = ["cold brew", "body armor", "red bull", "la croix", "hot chocolate", "dr pepper"]

    // MARK: Amounts

    /// "9oz Shiraz" is 266 ml, "500 ml water" 500, "1.5 l" 1500.
    static func milliliters(in lower: String) -> Int? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(fl\.?\s*oz|oz|ounces?|ml|milliliters?|millilitres?|l|liters?|litres?)\b"#
        guard let match = lower.range(of: pattern, options: .regularExpression) else { return nil }
        let found = String(lower[match])
        guard let number = Double(found.prefix { $0.isNumber || $0 == "." }) else { return nil }
        let unit = found.drop { $0.isNumber || $0 == "." || $0 == " " }
        let factor: Double
        if unit.hasPrefix("m") {
            factor = 1
        } else if unit.hasPrefix("l") {
            factor = 1000
        } else {
            factor = 29.5735
        }
        let value = Int((number * factor).rounded())
        return value > 0 && value <= 5000 ? value : nil
    }

    /// "for an hour" is 60, "45 min" 45, "1.5 hours" 90.
    static func minutes(in lower: String) -> Int? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(minutes?|mins?|hours?|hrs?|h)\b"#
        if let match = lower.range(of: pattern, options: .regularExpression) {
            let found = String(lower[match])
            guard let number = Double(found.prefix { $0.isNumber || $0 == "." }) else { return nil }
            let isHours = found.contains("h")
            let value = Int((isHours ? number * 60 : number).rounded())
            return value > 0 && value <= 1440 ? value : nil
        }
        if lower.contains("half an hour") || lower.contains("half hour") { return 30 }
        if lower.contains("an hour") || lower.contains("one hour") { return 60 }
        return nil
    }

    /// "Water", "Glass of water", "Big bottle of water": counts as a glass. "Coconut water" does
    /// not, since it isn't plain water.
    static func isPlainWater(_ lower: String) -> Bool {
        let filler: Set<String> = ["water", "glass", "glasses", "of", "a", "bottle", "bottles", "sparkling",
                                   "still", "cold", "ice", "iced", "big", "large", "small", "tap",
                                   "filtered", "plain", "bubbly", "some", "cup", "cups", "x"]
        let words = tokens(timesCount(lower))
        return words.contains("water") && words.allSatisfy { filler.contains($0) || countWords[$0] != nil || Int($0) != nil }
    }

    private static let countWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
    ]

    /// "water x3" and "water 3x" → "water 3".
    private static func timesCount(_ lower: String) -> String {
        lower.replacingOccurrences(of: #"\bx\s*(\d+)\b|\b(\d+)\s*x\b"#, with: "$1$2", options: .regularExpression)
    }

    /// "2 glasses of water" and "water x3" are that many glasses; plain "water" is one.
    static func waterCount(in lower: String) -> Int {
        for word in tokens(timesCount(lower)) {
            if let number = Int(word), (1...12).contains(number) { return number }
            if let number = countWords[word] { return number }
        }
        return 1
    }

    // MARK: Dates

    struct Header: Equatable {
        var day: DayKey
        /// Text after the date on the same line, as in "10/06/26 - Steak salad".
        var remainder: String?
    }

    /// Month first in the US and a few other places, day first elsewhere. "13/10" is read as
    /// day first anywhere, since there is no month 13.
    static var monthFirstLocale: Bool {
        let region = Locale.current.region?.identifier ?? "US"
        return ["US", "PH", "PR", "GU", "AS", "VI", "UM", "MH", "FM", "PW", "BZ"].contains(region)
    }

    static func dateHeader(_ raw: String, today: DayKey, monthFirst: Bool, calendar: Calendar) -> Header? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !line.isEmpty, line.count <= 120 else { return nil }
        line = line.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)

        // A date alone on its line, optionally followed by a dash or colon.
        let trailing = #"\s*[-–—:,.]*\s*$"#
        if let day = parseDate(line.replacingOccurrences(of: trailing, with: "", options: .regularExpression),
                               today: today, monthFirst: monthFirst, calendar: calendar) {
            return Header(day: day, remainder: nil)
        }

        // "10/06/26 - Steak salad", "Yesterday: pizza", "Oct 5 - pizza", "Monday: tacos".
        // A numeric date needs its year here, so "1/2 - avocado" stays food.
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
        let inline = #"^(.{3,30}?)\s*(:|\s[-–—]|[-–—]\s)\s*(\S.*)$"#
        if let regex = try? NSRegularExpression(pattern: inline),
           let match = regex.firstMatch(in: original, range: NSRange(original.startIndex..., in: original)),
           let prefixRange = Range(match.range(at: 1), in: original),
           let restRange = Range(match.range(at: 3), in: original) {
            let dateText = original[prefixRange].lowercased().trimmingCharacters(in: .whitespaces)
            let shortNumeric = dateText.range(of: #"^\d{1,2}[/.\-]\d{1,2}$"#, options: .regularExpression) != nil
            if !shortNumeric, let day = parseDate(dateText, today: today, monthFirst: monthFirst, calendar: calendar) {
                let rest = clean(String(original[restRange]))
                return Header(day: day, remainder: rest.isEmpty ? nil : rest)
            }
        }
        return nil
    }

    private static let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                                   "mon", "tue", "tues", "wed", "thu", "thur", "thurs", "fri", "sat", "sun"]
    /// Calendar weekday numbers (Sunday is 1) for `weekdays`, in the same order.
    private static let weekdayNumbers = [2, 3, 4, 5, 6, 7, 1, 2, 3, 3, 4, 5, 5, 5, 6, 7, 1]

    private static func mostRecent(weekday: Int, before today: DayKey, calendar: Calendar) -> DayKey? {
        for offset in 0..<7 {
            let day = today.adding(days: -offset, calendar: calendar)
            if calendar.component(.weekday, from: day.date(calendar: calendar)) == weekday { return day }
        }
        return nil
    }

    private static let months = ["january", "february", "march", "april", "may", "june", "july",
                                 "august", "september", "october", "november", "december"]

    static func parseDate(_ text: String, today: DayKey, monthFirst: Bool, calendar: Calendar) -> DayKey? {
        var line = text.trimmingCharacters(in: .whitespaces)
        if line == "today" { return today }
        if line == "yesterday" { return today.adding(days: -1, calendar: calendar) }

        // Drop a leading weekday: "Mon 10/6", "Monday, October 6". Alone, it's the most
        // recent such day: "Monday" on a Wednesday is two days ago.
        for (index, name) in weekdays.enumerated() where line.hasPrefix(name) {
            let rest = line.dropFirst(name.count)
            if rest.isEmpty { return mostRecent(weekday: weekdayNumbers[index], before: today, calendar: calendar) }
            if let next = rest.first, next == " " || next == "," || next == "." {
                line = rest.trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
                break
            }
        }

        // 10/06/26, 9/28, 2026-10-06
        if let match = line.range(of: #"^\d{4}-\d{1,2}-\d{1,2}$"#, options: .regularExpression),
           match == line.startIndex..<line.endIndex {
            let parts = line.split(separator: "-").compactMap { Int($0) }
            return make(year: parts[0], month: parts[1], day: parts[2], today: today, calendar: calendar)
        }
        // A dot only with a year, so "5.5" on its own isn't read as a date.
        if line.range(of: #"^\d{1,2}[/\-]\d{1,2}([/\-]\d{2,4})?$|^\d{1,2}\.\d{1,2}\.\d{2,4}$"#, options: .regularExpression) != nil {
            let parts = line.split(whereSeparator: { "/.-".contains($0) }).compactMap { Int($0) }
            var (month, day) = monthFirst ? (parts[0], parts[1]) : (parts[1], parts[0])
            if month > 12 && day <= 12 { swap(&month, &day) }
            let year = parts.count > 2 ? (parts[2] < 100 ? 2000 + parts[2] : parts[2]) : nil
            return make(year: year, month: month, day: day, today: today, calendar: calendar)
        }

        // October 6, Oct 6th 2026, 6 Oct
        let wordsPattern = #"^([a-z]+)\.?\s+(\d{1,2})(st|nd|rd|th)?(,?\s+(\d{4}))?$"#
        if line.range(of: wordsPattern, options: .regularExpression) != nil {
            let parts = line.replacingOccurrences(of: ",", with: " ").split(separator: " ")
            guard let month = monthIndex(String(parts[0])) else { return nil }
            let day = Int(parts[1].prefix { $0.isNumber }) ?? 0
            let year = parts.count > 2 ? Int(parts[2]) : nil
            return make(year: year, month: month, day: day, today: today, calendar: calendar)
        }
        let dayFirstPattern = #"^(\d{1,2})(st|nd|rd|th)?\s+([a-z]+)\.?(\s+(\d{4}))?$"#
        if line.range(of: dayFirstPattern, options: .regularExpression) != nil {
            let parts = line.split(separator: " ")
            guard let month = monthIndex(String(parts[1])) else { return nil }
            let day = Int(parts[0].prefix { $0.isNumber }) ?? 0
            let year = parts.count > 2 ? Int(parts[2]) : nil
            return make(year: year, month: month, day: day, today: today, calendar: calendar)
        }
        return nil
    }

    /// "oct", "sept" and "october" all count; "marathon" and "mayo" don't.
    private static func monthIndex(_ word: String) -> Int? {
        guard word.count >= 3, let index = months.firstIndex(where: { $0.hasPrefix(word) }) else { return nil }
        return index + 1
    }

    /// Without a year, the most recent such date that isn't in the future.
    private static func make(year: Int?, month: Int, day: Int, today: DayKey, calendar: Calendar) -> DayKey? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let candidateYear = year ?? today.year
        guard var key = valid(year: candidateYear, month: month, day: day, calendar: calendar) else { return nil }
        if year == nil, key > today, let previous = valid(year: candidateYear - 1, month: month, day: day, calendar: calendar) {
            key = previous
        }
        return key
    }

    private static func valid(year: Int, month: Int, day: Int, calendar: Calendar) -> DayKey? {
        guard (2000...2100).contains(year) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return DayKey(date, calendar: calendar)
    }
}
