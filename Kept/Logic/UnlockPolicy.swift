import Foundation

/// What's free and what the one-time Fuelprint Unlock adds. Logging, the checklist, history,
/// import and export are free forever, so nobody's own data is ever behind a purchase. Asking
/// AI is free for a few questions over short periods; the Unlock makes it unlimited, opens
/// every period, Trends and Apple Health.
enum UnlockPolicy {
    static let productID = "com.messagegabrielhere.kept.unlock"

    /// Questions sent to an AI, or answered on the iPhone, before the Unlock is needed.
    static let freeQuestions = 5

    /// Fuelprint was a paid app until 2.3. Build numbers are the release timestamp
    /// (yyyyMMddHHmm, set by scripts/release.sh), and every build sold for a price is older
    /// than this, so anyone whose first download was one of them already paid.
    static let firstFreeBuild = 202_610_090_000

    static func paidForApp(originalAppVersion: String) -> Bool {
        let trimmed = originalAppVersion.trimmingCharacters(in: .whitespaces)
        if let build = Int(trimmed) { return build < firstFreeBuild }
        // "1.0" style values (early builds) are older than any timestamp.
        if let number = Double(trimmed) { return number < Double(firstFreeBuild) }
        return false
    }

    static func isFree(_ range: AIExportRange) -> Bool {
        switch range {
        case .today, .yesterday, .week: return true
        case .twoWeeks, .month, .quarter, .year, .all: return false
        }
    }

    static func questionsLeft(used: Int) -> Int {
        max(0, freeQuestions - used)
    }

    static func canAsk(unlocked: Bool, used: Int) -> Bool {
        unlocked || used < freeQuestions
    }
}
