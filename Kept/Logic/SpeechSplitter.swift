import Foundation

/// Turns a spoken description of a day into the one-thing-per-line list that `BulkEntryParser`
/// reads. "Yesterday I had two eggs and toast with black coffee, then five grams of creatine
/// and a thirty minute walk" becomes a Yesterday line and four entries.
///
/// Speech arrives as one run-on sentence, so it's cut at clear breaks (commas, "then", "also"),
/// then at "and" or "with" only where the two sides are different kinds of thing: "eggs and
/// toast" stays one meal, "toast with black coffee" becomes food and a drink.
enum SpeechSplitter {
    static func list(from transcript: String) -> String {
        var text = normalizeNumbers(in: transcript.trimmingCharacters(in: .whitespacesAndNewlines))
        var lines: [String] = []

        // A leading day: "Yesterday I had…", "Today…".
        let lower = text.lowercased()
        for (word, header) in [("yesterday", "Yesterday"), ("today", "Today")] where lower.hasPrefix(word) {
            lines.append(header)
            text = String(text.dropFirst(word.count))
            break
        }

        for chunk in strongChunks(text) {
            lines.append(contentsOf: splitByKind(chunk))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Breaking

    private static let strongBreaks = [
        #"[,;.!?]+"#, #"\band then\b"#, #"\bthen\b"#, #"\bafter that\b"#, #"\balso\b"#, #"\bplus\b"#,
        #"\bfollowed by\b"#, #"\blater\b"#,
    ]

    private static let fillers = [
        "i had", "i ate", "i drank", "i took", "i did", "i went for", "i've had", "had", "ate", "drank",
        "took", "did", "for breakfast", "for lunch", "for dinner", "my", "some", "um", "uh", "like",
    ]

    static func strongChunks(_ text: String) -> [String] {
        var pieces = [text]
        for pattern in strongBreaks {
            pieces = pieces.flatMap { split($0, pattern: pattern) }
        }
        return pieces.map(cleanFillers).filter { !$0.isEmpty }
    }

    /// "two eggs and toast with black coffee" → ["two eggs and toast", "black coffee"].
    static func splitByKind(_ chunk: String) -> [String] {
        let pattern = #"\s+(and|with)\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [chunk] }
        let ns = chunk as NSString
        let matches = regex.matches(in: chunk, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [chunk] }

        var atoms: [String] = []
        var joiners: [String] = []
        var start = 0
        for match in matches {
            atoms.append(ns.substring(with: NSRange(location: start, length: match.range.location - start)))
            joiners.append(ns.substring(with: match.range))
            start = match.range.location + match.range.length
        }
        atoms.append(ns.substring(from: start))

        var result: [String] = []
        var current = atoms[0].trimmingCharacters(in: .whitespaces)
        for index in 1..<atoms.count {
            let next = atoms[index].trimmingCharacters(in: .whitespaces)
            let nextLower = next.lowercased()
            let mealContext = mealWords.contains(nextLower) || mealWords.contains(where: { nextLower == "a " + $0 })
            let sameKind = BulkEntryParser.classify(current) == BulkEntryParser.classify(next)
            if mealContext || sameKind || next.isEmpty {
                current += joiners[index - 1] + next
            } else {
                result.append(current)
                current = next
            }
        }
        result.append(current)
        return result.map(cleanFillers).filter { !$0.isEmpty }
    }

    private static let mealWords: Set<String> = ["breakfast", "lunch", "dinner", "supper", "brunch", "dessert", "snack"]

    private static func split(_ text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [text] }
        let ns = text as NSString
        var pieces: [String] = []
        var start = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            pieces.append(ns.substring(with: NSRange(location: start, length: match.range.location - start)))
            start = match.range.location + match.range.length
        }
        pieces.append(ns.substring(from: start))
        return pieces
    }

    /// Drops "and", "I had" and similar from the start of a piece, and capitalizes it.
    static func cleanFillers(_ piece: String) -> String {
        var text = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            let lower = text.lowercased()
            for word in ["and", "with"] + fillers where lower.hasPrefix(word + " ") || lower == word {
                text = String(text.dropFirst(word.count)).trimmingCharacters(in: .whitespaces)
                changed = true
                break
            }
        }
        guard let first = text.first else { return "" }
        return first.uppercased() + text.dropFirst()
    }

    // MARK: Numbers

    private static let units: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]
    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90,
    ]

    /// "thirty minute walk" → "30 minute walk", "five grams" → "5 g", "half an hour" kept.
    static func normalizeNumbers(in text: String) -> String {
        let words = text.components(separatedBy: " ")
        var output: [String] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            let key = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let ten = tens[key] {
                var value = ten
                if index + 1 < words.count,
                   let unit = units[words[index + 1].lowercased().trimmingCharacters(in: .punctuationCharacters)], unit < 10 {
                    value += unit
                    index += 1
                }
                output.append(String(value) + trailingPunctuation(words[index]))
            } else if let unit = units[key] {
                output.append(String(unit) + trailingPunctuation(word))
            } else if key.contains("-"), let tensPart = tens[String(key.split(separator: "-")[0])],
                      let unitPart = units[String(key.split(separator: "-").last ?? "")] {
                output.append(String(tensPart + unitPart) + trailingPunctuation(word))
            } else {
                output.append(word)
            }
            index += 1
        }
        return output.joined(separator: " ")
            .replacingOccurrences(of: #"(\d+) grams?\b"#, with: "$1 g", options: .regularExpression)
            .replacingOccurrences(of: #"(\d+) milligrams?\b"#, with: "$1 mg", options: .regularExpression)
            .replacingOccurrences(of: #"(\d+) ounces?\b"#, with: "$1 oz", options: .regularExpression)
    }

    private static func trailingPunctuation(_ word: String) -> String {
        String(word.reversed().prefix { $0.isPunctuation }.reversed())
    }
}
