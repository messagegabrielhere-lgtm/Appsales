import Foundation

/// Reads daily nutrition estimates out of an AI assistant's answer. The nutrition prompts ask
/// for a small block at the end:
///
///     FUELPRINT-DAILY
///     date,calories,protein_g,carbs_g,fat_g,fiber_g
///     2026-10-06,2100,140,180,80,25
///     END
///
/// Assistants don't always follow formats exactly, so this also reads Markdown tables and
/// loose lines: any line with an ISO date followed by numbers, with columns matched by header
/// names when there is a header, in the block's order otherwise. Ranges ("1,900-2,200") count
/// as their midpoint.
enum EstimateParser {
    static let marker = "FUELPRINT-DAILY"

    static let request = """
    At the very end, add this block exactly, one line for each day that has food logged \
    (skip days with nothing logged), plain numbers only, no thousands separators (use the \
    middle of any range), so I can save the estimates:
    \(marker)
    date,calories,protein_g,carbs_g,fat_g,fiber_g
    YYYY-MM-DD,0,0,0,0,0
    END
    """

    enum Column: CaseIterable {
        case calories, protein, carbs, fat, fiber
    }

    static func parse(_ answer: String, now: Date = Date()) -> [DailyEstimate] {
        var lines = answer.components(separatedBy: .newlines)
        // When the answer has the block, read only the block: prose above it often mentions
        // dates and totals ("from 2026-10-01 to 2026-10-07 you averaged 2,050 kcal").
        if let start = lines.firstIndex(where: { $0.uppercased().contains(marker) }) {
            let after = lines[(start + 1)...]
            let end = after.firstIndex { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("END") } ?? lines.endIndex
            lines = Array(lines[(start + 1)..<end])
        }

        var order: [Column] = Column.allCases
        var byDay: [DayKey: DailyEstimate] = [:]

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()
            if !lower.contains(where: \.isNumber), let header = headerOrder(lower) {
                order = header
                continue
            }
            guard let dateRange = line.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression),
                  let day = DayKey(isoString: String(line[dateRange])) else { continue }
            var rest = String(line[dateRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            // A second date means a span ("2026-10-01 to 2026-10-07"), not one day's numbers.
            guard rest.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) == nil else { continue }
            // "140 g (27%)": the percentage isn't another column.
            rest = rest.replacingOccurrences(of: #"\(?\s*\d+(\.\d+)?\s*%\s*\)?"#, with: "", options: .regularExpression)

            let values: [Double?]
            if rest.hasPrefix(",") {
                values = blockValues(String(rest.dropFirst()), columns: order.count)
            } else if rest.contains("|") {
                values = rest.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .drop { $0.isEmpty }
                    .map { numbers(in: String($0)).first }
            } else {
                values = numbers(in: rest).map { Optional($0) }
            }

            var estimate = DailyEstimate(day: day, savedAt: now)
            var found = false
            for (column, value) in zip(order, values) {
                guard let value, value > 0 else { continue }
                found = true
                let rounded = Int(value.rounded())
                switch column {
                case .calories: estimate.calories = rounded
                case .protein: estimate.proteinGrams = rounded
                case .carbs: estimate.carbsGrams = rounded
                case .fat: estimate.fatGrams = rounded
                case .fiber: estimate.fiberGrams = rounded
                }
            }
            // An all-zero or empty row is a day with nothing logged, not a 0 kcal day.
            guard found else { continue }
            byDay[day] = estimate
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    /// The comma-separated cells after the date, by position, so an empty or "n/a" cell
    /// leaves its column empty instead of shifting the rest. Quoted cells ("1,850") are one
    /// cell, and an unquoted "2,100" in the calories column is put back together.
    static func blockValues(_ text: String, columns: Int) -> [Double?] {
        var cells: [String] = []
        var current = ""
        var quoted = false
        for character in text {
            if character == "\"" {
                quoted.toggle()
            } else if character == "," && !quoted {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        cells.append(current)
        cells = cells.map { $0.trimmingCharacters(in: .whitespaces) }
        while cells.count > columns, cells.count >= 2,
              cells[0].range(of: #"^\d{1,2}$"#, options: .regularExpression) != nil,
              cells[1].range(of: #"^\d{3}$"#, options: .regularExpression) != nil {
            cells[0] += cells[1]
            cells.remove(at: 1)
        }
        return cells.map { numbers(in: $0).first }
    }

    /// Column order from a header such as "| Date | Calories | Protein (g) | Fiber |".
    static func headerOrder(_ lower: String) -> [Column]? {
        let cells = lower.components(separatedBy: CharacterSet(charactersIn: ",|\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard cells.contains(where: { $0.contains("date") || $0 == "day" }) else { return nil }
        var columns: [Column] = []
        for cell in cells where !(cell.contains("date") || cell == "day") {
            if cell.contains("cal") || cell.contains("kcal") || cell.contains("energy") { columns.append(.calories) }
            else if cell.contains("protein") { columns.append(.protein) }
            else if cell.contains("carb") { columns.append(.carbs) }
            else if cell.contains("fiber") || cell.contains("fibre") { columns.append(.fiber) }
            else if cell.contains("fat") { columns.append(.fat) }
            else { return nil }
        }
        return columns.isEmpty ? nil : columns
    }

    /// Numbers in order, reading "1,900" as 1900 and "1,900-2,200" or "1900–2200" as 2050.
    static func numbers(in text: String) -> [Double] {
        let pattern = #"(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)(?:\s*[-–—]\s*(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            func value(_ index: Int) -> Double? {
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return nil }
                return Double(ns.substring(with: range).replacingOccurrences(of: ",", with: ""))
            }
            guard let low = value(1) else { return nil }
            if let high = value(2) { return (low + high) / 2 }
            return low
        }
    }
}
