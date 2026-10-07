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
    At the very end, add this block exactly, one line per day, plain numbers only (use the \
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
        var order: [Column] = Column.allCases
        var byDay: [DayKey: DailyEstimate] = [:]

        for raw in answer.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()
            if !lower.contains(where: \.isNumber), let header = headerOrder(lower) {
                order = header
                continue
            }
            guard let dateRange = line.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression),
                  let day = DayKey(isoString: String(line[dateRange])) else { continue }
            let rest = String(line[dateRange.upperBound...])
            let values = numbers(in: rest)
            guard !values.isEmpty else { continue }
            var estimate = DailyEstimate(day: day, savedAt: now)
            for (column, value) in zip(order, values) {
                let rounded = Int(value.rounded())
                switch column {
                case .calories: estimate.calories = rounded
                case .protein: estimate.proteinGrams = rounded
                case .carbs: estimate.carbsGrams = rounded
                case .fat: estimate.fatGrams = rounded
                case .fiber: estimate.fiberGrams = rounded
                }
            }
            byDay[day] = estimate
        }
        return byDay.values.sorted { $0.day < $1.day }
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
