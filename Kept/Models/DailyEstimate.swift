import Foundation

/// One day's nutrition as estimated by the user's AI assistant, pasted back into Fuelprint so
/// it can chart trends without a food database. Every number is the AI's estimate.
struct DailyEstimate: Codable, Equatable, Identifiable {
    var day: DayKey
    var calories: Int?
    var proteinGrams: Int?
    var carbsGrams: Int?
    var fatGrams: Int?
    var fiberGrams: Int?
    var savedAt: Date

    var id: DayKey { day }
}

extension DayKey {
    /// "2026-10-06".
    init?(isoString: String) {
        let parts = isoString.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (2000...2100).contains(parts[0]), (1...12).contains(parts[1]), (1...31).contains(parts[2]) else {
            return nil
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
}
