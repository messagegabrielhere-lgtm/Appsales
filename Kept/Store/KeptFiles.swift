import Foundation

extension Notification.Name {
    /// Posted after a widget button or Siri writes to the data files from inside the app's
    /// process, so an open `HabitStore` can reload instead of overwriting the change.
    static let keptDataChanged = Notification.Name("KeptDataChanged")
}

/// Shared JSON file handling for every data file. Plain functions, no actor, safe from the
/// widget extension and App Intents.
enum JSONFile {
    /// Reads an array, skipping any element that fails to decode instead of discarding the
    /// whole file. A file that is not an array at all is moved aside, never overwritten, so a
    /// later save cannot destroy data that might still be recoverable.
    static func loadArray<Element: Decodable>(_ type: Element.Type, from url: URL) -> [Element] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder.kept.decode([Lossy<Element>].self, from: data).compactMap(\.value)
        } catch {
            setAside(url)
            return []
        }
    }

    static func loadValue<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder.kept.decode(Value.self, from: data)
        } catch {
            setAside(url)
            return nil
        }
    }

    @discardableResult
    static func save<Value: Encodable>(_ value: Value, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.kept.encode(value)
            // `completeFileProtection` would make the file unreadable while the device is
            // locked, which breaks lock-screen widgets and reminders. Until first unlock is
            // the strongest protection that still lets those work.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// Renames an unreadable file to `name.unreadable-<timestamp>.json` beside the original.
    static func setAside(_ url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "json" : url.pathExtension
        let target = url.deletingLastPathComponent().appendingPathComponent("\(base).unreadable-\(stamp).\(ext)")
        try? FileManager.default.moveItem(at: url, to: target)
    }
}

/// Decodes one array element, turning a failure into nil so its neighbours survive.
private struct Lossy<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

/// The food, drink, activity and feeling log. Lives beside `habits.json`.
enum LogFileStore {
    static let fileName = "log.json"

    static var fileURL: URL {
        HabitFileStore.fileURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    static func load(from url: URL = fileURL) -> [LogEntry] {
        JSONFile.loadArray(LogEntry.self, from: url).sorted { $0.date < $1.date }
    }

    @discardableResult
    static func save(_ entries: [LogEntry], to url: URL = fileURL) -> Bool {
        JSONFile.save(entries.sorted { $0.date < $1.date }, to: url)
    }

    /// Adds one entry and writes the file. Used by Siri and widget buttons.
    /// - Returns: the whole log as it now stands, oldest first.
    @discardableResult
    static func append(_ entry: LogEntry, to url: URL = fileURL) -> [LogEntry] {
        var entries = load(from: url)
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        save(entries, to: url)
        return entries
    }
}

enum SettingsFileStore {
    static let fileName = "settings.json"

    static var fileURL: URL {
        HabitFileStore.fileURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    static func load(from url: URL = fileURL) -> KeptSettings {
        JSONFile.loadValue(KeptSettings.self, from: url) ?? KeptSettings()
    }

    @discardableResult
    static func save(_ settings: KeptSettings, to url: URL = fileURL) -> Bool {
        JSONFile.save(settings, to: url)
    }
}

/// Everything, in one file, for the "Complete backup" export.
struct KeptBackup: Codable {
    var format: Int = 2
    var exportedAt: Date
    var habits: [Habit]
    var log: [LogEntry]
    var settings: KeptSettings
}
