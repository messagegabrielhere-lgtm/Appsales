import Foundation

/// The app and its widget extension share one data file through this App Group.
enum AppGroup {
    static let identifier = "group.com.messagegabrielhere.kept"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
