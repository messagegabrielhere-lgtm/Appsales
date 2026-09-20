import SwiftUI

/// Fixed set of colors and icons a habit can use. Stored by name so the JSON stays readable
/// and survives future palette tweaks.
enum HabitPalette {
    static let names = ["red", "orange", "yellow", "green", "mint", "teal", "blue", "indigo", "purple", "pink"]

    static func color(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        default: return .teal
        }
    }

    static let emojis = [
        "✅", "💧", "🏃", "📚", "🧘", "💪",
        "🥗", "😴", "✍️", "🎸", "🧹", "💊",
        "🚭", "🌱", "🎯", "🧠", "🚶", "🦷",
        "☀️", "🙏", "🎨", "🧺", "💰", "📵",
    ]
}
