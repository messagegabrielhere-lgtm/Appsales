import StoreKit
import SwiftUI

enum DayTitle {
    static func title(for day: DayKey, today: DayKey = DayKey.today()) -> String {
        if day == today { return "Today" }
        if day == today.adding(days: -1) { return "Yesterday" }
        let date = day.date()
        if day.year == today.year {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

/// Switches to the Ask AI tab with a period chosen. Set by RootView.
struct AskAIAction {
    var perform: (AIExportRange) -> Void = { _ in }

    func callAsFunction(_ range: AIExportRange) {
        perform(range)
    }
}

private struct AskAIActionKey: EnvironmentKey {
    static let defaultValue = AskAIAction()
}

extension EnvironmentValues {
    var askAI: AskAIAction {
        get { self[AskAIActionKey.self] }
        set { self[AskAIActionKey.self] = newValue }
    }
}

/// Everything for one day: one-tap logging, water, the supplement and routine checklist, and
/// the timeline of what was logged. Used by Today and by History.
struct DayView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.askAI) private var askAI
    @Environment(\.requestReview) private var requestReview
    let day: DayKey
    @Binding var pendingKind: LogKind?

    @State private var editorRequest: LogEditorRequest?
    @State private var addingHabit = false
    @State private var addingList = false
    @State private var speaking = false
    @State private var scanning = false
    @State private var listSeed: ListSeed?
    /// Text handed over by the voice or scan sheet, shown in the list editor once that sheet
    /// has closed.
    @State private var pendingSeed: ListSeed?

    struct ListSeed: Identifiable {
        let id = UUID()
        let text: String
        let note: String
        var day: DayKey? = nil
    }

    /// The day to repeat: yesterday on Today, or this day when looking back.
    private var repeatSource: DayKey {
        day == DayKey.today() ? day.adding(days: -1) : day
    }

    /// Food, drinks and supplements from `repeatSource`, as a list with their types.
    private var repeatText: String {
        store.entries(on: repeatSource)
            .filter { [.food, .drink, .supplement].contains($0.kind) }
            .map { entry in
                var details: [String] = []
                if let amount = entry.amount, !amount.isEmpty { details.append(amount) }
                if let ml = entry.milliliters { details.append("\(ml) ml") }
                let suffix = details.isEmpty || entry.text.contains("(") ? "" : " (" + details.joined(separator: ", ") + ")"
                return "\(entry.kind.title): \(entry.text)\(suffix)"
            }
            .joined(separator: "\n")
    }

    private var entries: [LogEntry] { store.entries(on: day) }
    private var scheduled: [Habit] { store.habits.filter { $0.isScheduled(on: day) } }
    private var doneCount: Int { scheduled.filter { $0.isCompleted(on: day) }.count }

    var body: some View {
        List {
            Section {
                QuickAddGrid { kind in
                    editorRequest = .create(kind, day)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

                LogMethodsRow(
                    repeatTitle: day == DayKey.today() ? "Repeat yesterday" : "Repeat today",
                    canRepeat: !repeatText.isEmpty
                ) { method in
                    Haptics.tap()
                    switch method {
                    case .list: addingList = true
                    case .speak: speaking = true
                    case .scan: scanning = true
                    case .repeatDay:
                        listSeed = ListSeed(
                            text: repeatText,
                            note: day == DayKey.today()
                                ? "Yesterday's food, drinks and supplements. Remove what you didn't have, then tap Add."
                                : "This day's food, drinks and supplements, logged again for today.",
                            day: DayKey.today()
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)

                WaterRow(
                    milliliters: store.waterMilliliters(on: day),
                    glass: store.settings.glassMilliliters
                ) {
                    withAnimation(.snappy) { store.addWater(on: day) }
                    Haptics.tap()
                }
            }

            Section {
                AskAICard(day: day) { range in
                    Haptics.tap()
                    askAI(range)
                }
                .listRowInsets(EdgeInsets())
            }

            Section {
                if store.habits.isEmpty {
                    Button {
                        addingHabit = true
                    } label: {
                        Label("Add your supplements and routines", systemImage: "plus.circle.fill")
                    }
                } else {
                    ForEach(store.habits) { habit in
                        NavigationLink(value: habit.id) {
                            HabitRow(habit: habit, today: day) {
                                toggle(habit)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Supplements & routines")
                    Spacer()
                    if !scheduled.isEmpty {
                        Text("\(doneCount) of \(scheduled.count)")
                            .contentTransition(.numericText())
                    }
                }
            }

            Section {
                if entries.isEmpty {
                    Text(day == DayKey.today() ? "Nothing logged yet today." : "Nothing logged this day.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            editorRequest = .edit(entry)
                        } label: {
                            LogEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteEntries)
                }
            } header: {
                Text("Log")
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editorRequest) { request in
            LogEntryEditor(request: request)
                .environmentObject(store)
        }
        .sheet(isPresented: $speaking, onDismiss: presentPendingSeed) {
            VoiceEntryView { text in
                pendingSeed = ListSeed(text: text, note: "From what you said. Check each line, then tap Add.")
            }
        }
        .sheet(isPresented: $scanning, onDismiss: presentPendingSeed) {
            LabelScanView { line in
                pendingSeed = ListSeed(text: line, note: "From the label. Edit the name or amounts if needed, then tap Add.")
            }
        }
        .sheet(item: $listSeed, onDismiss: askForReviewIfDue) { seed in
            BulkEntryView(day: seed.day ?? day, initialText: seed.text, note: seed.note)
                .environmentObject(store)
        }
        .sheet(isPresented: $addingList, onDismiss: askForReviewIfDue) {
            BulkEntryView(day: day)
                .environmentObject(store)
        }
        .sheet(isPresented: $addingHabit) {
            HabitEditorView(mode: .create) { habit in
                withAnimation(.snappy) { store.add(habit) }
            }
        }
        .onChange(of: pendingKind) { _, kind in
            consume(kind)
        }
        .onAppear {
            consume(pendingKind)
            openListFromLaunchArguments()
        }
    }

    private func consume(_ kind: LogKind?) {
        guard let kind else { return }
        editorRequest = .create(kind, DayKey.today())
        pendingKind = nil
    }

    private func presentPendingSeed() {
        if let seed = pendingSeed, !seed.text.isEmpty {
            listSeed = seed
        }
        pendingSeed = nil
    }

    /// `-screen paste` (used by scripts/screenshots.sh) opens the list editor on Today.
    private func openListFromLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard day == DayKey.today(), let index = args.firstIndex(of: "-screen"), index + 1 < args.count,
              args[index + 1] == "paste" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            addingList = true
        }
    }

    /// After a good moment, and only when `ReviewPrompt` says it's due.
    private func askForReviewIfDue() {
        guard !ProcessInfo.processInfo.arguments.contains("-demo") else { return }
        let defaults = UserDefaults.standard
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let daysLogged = Set(store.log.map { $0.day() }).count
        guard ReviewPrompt.shouldAsk(
            daysLogged: daysLogged,
            lastAskedAt: defaults.object(forKey: "reviewRequestedAt") as? Date,
            lastAskedVersion: defaults.string(forKey: "reviewRequestedVersion"),
            currentVersion: version
        ) else { return }
        defaults.set(Date(), forKey: "reviewRequestedAt")
        defaults.set(version, forKey: "reviewRequestedVersion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            requestReview()
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let current = entries
        withAnimation(.snappy) {
            for index in offsets {
                store.deleteEntry(current[index])
            }
        }
    }

    private func toggle(_ habit: Habit) {
        let wasDone = habit.isCompleted(on: day)
        withAnimation(.snappy) {
            store.toggle(habit, on: day)
        }
        guard !wasDone, let updated = store.habit(id: habit.id) else {
            Haptics.tap()
            return
        }
        let remaining = store.habits.filter { $0.isScheduled(on: day) && !$0.isCompleted(on: day) }
        if remaining.isEmpty {
            Haptics.success()
            askForReviewIfDue()
        } else {
            Haptics.checkIn(newStreak: StreakCalculator.currentStreak(
                updated.completions, today: day, schedule: updated.schedule))
        }
    }
}

enum LogMethod {
    case list, speak, scan, repeatDay
}

/// The other ways to log: a typed or pasted list, speech, a label photo, or repeating a day.
private struct LogMethodsRow: View {
    let repeatTitle: String
    let canRepeat: Bool
    let onSelect: (LogMethod) -> Void

    var body: some View {
        HStack(spacing: 8) {
            tile("Type a list", "list.bullet.clipboard", .list)
            tile("Speak", "mic.fill", .speak)
            tile("Scan label", "text.viewfinder", .scan)
            tile(repeatTitle, "arrow.clockwise", .repeatDay)
                .disabled(!canRepeat)
                .opacity(canRepeat ? 1 : 0.4)
        }
    }

    private func tile(_ title: String, _ symbol: String, _ method: LogMethod) -> some View {
        Button {
            onSelect(method)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The way into Ask AI from the day itself, so nobody has to discover the tab.
private struct AskAICard: View {
    let day: DayKey
    let onAsk: (AIExportRange) -> Void

    private var dayRange: AIExportRange? {
        let today = DayKey.today()
        if day == today { return .today }
        if day == today.adding(days: -1) { return .yesterday }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                Text("Ask AI about your log")
                    .font(.headline)
            }
            Text("Nutrition, protein, energy, sleep, gut health and more. Sends to ChatGPT, Claude, Gemini or any assistant.")
                .font(.subheadline)
                .opacity(0.9)
            HStack(spacing: 8) {
                if let dayRange {
                    pill(dayRange == .today ? "Today" : "Yesterday", range: dayRange)
                }
                pill("This week", range: .week)
                pill("30 days", range: .month)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.09), Color(red: 0.88, green: 0.11, blue: 0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .contentShape(Rectangle())
        .onTapGesture { onAsk(dayRange ?? .week) }
        .accessibilityElement(children: .contain)
    }

    private func pill(_ title: String, range: AIExportRange) -> some View {
        Button {
            onAsk(range)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.22), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask AI about \(title.lowercased())")
    }
}

/// Four large targets, one per kind of entry. Two taps from here to a logged meal.
private struct QuickAddGrid: View {
    let onSelect: (LogKind) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(LogKind.quickAdd) { kind in
                Button {
                    Haptics.tap()
                    onSelect(kind)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: kind.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                HabitPalette.color(kind.colorName).gradient,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        Text(kind.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(kind.title.lowercased())")
            }
        }
    }
}

/// Today's water with a one-tap glass.
private struct WaterRow: View {
    let milliliters: Int
    let glass: Int
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.headline)
                Text(milliliters == 0 ? "None yet" : VolumeFormat.string(milliliters: milliliters))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button(action: onAdd) {
                Text("+ \(VolumeFormat.string(milliliters: glass))")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.blue)
            .accessibilityLabel("Add a glass of water")
        }
        .padding(.vertical, 4)
    }
}
