import Foundation

/// Turns the text read from a photo of a label into one list line. A Nutrition Facts panel
/// becomes a food line with its numbers; a Supplement Facts panel becomes a supplement line
/// with each ingredient and dose. The user reviews and edits it before it's added.
enum LabelParser {
    static func line(from recognized: [String]) -> String? {
        let lines = recognized.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        let joined = lines.joined(separator: "\n").lowercased()

        if joined.contains("supplement facts") || (!joined.contains("nutrition facts") && doses(in: lines).count > 0 && !joined.contains("calories")) {
            return supplementLine(lines)
        }
        if joined.contains("nutrition facts") || joined.contains("calories") {
            return foodLine(lines)
        }
        return "Food: " + lines.prefix(2).joined(separator: " ")
    }

    // MARK: Nutrition Facts

    static func foodLine(_ lines: [String]) -> String {
        let text = lines.joined(separator: "\n")
        var details: [String] = []
        if let serving = firstMatch(#"serving size\s*:?\s*([^\n]+)"#, in: text) {
            details.append("serving " + serving.trimmingCharacters(in: .whitespaces))
        }
        if let calories = calories(in: lines) { details.append("\(calories) kcal") }
        for (label, pattern) in [("protein", #"protein\s*:?\s*(\d{1,3}(?:\.\d)?)\s*g"#),
                                 ("carbs", #"total carbohydrates?\s*:?\s*(\d{1,3}(?:\.\d)?)\s*g"#),
                                 ("fat", #"total fat\s*:?\s*(\d{1,3}(?:\.\d)?)\s*g"#),
                                 ("fiber", #"dietary fib(?:er|re)\s*:?\s*(\d{1,3}(?:\.\d)?)\s*g"#),
                                 ("sugar", #"total sugars?\s*:?\s*(\d{1,3}(?:\.\d)?)\s*g"#)] {
            if let grams = firstMatch(pattern, in: text) { details.append("\(grams) g \(label)") }
        }
        let name = productName(lines) ?? "Scanned food"
        return details.isEmpty ? "Food: \(name)" : "Food: \(name) (\(details.joined(separator: ", ")))"
    }

    // MARK: Supplement Facts

    struct Dose: Equatable {
        var name: String
        var amount: String
    }

    static func supplementLine(_ lines: [String]) -> String {
        let found = doses(in: lines)
        guard !found.isEmpty else { return "Supplement: " + (productName(lines) ?? "Scanned supplement") }
        let listed = found.prefix(3).map { "\($0.name) \($0.amount)" }.joined(separator: ", ")
        if found.count > 3 {
            return "Supplement: \(productName(lines) ?? "Scanned supplement") (\(listed) and \(found.count - 3) more)"
        }
        return "Supplement: " + listed
    }

    /// "Magnesium (as magnesium glycinate) 400 mg 95%" → Magnesium (as magnesium glycinate), 400 mg.
    static func doses(in lines: [String]) -> [Dose] {
        let skip = ["serving", "calories", "daily value", "servings per", "amount per", "%dv",
                    "total fat", "total carbohydrate", "total sugar", "saturated fat", "trans fat"]
        var result: [Dose] = []
        for line in pairingNamesWithAmounts(lines) {
            let lower = line.lowercased()
            guard !skip.contains(where: lower.contains) else { continue }
            guard let match = line.range(of: #"(\d[\d,]*(?:\.\d+)?)\s*(mg|mcg|µg|iu|IU|g)\b"#, options: [.regularExpression, .caseInsensitive]) else { continue }
            let name = line[..<match.lowerBound]
                .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters).subtracting(CharacterSet(charactersIn: ")")))
            guard name.count >= 2, name.contains(where: \.isLetter) else { continue }
            let amount = String(line[match]).replacingOccurrences(of: "µg", with: "mcg")
                .replacingOccurrences(of: #"(\d)(mg|mcg|g|iu|IU)"#, with: "$1 $2", options: .regularExpression)
                .replacingOccurrences(of: " iu", with: " IU")
            result.append(Dose(name: name, amount: amount))
        }
        return result
    }

    /// Wide panels come back from the camera as a column of names and a column of amounts:
    /// "Magnesium (as magnesium glycinate)" then "400 mg". Put each pair back on one line.
    static func pairingNamesWithAmounts(_ lines: [String]) -> [String] {
        let amountOnly = #"^\d[\d,]*(\.\d+)?\s*(mg|mcg|µg|iu|IU|g)\b"#
        var result: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let hasAmount = line.range(of: #"\d[\d,]*(\.\d+)?\s*(mg|mcg|µg|iu|IU|g)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
            if !hasAmount, line.contains(where: \.isLetter), index + 1 < lines.count,
               lines[index + 1].range(of: amountOnly, options: [.regularExpression, .caseInsensitive]) != nil {
                result.append(line + " " + lines[index + 1])
                index += 2
            } else {
                result.append(line)
                index += 1
            }
        }
        return result
    }

    /// "Calories 230", or "Calories" with the number a line or two below it.
    static func calories(in lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard lower.hasPrefix("calories") || lower.hasPrefix("energy") else { continue }
            if let number = firstMatch(#"(?:calories|energy)\s*:?\s*(\d{1,4})\b"#, in: line) { return number }
            for next in lines.dropFirst(index + 1).prefix(2) {
                let trimmed = next.trimmingCharacters(in: .whitespaces)
                if trimmed.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil { return trimmed }
            }
        }
        return firstMatch(#"calories\s*:?\s*(\d{1,4})"#, in: lines.joined(separator: "\n"))
    }

    /// The first line that reads like a name rather than panel text.
    private static func productName(_ lines: [String]) -> String? {
        let panelWords = ["facts", "serving", "amount", "calories", "daily value", "%", "total", "ingredients",
                          "saturated", "trans fat", "cholesterol", "sodium", "sugars", "includes", "dietary",
                          "carbohydrate", "potassium"]
        return lines.first { line in
            let lower = line.lowercased()
            return line.count >= 3 && line.count <= 40 && line.contains(where: \.isLetter)
                && !panelWords.contains(where: lower.contains) && !line.contains(where: \.isNumber)
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
    }
}
