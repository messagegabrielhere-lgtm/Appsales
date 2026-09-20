import UIKit

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Streak lengths worth a little extra celebration.
    static let milestones: Set<Int> = [7, 30, 100, 365]

    /// Plays a success haptic when a check-in lands on a milestone streak, a plain tap otherwise.
    static func checkIn(newStreak: Int) {
        if milestones.contains(newStreak) {
            success()
        } else {
            tap()
        }
    }
}
