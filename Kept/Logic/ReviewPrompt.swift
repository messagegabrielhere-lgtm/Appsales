import Foundation

/// When to ask for an App Store rating: only after a good moment (a finished checklist, a
/// pasted list), only once the app has proven useful (five days with entries), at most once
/// per version and once per 90 days. iOS adds its own limit of three prompts a year.
enum ReviewPrompt {
    static let minimumDaysLogged = 5
    static let minimumInterval: TimeInterval = 90 * 24 * 60 * 60

    static func shouldAsk(
        daysLogged: Int,
        lastAskedAt: Date?,
        lastAskedVersion: String?,
        currentVersion: String,
        now: Date = Date()
    ) -> Bool {
        guard daysLogged >= minimumDaysLogged else { return false }
        guard lastAskedVersion != currentVersion else { return false }
        if let lastAskedAt, now.timeIntervalSince(lastAskedAt) < minimumInterval { return false }
        return true
    }
}
