import Foundation

enum Relationship: String, Codable, CaseIterable, Identifiable {
    case me, spouse, child, parent, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .me: return "Me"
        case .spouse: return "Spouse / partner"
        case .child: return "Child"
        case .parent: return "Parent"
        case .other: return "Other family"
        }
    }
}

/// One household member. Everything here stays on the device.
/// The app deliberately has no field for a Social Security number; letters
/// that need one print a blank for the user to fill in by hand.
struct Person: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var relationship: Relationship = .me
    var firstName: String = ""
    var middleName: String = ""
    var lastName: String = ""
    var otherNames: [String] = []
    var birthDate: Date? = nil
    var emails: [String] = []
    var phones: [String] = []
    var usernames: [String] = []
    var city: String = ""
    var state: String = ""
    var pastLocations: [String] = []

    var shortName: String {
        [firstName, lastName].map(\.trimmed).filter { !$0.isEmpty }.joined(separator: " ")
    }

    var fullName: String {
        [firstName, middleName, lastName].map(\.trimmed).filter { !$0.isEmpty }.joined(separator: " ")
    }

    var displayName: String { shortName.isEmpty ? relationship.label : shortName }

    /// Every name variant worth searching for, without duplicates.
    var allNames: [String] { ([shortName, fullName] + otherNames).cleaned }

    var location: String {
        [city, state].map(\.trimmed).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    func age(on date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let birthDate else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: date).year
    }

    var isMinor: Bool {
        if let age = age() { return age < 18 }
        return relationship == .child
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Array where Element == String {
    /// Trimmed, non-empty, de-duplicated (case-insensitive), original order kept.
    var cleaned: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in self {
            let value = raw.trimmed
            guard !value.isEmpty else { continue }
            if seen.insert(value.lowercased()).inserted { out.append(value) }
        }
        return out
    }

    /// Splits user-entered text on commas and new lines.
    static func fromList(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",\n")).cleaned
    }

    var listText: String { joined(separator: "\n") }
}
