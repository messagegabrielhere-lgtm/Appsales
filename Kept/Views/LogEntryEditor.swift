import SwiftUI

enum LogEditorRequest: Identifiable {
    case create(LogKind, DayKey)
    case edit(LogEntry)

    var id: String {
        switch self {
        case .create(let kind, let day): return "new-\(kind.rawValue)-\(day)"
        case .edit(let entry): return entry.id.uuidString
        }
    }
}

/// Adds or edits one entry. Built for speed: the text field is focused on open, recent
/// entries of the same kind are one tap away, and drinks start at the user's glass size.
struct LogEntryEditor: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    let request: LogEditorRequest

    @State private var kind: LogKind
    @State private var text: String
    @State private var amount: String
    @State private var milliliters: Int?
    @State private var minutes: Int?
    @State private var rating: Int?
    @State private var date: Date
    @State private var prepared = false
    @FocusState private var textFocused: Bool

    private static var isDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    init(request: LogEditorRequest) {
        self.request = request
        switch request {
        case .create(let kind, let day):
            _kind = State(initialValue: kind)
            _text = State(initialValue: "")
            _amount = State(initialValue: "")
            _milliliters = State(initialValue: nil)
            _minutes = State(initialValue: nil)
            _rating = State(initialValue: nil)
            _date = State(initialValue: LogInsights.defaultDate(for: day))
        case .edit(let entry):
            _kind = State(initialValue: entry.kind)
            _text = State(initialValue: entry.text)
            _amount = State(initialValue: entry.amount ?? "")
            _milliliters = State(initialValue: entry.milliliters)
            _minutes = State(initialValue: entry.minutes)
            _rating = State(initialValue: entry.rating)
            _date = State(initialValue: entry.date)
        }
    }

    private var editing: LogEntry? {
        if case .edit(let entry) = request { return entry }
        return nil
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedText.isEmpty || (kind == .feeling && rating != nil)
    }

    private var color: Color { HabitPalette.color(kind.colorName) }

    private var suggestions: [String] {
        store.recents(for: kind).filter { $0.caseInsensitiveCompare(trimmedText) != .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(LogKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if kind == .feeling {
                    Section("How do you feel?") {
                        ratingPicker
                    }
                }

                Section {
                    TextField(kind.placeholder, text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($textFocused)
                    if !suggestions.isEmpty {
                        suggestionChips
                    }
                } header: {
                    Text(kind.question)
                } footer: {
                    if kind == .food && editing == nil {
                        Text("Write it the way you'd say it. Your AI estimates the nutrition later.")
                    }
                }

                detailSection

                Section {
                    DatePicker("Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }

                if let editing {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            store.deleteEntry(editing)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Log \(kind.title)" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: prepare)
            .onChange(of: kind) { _, newKind in
                if newKind == .drink && milliliters == nil {
                    milliliters = store.settings.glassMilliliters
                }
            }
        }
    }

    // MARK: Sections

    private var ratingPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { value in
                let selected = rating == value
                Button {
                    Haptics.tap()
                    rating = value
                } label: {
                    VStack(spacing: 4) {
                        Text(LogEntry.face(for: value))
                            .font(.title2)
                        Text(LogEntry.label(for: value))
                            .font(.caption2)
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? color.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected ? color : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LogEntry.label(for: value))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(suggestions.prefix(8)), id: \.self) { item in
                    Button {
                        Haptics.tap()
                        text = item
                    } label: {
                        Text(item)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(color.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var detailSection: some View {
        switch kind {
        case .food:
            Section("Portion") {
                TextField("Optional, e.g. 1 bowl or 2 slices", text: $amount)
            }
        case .drink:
            Section("Amount") {
                chips(
                    options: VolumeFormat.drinkOptions(),
                    selected: milliliters,
                    label: { VolumeFormat.string(milliliters: $0) }
                ) { milliliters = $0 }
                Stepper(value: millilitersBinding, in: 0...3000, step: VolumeFormat.step()) {
                    Text(milliliters.map { VolumeFormat.string(milliliters: $0) } ?? "No amount")
                }
            }
        case .activity:
            Section("Duration") {
                chips(
                    options: [10, 20, 30, 45, 60, 90],
                    selected: minutes,
                    label: { "\($0) min" }
                ) { minutes = $0 }
                Stepper(value: minutesBinding, in: 0...600, step: 5) {
                    Text(minutes.map { "\($0) min" } ?? "No duration")
                }
            }
        case .feeling:
            EmptyView()
        }
    }

    private func chips(
        options: [Int],
        selected: Int?,
        label: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selected == option
                    Button {
                        Haptics.tap()
                        onSelect(option)
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? color : color.opacity(0.14), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var millilitersBinding: Binding<Int> {
        Binding(
            get: { milliliters ?? 0 },
            set: { milliliters = $0 == 0 ? nil : $0 }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { minutes ?? 0 },
            set: { minutes = $0 == 0 ? nil : $0 }
        )
    }

    // MARK: Actions

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        guard editing == nil else { return }
        if kind == .drink && milliliters == nil {
            milliliters = store.settings.glassMilliliters
        }
        if Self.isDemo {
            // Screenshots: show a filled-in entry with its suggestions, keyboard down.
            text = store.recents(for: kind).first ?? ""
            return
        }
        if kind != .feeling {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                textFocused = true
            }
        }
    }

    private func save() {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = LogEntry(
            id: editing?.id ?? UUID(),
            kind: kind,
            date: date,
            text: trimmedText,
            amount: kind == .food && !trimmedAmount.isEmpty ? trimmedAmount : nil,
            milliliters: kind == .drink ? milliliters : nil,
            minutes: kind == .activity ? minutes : nil,
            rating: kind == .feeling ? rating : nil
        )
        withAnimation(.snappy) {
            if editing != nil {
                store.updateEntry(entry)
            } else {
                store.addEntry(entry)
            }
        }
        Haptics.tap()
        dismiss()
    }
}
