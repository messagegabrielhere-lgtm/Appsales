import Foundation

/// What the user tells the AI about themselves once, so every prompt starts with the context a
/// good answer needs. All free text: people describe height, weight and history in their own
/// units and words, and the AI reads them fine. Stays on the device; only included when the
/// user sends a prompt.
struct UserProfile: Codable, Equatable {
    var age: String = ""
    var sex: String = ""
    var height: String = ""
    var weight: String = ""
    var activityLevel: String = ""
    var goals: String = ""
    var diet: String = ""
    var medicalHistory: String = ""
    var medications: String = ""
    var allergies: String = ""

    init() {}

    /// Label and value for every field, in the order the prompt and editor show them.
    var fields: [(label: String, value: String)] {
        [
            ("Age", age),
            ("Sex", sex),
            ("Height", height),
            ("Weight", weight),
            ("Activity level", activityLevel),
            ("Goals", goals),
            ("Diet and preferences", diet),
            ("Medical history", medicalHistory),
            ("Medications", medications),
            ("Allergies and intolerances", allergies),
        ]
    }

    /// "Age: 39" lines for the fields that are filled in.
    var promptLines: [String] {
        fields.compactMap { field in
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: "; ")
            return value.isEmpty ? nil : "\(field.label): \(value)"
        }
    }

    var isEmpty: Bool { promptLines.isEmpty }

    /// "39 years · Male · 6 ft 4 in · 280 lb" for compact display.
    var summary: String {
        var parts: [String] = []
        let years = age.trimmingCharacters(in: .whitespacesAndNewlines)
        if !years.isEmpty {
            parts.append(Int(years) != nil ? "\(years) years" : years)
        }
        for value in [sex, height, weight] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { parts.append(trimmed) }
        }
        return parts.joined(separator: " · ")
    }

    private enum CodingKeys: String, CodingKey {
        case age, sex, height, weight, activityLevel, goals, diet, medicalHistory, medications, allergies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) throws -> String {
            try container.decodeIfPresent(String.self, forKey: key) ?? ""
        }
        age = try text(.age)
        sex = try text(.sex)
        height = try text(.height)
        weight = try text(.weight)
        activityLevel = try text(.activityLevel)
        goals = try text(.goals)
        diet = try text(.diet)
        medicalHistory = try text(.medicalHistory)
        medications = try text(.medications)
        allergies = try text(.allergies)
    }
}

/// User preferences, stored beside the habits and log files. Every key is optional on read so
/// a settings file from any version, or none at all, loads.
struct KeptSettings: Codable, Equatable {
    var profile = UserProfile()
    /// Anything else the user wants every prompt to know. Called About Me before 2.1.
    var aboutMe: String = ""
    /// Include the profile and notes in prompts.
    var includeAboutMe: Bool = true
    var glassMilliliters: Int = 250
    var hasOnboarded: Bool = false
    /// The user has read that AI answers are not medical advice. Asked once, before the first
    /// prompt leaves the app.
    var acceptedAIDisclaimer: Bool = false
    /// Include Apple Health (steps, workouts, sleep, weight, resting heart rate) in prompts.
    var includeHealth: Bool = false

    init() {}

    var hasAboutMe: Bool {
        !profile.isEmpty || !aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case profile, aboutMe, includeAboutMe, glassMilliliters, hasOnboarded, acceptedAIDisclaimer, includeHealth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = (try? container.decodeIfPresent(UserProfile.self, forKey: .profile)) ?? UserProfile()
        aboutMe = try container.decodeIfPresent(String.self, forKey: .aboutMe) ?? ""
        includeAboutMe = try container.decodeIfPresent(Bool.self, forKey: .includeAboutMe) ?? true
        let glass = try container.decodeIfPresent(Int.self, forKey: .glassMilliliters) ?? 250
        glassMilliliters = min(2000, max(50, glass))
        hasOnboarded = try container.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        acceptedAIDisclaimer = try container.decodeIfPresent(Bool.self, forKey: .acceptedAIDisclaimer) ?? false
        includeHealth = try container.decodeIfPresent(Bool.self, forKey: .includeHealth) ?? false
    }
}
