import SwiftUI

/// First run. Offers a handful of proven starter habits so the first check-in is seconds away.
struct EmptyStateView: View {
    let onAdd: () -> Void
    let onPick: (Habit) -> Void

    @State private var selected: Set<Int> = []

    static let suggestions: [(name: String, emoji: String, color: String)] = [
        ("Drink water", "💧", "blue"),
        ("Walk 20 minutes", "🚶", "green"),
        ("Read 10 pages", "📚", "orange"),
        ("Meditate", "🧘", "purple"),
        ("Stretch", "🤸", "pink"),
        ("No phone in bed", "📵", "indigo"),
        ("Sleep by 11", "😴", "teal"),
        ("Tidy for 5 minutes", "🧹", "yellow"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                    Text("Pick a few to start")
                        .font(.title2.bold())
                    Text("Small, daily, and easy to keep. You can change anything later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(Self.suggestions.enumerated()), id: \.offset) { index, item in
                        let isSelected = selected.contains(index)
                        Button {
                            Haptics.tap()
                            if isSelected { selected.remove(index) } else { selected.insert(index) }
                        } label: {
                            HStack(spacing: 10) {
                                Text(item.emoji).font(.title3)
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? HabitPalette.color(item.color) : Color.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                HabitPalette.color(item.color).opacity(isSelected ? 0.18 : 0.08),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? HabitPalette.color(item.color) : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        for index in selected.sorted() {
                            let item = Self.suggestions[index]
                            onPick(Habit(name: item.name, emoji: item.emoji, colorName: item.color))
                        }
                        selected.removeAll()
                    } label: {
                        Text(selected.isEmpty ? "Select habits above" : "Add \(selected.count) habit\(selected.count == 1 ? "" : "s")")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)

                    Button("Or create your own", action: onAdd)
                        .font(.subheadline)
                }
            }
            .padding(20)
        }
    }
}

#Preview {
    EmptyStateView(onAdd: {}, onPick: { _ in })
}
