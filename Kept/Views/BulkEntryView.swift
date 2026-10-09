import SwiftUI
import UIKit

/// Type or paste a list, one thing per line, the way people already keep a food diary in their
/// notes app. Date lines split it into days, so a whole month can come in at once. Every line's
/// type is guessed and shown before anything is added, and one tap changes a wrong guess.
struct BulkEntryView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    /// Where lines go when the list has no dates.
    let day: DayKey
    /// Text to start with, from an imported file.
    var initialText: String = ""
    /// Shown above the list, such as what an import contained.
    var note: String? = nil

    @State private var text = ""
    @State private var result = BulkEntryParser.Result()
    @State private var overrides: [String: LogKind] = [:]
    @State private var tickChecklist = true
    @State private var addPreambleToProfile = false
    @State private var prepared = false
    @FocusState private var editorFocused: Bool

    private static var isDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    private func parse(_ text: String) -> BulkEntryParser.Result {
        BulkEntryParser.parse(
            text,
            defaultDay: day,
            habits: store.habits,
            glassMilliliters: store.settings.glassMilliliters
        )
    }

    /// The parsed days with the user's corrections applied and lines already logged removed.
    private func resolve(_ result: BulkEntryParser.Result) -> (days: [BulkEntryParser.Day], skipped: Int) {
        let corrected = result.days.map { parsed in
            BulkEntryParser.Day(day: parsed.day, items: parsed.items.map { item in
                guard let kind = overrides[overrideKey(item, on: parsed.day)], kind != item.kind else { return item }
                return BulkEntryParser.with(item, kind: kind, glassMilliliters: store.settings.glassMilliliters)
            })
        }
        return BulkEntryParser.removingDuplicates(of: corrected, in: store.log)
    }

    private func overrideKey(_ item: BulkEntryParser.Item, on day: DayKey) -> String {
        "\(day)|\(item.text.lowercased())"
    }

    var body: some View {
        let parsed = result
        let resolved = resolve(parsed)
        let noteText = note
        let count = resolved.days.reduce(0) { $0 + $1.items.count }
        let matchesChecklist = resolved.days.contains { $0.items.contains { $0.habitID != nil } }

        NavigationStack {
            Form {
                if let noteText {
                    Section {
                        Label(noteText, systemImage: "square.and.arrow.down")
                            .font(.subheadline)
                    }
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(Self.placeholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .focused($editorFocused)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                    }
                    PasteButton(payloadType: String.self) { strings in
                        guard let clip = strings.first, !clip.isEmpty else { return }
                        Task { @MainActor in
                            Haptics.tap()
                            text = text.isEmpty ? clip : text + "\n" + clip
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                } header: {
                    Text("One thing per line")
                } footer: {
                    Text("Type it like a note: \"2 eggs and toast\", \"5g creatine\", \"30 min walk\". Add a date line such as 10/06/26 to log several days at once. Pasting the same list again only adds new lines.")
                }

                if text.isEmpty && initialText.isEmpty {
                    Section {
                        NavigationLink {
                            ImportView()
                        } label: {
                            Label("Import a file from another app", systemImage: "square.and.arrow.down")
                        }
                    } footer: {
                        Text("Spreadsheet (CSV) exports from other trackers, text files, or a \(Brand.name) backup.")
                    }
                }

                if !parsed.preamble.isEmpty {
                    Section {
                        ForEach(Array(parsed.preamble.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("Add to my profile notes", isOn: $addPreambleToProfile)
                    } header: {
                        Text("Before the first date")
                    } footer: {
                        Text("These lines aren't logged. Details like age, height and weight help AI answers; you can keep them in your profile.")
                    }
                }

                ForEach(resolved.days) { parsedDay in
                    Section {
                        ForEach(parsedDay.items) { item in
                            BulkItemRow(item: item, habitName: item.habitID.flatMap { store.habit(id: $0)?.name }) { kind in
                                overrides[overrideKey(item, on: parsedDay.day)] = kind
                            }
                        }
                    } header: {
                        HStack {
                            Text(DayTitle.title(for: parsedDay.day))
                            Spacer()
                            Text(parsedDay.items.count == 1 ? "1 item" : "\(parsedDay.items.count) items")
                        }
                    }
                }

                if matchesChecklist {
                    Section {
                        Toggle("Check off matching supplements", isOn: $tickChecklist)
                    } footer: {
                        Text("Lines that name something on your checklist tick it for that day.")
                    }
                }

                if resolved.skipped > 0 || parsed.futureLines > 0 {
                    Section {
                        if resolved.skipped > 0 {
                            Label(
                                resolved.skipped == 1 ? "1 line is already logged and will be skipped." : "\(resolved.skipped) lines are already logged and will be skipped.",
                                systemImage: "checkmark.circle"
                            )
                        }
                        if parsed.futureLines > 0 {
                            Label(
                                parsed.futureLines == 1 ? "1 line is dated in the future and will be skipped." : "\(parsed.futureLines) lines are dated in the future and will be skipped.",
                                systemImage: "calendar.badge.exclamationmark"
                            )
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Type or Paste a List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(count == 0 ? "Add" : "Add \(count)") {
                        // Read the text as it is now: the preview catches up a moment after
                        // typing, and a quick tap must not add a list missing its last lines.
                        let current = parse(text)
                        add(resolve(current).days, preamble: current.preamble)
                    }
                    .fontWeight(.semibold)
                    .disabled(count == 0 && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
            }
            .onAppear(perform: prepare)
            .task(id: text) {
                // Re-read the list a moment after typing stops, so a month-long paste stays smooth.
                if !result.days.isEmpty || !result.preamble.isEmpty {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if Task.isCancelled { return }
                }
                result = parse(text)
            }
        }
    }

    private static let placeholder = """
    Oatmeal with berries
    Black coffee with cream
    5g creatine
    Chicken salad
    Sparkling water
    30 min walk

    Or paste several days:
    10/06/26 -
    Steak, rice and broccoli
    """

    private static let demoText = """
    Yesterday
    Greek yogurt with blueberries
    Black coffee with oat milk
    5g creatine
    Turkey and avocado wrap
    45 min strength training
    Salmon, rice and green beans
    Glass of pinot noir

    Today
    Two eggs on sourdough
    Cold brew
    1.5 mile walk
    """

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        if !initialText.isEmpty {
            text = initialText
            return
        }
        if Self.isDemo {
            text = Self.demoText
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            editorFocused = true
        }
    }

    private func add(_ days: [BulkEntryParser.Day], preamble: [String]) {
        withAnimation(.snappy) {
            store.addList(days, tickChecklist: tickChecklist)
        }
        if addPreambleToProfile && !preamble.isEmpty {
            var settings = store.settings
            let joined = preamble.joined(separator: "\n")
            settings.aboutMe = settings.aboutMe.isEmpty ? joined : settings.aboutMe + "\n" + joined
            store.updateSettings(settings)
        }
        Haptics.success()
        dismiss()
    }
}

/// One parsed line: its guessed type, which is a menu to change it, and what it records.
private struct BulkItemRow: View {
    let item: BulkEntryParser.Item
    let habitName: String?
    let onChange: (LogKind) -> Void

    private var detail: String? {
        var parts: [String] = []
        if let ml = item.milliliters { parts.append(VolumeFormat.string(milliliters: ml)) }
        if let minutes = item.minutes { parts.append("\(minutes) min") }
        if let habitName { parts.append("ticks \(habitName)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(LogKind.allCases) { kind in
                    Button {
                        Haptics.tap()
                        onChange(kind)
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: item.kind.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            HabitPalette.color(item.kind.colorName).gradient,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Type: \(item.kind.title). Double-tap to change.")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                Text(detail.map { "\(item.kind.title) · \($0)" } ?? item.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }
}
