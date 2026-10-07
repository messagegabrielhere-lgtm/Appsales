import Foundation

/// Brings a Fuelprint backup into the current data without losing anything on either side:
/// a new phone, a restored phone, or two devices combined. Entries already present (same ID,
/// or same time and text) are skipped; checklist items are matched by ID, then by name, and
/// their ticks are combined.
enum BackupMerge {
    struct Result: Equatable {
        var habits: [Habit]
        var log: [LogEntry]
        var addedEntries = 0
        var addedHabits = 0
        var addedTicks = 0

        var changed: Bool { addedEntries + addedHabits + addedTicks > 0 }
    }

    static func merge(habits: [Habit], log: [LogEntry], backupHabits: [Habit], backupLog: [LogEntry]) -> Result {
        var result = Result(habits: habits, log: log)

        for incoming in backupHabits {
            let name = incoming.name.trimmingCharacters(in: .whitespaces).lowercased()
            if let index = result.habits.firstIndex(where: { $0.id == incoming.id })
                ?? result.habits.firstIndex(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == name }) {
                let before = result.habits[index].completions.count
                result.habits[index].completions.formUnion(incoming.completions)
                result.addedTicks += result.habits[index].completions.count - before
            } else {
                result.habits.append(incoming)
                result.addedHabits += 1
            }
        }

        var ids = Set(result.log.map(\.id))
        var signatures = Set(result.log.map(signature))
        for entry in backupLog {
            guard !ids.contains(entry.id), !signatures.contains(signature(entry)) else { continue }
            result.log.append(entry)
            ids.insert(entry.id)
            signatures.insert(signature(entry))
            result.addedEntries += 1
        }
        result.log.sort { $0.date < $1.date }
        return result
    }

    private static func signature(_ entry: LogEntry) -> String {
        "\(entry.date.timeIntervalSince1970)|\(entry.kind.rawValue)|\(entry.text.lowercased())"
    }
}
