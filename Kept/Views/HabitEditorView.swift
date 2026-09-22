import SwiftUI
import UIKit

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
    @State private var weekdays: Set<Int>
    @State private var reminderOn: Bool
    @State private var reminderTime: Date
    @State private var showingDeniedAlert = false
    @FocusState private var nameFocused: Bool

    private let calendar = Calendar.current

    init(mode: Mode, onSave: @escaping (Habit) -> Void) {
        self.mode = mode
        self.onSave = onSave
        let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _emoji = State(initialValue: "✅")
            _colorName = State(initialValue: "teal")
            _weekdays = State(initialValue: Habit.everyDay)
            _reminderOn = State(initialValue: false)
            _reminderTime = State(initialValue: defaultTime)
        case .edit(let habit):
            _name = State(initialValue: habit.name)
            _emoji = State(initialValue: habit.emoji)
            _colorName = State(initialValue: habit.colorName)
            _weekdays = State(initialValue: habit.schedule)
            _reminderOn = State(initialValue: habit.reminderMinutes != nil)
            let minutes = habit.reminderMinutes ?? 9 * 60
            let time = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? defaultTime
            _reminderTime = State(initialValue: time)
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

    /// Weekday numbers in the user's locale order, e.g. Monday first in most of Europe.
    private var orderedWeekdays: [Int] {
        (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
    }

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

                Section {
                    HStack(spacing: 6) {
                        ForEach(orderedWeekdays, id: \.self) { weekday in
                            let selected = weekdays.contains(weekday)
                            Button {
                                toggleWeekday(weekday)
                            } label: {
                                Text(calendar.veryShortStandaloneWeekdaySymbols[weekday - 1])
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(selected ? color : color.opacity(0.12), in: Circle())
                                    .foregroundStyle(selected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(calendar.standaloneWeekdaySymbols[weekday - 1])
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    HStack {
                        Button("Every day") { weekdays = Habit.everyDay }
                        Spacer()
                        Button("Weekdays") { weekdays = Habit.weekdays }
                    }
                    .font(.subheadline)
                } header: {
                    Text("Repeat")
                } footer: {
                    Text("Days you skip here are rest days. They never break a streak.")
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Reminders only fire on scheduled days you haven't checked in yet.")
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
            .onChange(of: reminderOn) { _, isOn in
                guard isOn else { return }
                Task {
                    let allowed = await ReminderScheduler.requestAuthorizationIfNeeded()
                    if !allowed {
                        reminderOn = false
                        showingDeniedAlert = true
                    }
                }
            }
            .alert("Notifications are off", isPresented: $showingDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Allow notifications for Kept in Settings to get reminders.")
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

    private func toggleWeekday(_ weekday: Int) {
        if weekdays.contains(weekday) {
            // Keep at least one day.
            if weekdays.count > 1 { weekdays.remove(weekday) }
        } else {
            weekdays.insert(weekday)
        }
    }

    private var reminderMinutes: Int? {
        guard reminderOn else { return nil }
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        return (components.hour ?? 9) * 60 + (components.minute ?? 0)
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
        habit.scheduledWeekdays = weekdays
        habit.reminderMinutes = reminderMinutes
        onSave(habit)
        dismiss()
    }
}

#Preview {
    HabitEditorView(mode: .create) { _ in }
}
