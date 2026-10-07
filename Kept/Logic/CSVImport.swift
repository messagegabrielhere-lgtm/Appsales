import Foundation

/// Reads spreadsheet (CSV) exports from other food, mood and fitness apps and turns them into
/// the same one-line-per-thing list a user can paste, with a date line per day. The list editor
/// then shows every line, its guessed type and duplicates before anything is added, so an
/// import is reviewed exactly like a paste.
///
/// Columns are found by name, not position: a date column, the column that says what it was
/// ("Food Name", "Name", "Description", "Activities"…), and any of type or meal, amount and
/// unit, calories, protein, mood and notes. That covers most apps' exports without knowing
/// each one.
enum CSVImport {
    struct Conversion: Equatable {
        /// The list, ready for `BulkEntryParser`.
        var text: String
        var rows: Int
        /// Rows without a readable date.
        var skippedRows: Int
    }

    // MARK: Parsing

    /// RFC 4180 rows. The delimiter is whichever of comma, semicolon or tab the header uses most.
    static func rows(_ text: String) -> [[String]] {
        let content = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let firstLine = content.prefix { $0 != "\n" && $0 != "\r" }
        var delimiter: Character = ","
        var best = firstLine.filter { $0 == "," }.count
        for candidate: Character in [";", "\t"] {
            let count = firstLine.filter { $0 == candidate }.count
            if count > best {
                delimiter = candidate
                best = count
            }
        }

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(content).makeIterator()
        var pending: Character? = nil

        func endField() {
            row.append(field)
            field = ""
        }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].trimmingCharacters(in: .whitespaces).isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while let char = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = next
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" && field.isEmpty {
                inQuotes = true
            } else if char == delimiter {
                endField()
            } else if char == "\n" || char == "\r\n" {
                endRow()
            } else if char == "\r" {
                if let next = iterator.next(), next != "\n" { pending = next }
                endRow()
            } else {
                field.append(char)
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    // MARK: Columns

    struct Columns: Equatable {
        var date: Int
        var text: Int?
        var kind: Int?
        var amount: Int?
        var unit: Int?
        var calories: Int?
        var protein: Int?
        var mood: Int?
        var notes: Int?
        var milliliters: Int?
        var minutes: Int?
        var rating: Int?
    }

    static func normalize(_ header: String) -> String {
        header.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func columns(for header: [String]) -> Columns? {
        let names = header.map(normalize)
        var used = Set<Int>()

        func find(_ candidates: [String], contains: Bool = false) -> Int? {
            for candidate in candidates {
                if let index = names.indices.first(where: { !used.contains($0) && names[$0] == candidate }) {
                    used.insert(index)
                    return index
                }
            }
            guard contains else { return nil }
            for candidate in candidates {
                if let index = names.indices.first(where: { !used.contains($0) && names[$0].contains(candidate) }) {
                    used.insert(index)
                    return index
                }
            }
            return nil
        }

        guard let date = find(["date", "day", "full date", "datetime", "date time", "timestamp",
                               "logged at", "start date", "start", "time stamp"], contains: true) else {
            return nil
        }
        _ = find(["time", "start time"])
        var columns = Columns(date: date)
        columns.kind = find(["type", "meal", "meal type", "category", "group", "kind", "entry type"])
        columns.text = find(["food name", "food", "name", "item", "description", "entry", "text", "title",
                             "activities", "activity", "exercise", "meal name", "product", "label"])
        columns.amount = find(["amount", "quantity", "qty", "serving", "servings", "serving size", "portion"])
        columns.unit = find(["unit", "units", "serving unit"])
        columns.calories = find(["calories", "energy kcal", "kcal", "energy", "calories kcal"], contains: true)
        columns.protein = find(["protein", "protein g"], contains: true)
        columns.mood = find(["mood"])
        columns.milliliters = find(["milliliters", "ml"])
        columns.minutes = find(["minutes", "duration", "duration min"])
        columns.rating = find(["rating"])
        columns.notes = find(["note", "notes", "comment", "comments", "note title"])
        return columns
    }

    // MARK: Conversion

    static func convert(
        _ csv: String,
        today: DayKey = DayKey.today(),
        monthFirst: Bool = BulkEntryParser.monthFirstLocale,
        calendar: Calendar = .current
    ) -> Conversion? {
        let table = rows(csv)
        guard table.count >= 2, let columns = columns(for: table[0]) else { return nil }

        var order: [DayKey] = []
        var byDay: [DayKey: [String]] = [:]
        var skipped = 0
        var count = 0

        for row in table.dropFirst() {
            func value(_ index: Int?) -> String {
                guard let index, index < row.count else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let day = parseDay(value(columns.date), today: today, monthFirst: monthFirst, calendar: calendar) else {
                skipped += 1
                continue
            }
            let lines = self.lines(
                text: value(columns.text), kind: value(columns.kind), amount: value(columns.amount),
                unit: value(columns.unit), calories: value(columns.calories), protein: value(columns.protein),
                mood: value(columns.mood), notes: value(columns.notes), milliliters: value(columns.milliliters),
                minutes: value(columns.minutes), rating: value(columns.rating)
            )
            guard !lines.isEmpty else { continue }
            if byDay[day] == nil {
                byDay[day] = []
                order.append(day)
            }
            byDay[day]?.append(contentsOf: lines)
            count += 1
        }
        guard count > 0 else { return nil }

        var output: [String] = []
        for day in order.sorted() {
            if !output.isEmpty { output.append("") }
            output.append(String(format: "%04d-%02d-%02d", day.year, day.month, day.day))
            output.append(contentsOf: byDay[day] ?? [])
        }
        return Conversion(text: output.joined(separator: "\n"), rows: count, skippedRows: skipped)
    }

    /// One row as list lines, with a type prefix where the export says what it was.
    static func lines(
        text: String, kind: String, amount: String = "", unit: String = "", calories: String = "",
        protein: String = "", mood: String = "", notes: String = "", milliliters: String = "",
        minutes: String = "", rating: String = ""
    ) -> [String] {
        var result: [String] = []
        let kindLower = kind.lowercased()
        var main = oneLine(text)
        if main.isEmpty && !kind.isEmpty && mood.isEmpty { main = oneLine(kind) }

        if !main.isEmpty {
            var details: [String] = []
            let portion = [amount, unit].filter { !$0.isEmpty }.joined(separator: " ")
            if !portion.isEmpty { details.append(portion) }
            if let ml = Double(milliliters), ml > 0 { details.append("\(Int(ml)) ml") }
            if let min = Double(minutes), min > 0 { details.append("\(Int(min)) min") }
            if let kcal = Double(calories), kcal > 0 { details.append("\(Int(kcal.rounded())) kcal") }
            if let grams = Double(protein), grams > 0 { details.append("\(formatted(grams)) g protein") }
            if let stars = Int(rating), (1...5).contains(stars) { details.append("rated \(stars)/5") }
            let line = details.isEmpty ? main : "\(main) (\(details.joined(separator: ", ")))"
            result.append(prefix(for: kindLower, text: main) + line)
        }
        if !mood.isEmpty {
            result.append("Mood: \(oneLine(mood))")
        }
        let note = oneLine(notes)
        if !note.isEmpty && note != main {
            result.append("Note: \(note)")
        }
        return result
    }

    /// Fuelprint's list understands "Activity: …" and similar; meal names stay in the text.
    private static func prefix(for kind: String, text: String) -> String {
        let words = Set(BulkEntryParser.tokens(kind))
        if text.lowercased() == kind { return "" }
        if !words.isDisjoint(with: ["exercise", "exercises", "workout", "workouts", "activity", "activities", "cardio", "strength"]) {
            return "Activity: "
        }
        if !words.isDisjoint(with: ["drink", "drinks", "beverage", "beverages", "water", "fluid", "fluids"]) {
            return "Drink: "
        }
        if !words.isDisjoint(with: ["supplement", "supplements", "vitamin", "vitamins", "medication", "medications", "checklist"]) {
            return "Supplement: "
        }
        if !words.isDisjoint(with: ["feeling", "feelings", "mood", "symptom", "symptoms"]) {
            return "Feeling: "
        }
        if !words.isDisjoint(with: ["note", "notes", "other"]) {
            return "Note: "
        }
        if !words.isDisjoint(with: ["breakfast", "lunch", "dinner", "snack", "snacks", "supper", "brunch"]) {
            return kind.prefix(1).uppercased() + kind.dropFirst() + ": "
        }
        if !words.isDisjoint(with: ["food", "meal", "meals"]) {
            return "Food: "
        }
        return ""
    }

    private static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// "2026-10-06", "2026-10-06T08:15:00Z", "10/06/2026 8:15 AM", "Oct 6, 2026".
    static func parseDay(_ raw: String, today: DayKey, monthFirst: Bool, calendar: Calendar) -> DayKey? {
        let value = raw.lowercased().trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        if value.range(of: #"^\d{4}-\d{1,2}-\d{1,2}"#, options: .regularExpression) != nil {
            let datePart = String(value.prefix { $0.isNumber || $0 == "-" })
            return BulkEntryParser.parseDate(datePart, today: today, monthFirst: monthFirst, calendar: calendar)
        }
        if let day = BulkEntryParser.parseDate(value, today: today, monthFirst: monthFirst, calendar: calendar) {
            return day
        }
        // Drop a trailing time: "10/06/2026 8:15 am", "oct 6, 2026 at 8:15".
        let withoutTime = value
            .replacingOccurrences(of: #"(\s+at)?\s+\d{1,2}:\d{2}(:\d{2})?(\s*[ap]\.?m\.?)?.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        return BulkEntryParser.parseDate(withoutTime, today: today, monthFirst: monthFirst, calendar: calendar)
    }
}
