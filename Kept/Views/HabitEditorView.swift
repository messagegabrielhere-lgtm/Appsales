import SwiftUI

struct HabitEditorView: View {
    enum Mode {
        case create
        case edit(Habit)
    }

    let mode: Mode
    let onSave: (Habit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var colorName: String
    @FocusState private var nameFocused: Bool

    init(mode: Mode, onSave: @escaping (Habit) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _emoji = State(initialValue: "✅")
            _colorName = State(initialValue: "teal")
        case .edit(let habit):
            _name = State(initialValue: habit.name)
            _emoji = State(initialValue: habit.emoji)
            _colorName = State(initialValue: habit.colorName)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var color: Color { HabitPalette.color(colorName) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Drink water", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !trimmedName.isEmpty { save() }
                        }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(HabitPalette.emojis, id: \.self) { candidate in
                            let selected = candidate == emoji
                            Text(candidate)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(
                                    selected ? color.opacity(0.2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selected ? color : Color.clear, lineWidth: 2)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { emoji = candidate }
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(HabitPalette.names, id: \.self) { candidate in
                            let selected = candidate == colorName
                            Circle()
                                .fill(HabitPalette.color(candidate))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: selected ? 3 : 0)
                                )
                                .contentShape(Circle())
                                .onTapGesture { colorName = candidate }
                                .accessibilityLabel(candidate)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !isEditing { nameFocused = true }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        var habit: Habit
        switch mode {
        case .create:
            habit = Habit(name: trimmedName, emoji: emoji, colorName: colorName)
        case .edit(let existing):
            habit = existing
            habit.name = trimmedName
            habit.emoji = emoji
            habit.colorName = colorName
        }
        onSave(habit)
        dismiss()
    }
}

#Preview {
    HabitEditorView(mode: .create) { _ in }
}
