import SwiftUI

/// First launch: explain the idea in one line, then offer common supplements so the checklist
/// is useful from the first minute.
struct OnboardingView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int> = []

    /// No doses are prefilled on purpose. Suggesting amounts would read as dosing advice.
    static let suggestions: [(name: String, emoji: String, color: String)] = [
        ("Vitamin D", "☀️", "yellow"),
        ("Magnesium", "😴", "indigo"),
        ("Omega-3", "🐟", "blue"),
        ("Creatine", "💪", "purple"),
        ("Multivitamin", "💊", "orange"),
        ("Probiotic", "🌿", "green"),
        ("Vitamin C", "🍋", "yellow"),
        ("Electrolytes", "💧", "teal"),
        ("Protein shake", "🥛", "pink"),
        ("Walk 20 minutes", "🚶", "mint"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Text("Log your day. Ask your AI.")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Log food, drinks, activity and how you feel in your own words. \(Brand.name) turns it into a ready-made prompt for any AI assistant.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What do you take each day?")
                            .font(.headline)
                        Text("Pick any to add to your daily checklist. Set doses, days and reminders later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Array(Self.suggestions.enumerated()), id: \.offset) { index, item in
                                chip(index: index, name: item.name, emoji: item.emoji, colorName: item.color)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: finish) {
                    Text(selected.isEmpty ? "Continue" : "Add \(selected.count) and Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding(20)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        markOnboarded()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear(perform: markOnboarded)
    }

    private func chip(index: Int, name: String, emoji: String, colorName: String) -> some View {
        let isSelected = selected.contains(index)
        let color = HabitPalette.color(colorName)
        return Button {
            Haptics.tap()
            if isSelected {
                selected.remove(index)
            } else {
                selected.insert(index)
            }
        } label: {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.title3)
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? color : Color.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func finish() {
        for index in selected.sorted() {
            let item = Self.suggestions[index]
            store.add(Habit(name: item.name, emoji: item.emoji, colorName: item.color))
        }
        markOnboarded()
        dismiss()
    }

    private func markOnboarded() {
        guard !store.settings.hasOnboarded else { return }
        var settings = store.settings
        settings.hasOnboarded = true
        store.updateSettings(settings)
    }
}
