import Foundation

/// User preferences, stored beside the habits and log files. Every key is optional on read so
/// a settings file from any version, or none at all, loads.
struct KeptSettings: Codable, Equatable {
    /// Optional context the user writes once, such as age, goals, or diet. Stays on the
    /// device and is only included when the user copies or shares an AI prompt.
    var aboutMe: String = ""
    var includeAboutMe: Bool = true
    var glassMilliliters: Int = 250
    var hasOnboarded: Bool = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case aboutMe, includeAboutMe, glassMilliliters, hasOnboarded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aboutMe = try container.decodeIfPresent(String.self, forKey: .aboutMe) ?? ""
        includeAboutMe = try container.decodeIfPresent(Bool.self, forKey: .includeAboutMe) ?? true
        let glass = try container.decodeIfPresent(Int.self, forKey: .glassMilliliters) ?? 250
        glassMilliliters = min(2000, max(50, glass))
        hasOnboarded = try container.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
    }
}
