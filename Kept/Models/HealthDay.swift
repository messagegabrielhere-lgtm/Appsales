import Foundation

/// One day of Apple Health data, as far as the AI needs it. Read on the device when the user
/// includes Apple Health in a prompt; never stored by Fuelprint.
struct HealthDay: Equatable {
    var steps: Int?
    var exerciseMinutes: Int?
    var activeCalories: Int?
    /// Sleep that ended on this day's morning, in hours.
    var sleepHours: Double?
    var weightKilograms: Double?
    var restingHeartRate: Int?
    /// "Running 32 min", in the order they happened.
    var workouts: [String] = []

    var isEmpty: Bool {
        steps == nil && exerciseMinutes == nil && activeCalories == nil && sleepHours == nil
            && weightKilograms == nil && restingHeartRate == nil && workouts.isEmpty
    }

    /// "Apple Health: slept 7.2 h; 8,432 steps; 42 min exercise; …" or nil when empty.
    func line(usesPounds: Bool) -> String? {
        guard !isEmpty else { return nil }
        var parts: [String] = []
        if let sleepHours { parts.append(String(format: "slept %.1f h", sleepHours)) }
        if let steps { parts.append("\(Self.grouped(steps)) steps") }
        if let exerciseMinutes { parts.append("\(exerciseMinutes) min exercise") }
        if let activeCalories { parts.append("\(Self.grouped(activeCalories)) active kcal") }
        if !workouts.isEmpty { parts.append("workouts: " + workouts.joined(separator: ", ")) }
        if let weightKilograms {
            let kilograms = String(format: "%.1f kg", weightKilograms)
            parts.append(usesPounds
                ? String(format: "weight %.1f lb (%@)", weightKilograms * 2.20462, kilograms)
                : "weight \(kilograms)")
        }
        if let restingHeartRate { parts.append("resting heart rate \(restingHeartRate) bpm") }
        return "Apple Health: " + parts.joined(separator: "; ")
    }

    private static func grouped(_ value: Int) -> String {
        let digits = String(value)
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(character)
        }
        return result
    }
}
