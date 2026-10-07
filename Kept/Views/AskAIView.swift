import SwiftUI
import UIKit

/// Turns a period of the log into a prompt for any AI assistant, in three plain steps: pick a
/// period, pick a question, send. The app never contacts an AI itself: it copies the prompt and
/// opens the assistant the user picks.
struct AskAIView: View {
    @EnvironmentObject private var store: HabitStore
    @Binding var range: AIExportRange
    @State private var template: AIPromptTemplate = .patterns
    @State private var question = ""
    @State private var showingPreview = false
    @State private var showingSend = false
    @State private var showingDisclaimer = false

    private var days: [DayKey] {
        range.days(endingAt: DayKey.today(), firstDay: firstDay)
    }

    /// The earliest day with an entry or a checklist tick, where "All time" starts.
    private var firstDay: DayKey? {
        let firstEntry = store.log.min(by: { $0.date < $1.date })?.day()
        let firstTick = store.habits.flatMap(\.completions).min()
        return [firstEntry, firstTick].compactMap { $0 }.min()
    }

    private var exportText: String {
        let include = store.settings.includeAboutMe
        return AIExportBuilder.build(AIExportBuilder.Input(
            template: template,
            customQuestion: question,
            days: days,
            habits: store.habits,
            log: store.log,
            aboutMe: include ? store.settings.aboutMe : nil,
            profile: include ? store.settings.profile : nil
        ))
    }

    private var entryCount: Int {
        let included = Set(days)
        return store.log.filter { included.contains($0.day()) }.count
    }

    private var includeProfile: Binding<Bool> {
        Binding(
            get: { store.settings.includeAboutMe },
            set: { newValue in
                var settings = store.settings
                settings.includeAboutMe = newValue
                store.updateSettings(settings)
            }
        )
    }

    var body: some View {
        let text = exportText

        Form {
            Section {
                Button {
                    showingDisclaimer = true
                } label: {
                    Label {
                        Text("AI answers can be wrong and are not medical advice. Check with a doctor before changing anything.")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                RangeChips(selection: $range)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                StepHeader(number: 1, title: "Choose a period")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entryCount == 1 ? "1 entry" : "\(entryCount.formatted()) entries") · about \(text.count.formatted()) characters")
                    if text.count > Self.longPrompt {
                        Text("That's a long prompt. If your assistant says it's too long, use Share as File in the next step and attach it instead.")
                    }
                }
            }

            ForEach(AIPromptGroup.allCases) { group in
                Section {
                    ForEach(group.templates) { item in
                        Button {
                            Haptics.tap()
                            withAnimation(.snappy) { template = item }
                        } label: {
                            TemplateRow(template: item, isSelected: item == template)
                        }
                        .buttonStyle(.plain)
                    }
                    if group == .ask && template == .custom {
                        TextField("e.g. Why do I crash after lunch?", text: $question, axis: .vertical)
                            .lineLimit(2...5)
                    }
                } header: {
                    if group == AIPromptGroup.allCases.first {
                        VStack(alignment: .leading, spacing: 6) {
                            StepHeader(number: 2, title: "Choose a question")
                            Text(group.title)
                        }
                    } else {
                        Text(group.title)
                    }
                }
            }

            Section {
                NavigationLink {
                    ProfileEditor()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My profile")
                        Text(profileSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Toggle("Include my profile", isOn: includeProfile)
            } header: {
                StepHeader(number: 3, title: "Add your details")
            } footer: {
                Text("Age, height, weight, goals, diet, medical history and medications make answers far more useful. It stays on this phone and is only included when you send.")
            }

            Section {
                DisclosureGroup(isExpanded: $showingPreview) {
                    Text(text)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text("Preview the prompt")
                        Spacer()
                        Text("\(text.count.formatted()) characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("\(Brand.name) never sends your data anywhere. You choose where the prompt goes.")
            }
        }
        .navigationTitle("Ask AI")
        .safeAreaInset(edge: .bottom) {
            SendBar(template: template) {
                Haptics.tap()
                if store.settings.acceptedAIDisclaimer {
                    showingSend = true
                } else {
                    showingDisclaimer = true
                }
            }
        }
        .sheet(isPresented: $showingSend) {
            SendToAISheet(prompt: text, title: template.title)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingDisclaimer) {
            AIDisclaimerView(alreadyAccepted: store.settings.acceptedAIDisclaimer) {
                var settings = store.settings
                let firstTime = !settings.acceptedAIDisclaimer
                settings.acceptedAIDisclaimer = true
                store.updateSettings(settings)
                showingDisclaimer = false
                if firstTime {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingSend = true }
                }
            }
        }
        .onAppear(perform: openSendFromLaunchArguments)
    }

    /// Above this, some assistants' message boxes struggle and a file attachment works better.
    static let longPrompt = 60_000

    private var profileSummary: String {
        let summary = store.settings.profile.summary
        if !summary.isEmpty { return summary }
        if store.settings.hasAboutMe { return "Added" }
        return "Add age, weight, goals, medical history…"
    }

    /// `-screen send` (used by scripts/screenshots.sh) opens the send sheet.
    private func openSendFromLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screen"), index + 1 < args.count, args[index + 1] == "send" else { return }
        template = .nutrition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingSend = true }
    }
}

/// Every period, from today to all time, in one scrolling row.
private struct RangeChips: View {
    @Binding var selection: AIExportRange

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIExportRange.allCases) { item in
                    let selected = item == selection
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { selection = item }
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? Color.accentColor : Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

private struct StepHeader: View {
    let number: Int
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title)")
    }
}

/// Always on screen, so the way forward is never below the fold.
private struct SendBar: View {
    let template: AIPromptTemplate
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onSend) {
                Label("Send to AI", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Choose ChatGPT, Claude, Gemini or another assistant")
            Text(template.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }
}

/// Step 4: where the prompt goes. Every option copies it first, so it can always be pasted.
struct SendToAISheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let prompt: String
    let title: String
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AIAssistant.allCases) { assistant in
                        let destination = assistant.destination(for: prompt)
                        Button {
                            UIPasteboard.general.string = prompt
                            Haptics.success()
                            openURL(destination.url)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: assistant.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(assistant.name)
                                        .foregroundStyle(.primary)
                                    Text(destination.prefilled ? "Opens with your prompt filled in" : "Opens, then paste your prompt")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Open in")
                } footer: {
                    Text("Your prompt is copied every time. If the assistant opens empty, tap its message box and paste.")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = prompt
                        Haptics.success()
                        withAnimation { copied = true }
                    } label: {
                        Label(copied ? "Copied" : "Copy Prompt", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(item: prompt) {
                        Label("Share to Another App", systemImage: "square.and.arrow.up")
                    }
                    ShareLink(
                        item: PromptDocument(text: prompt),
                        preview: SharePreview("\(Brand.name) prompt", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Share as File", systemImage: "doc.text")
                    }
                } footer: {
                    Text("For long periods, Share as File and attach it in your assistant's app. \(Brand.name) is not affiliated with these companies. Each service's own privacy policy applies to what you send it.")
                }
            }
            .navigationTitle("Send to AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TemplateRow: View {
    let template: AIPromptTemplate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                    .foregroundStyle(.primary)
                Text(template.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Shown before the first prompt leaves the app, and any time from Ask AI or Settings.
struct AIDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    let alreadyAccepted: Bool
    let onAccept: () -> Void

    private struct Point: Hashable {
        let symbol: String
        let text: String

        init(_ symbol: String, _ text: String) {
            self.symbol = symbol
            self.text = text
        }
    }

    private let points: [Point] = [
        Point("sparkles", "AI answers come from the service you choose, not from \(Brand.name) or a doctor. They can be wrong, incomplete or out of date."),
        Point("cross.case", "Nothing here is medical advice, diagnosis or treatment."),
        Point("stethoscope", "Talk to a doctor or pharmacist before changing your diet, supplements or medication, especially if you have a health condition, are pregnant, or take medication."),
        Point("phone.arrow.up.right", "In an emergency, call your local emergency number."),
        Point("lock.shield", "\(Brand.name) never sends your data anywhere. What you send to an AI service is covered by that service's privacy policy."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("AI is a helper, not a doctor")
                        .font(.title2.weight(.bold))
                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: point.symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26)
                            Text(point.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAccept()
                } label: {
                    Text(alreadyAccepted ? "OK" : "I Understand")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
            .toolbar {
                if alreadyAccepted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!alreadyAccepted)
        }
    }
}

/// What every prompt can say about the user: body, lifestyle and health details, plus free
/// notes. All optional. Stays on the device.
struct ProfileEditor: View {
    @EnvironmentObject private var store: HabitStore
    @State private var profile = UserProfile()
    @State private var notes = ""
    @State private var loaded = false

    private var usesImperial: Bool {
        Locale.current.measurementSystem == .us
    }

    private var sexOptions: [String] {
        let options = ["Male", "Female", "Other"]
        return profile.sex.isEmpty || options.contains(profile.sex) ? options : options + [profile.sex]
    }

    var body: some View {
        Form {
            Section {
                row("Age", text: $profile.age, prompt: "e.g. 39", keyboard: .numberPad)
                Picker("Sex", selection: $profile.sex) {
                    Text("Not set").tag("")
                    ForEach(sexOptions, id: \.self) { Text($0).tag($0) }
                }
                row("Height", text: $profile.height, prompt: usesImperial ? "e.g. 6 ft 4 in" : "e.g. 180 cm")
                row("Weight", text: $profile.weight, prompt: usesImperial ? "e.g. 180 lb" : "e.g. 80 kg")
            } header: {
                Text("Body")
            } footer: {
                Text("Used for protein, calorie and weight estimates.")
            }

            Section("Lifestyle") {
                field("Activity level", text: $profile.activityLevel, prompt: "e.g. Desk job, walk daily, lift twice a week")
                field("Goals", text: $profile.goals, prompt: "e.g. Lose 20 lb, more energy, better sleep")
                field("Diet and preferences", text: $profile.diet, prompt: "e.g. High protein, no seed oils, low sugar")
            }

            Section {
                field("Medical history", text: $profile.medicalHistory, prompt: "e.g. High blood pressure, knee surgery 2019")
                field("Medications", text: $profile.medications, prompt: "e.g. Lisinopril 10 mg daily")
                field("Allergies and intolerances", text: $profile.allergies, prompt: "e.g. Lactose, shellfish")
            } header: {
                Text("Health")
            } footer: {
                Text("Helps the AI point out things worth checking with your doctor. Leave anything blank.")
            }

            Section {
                TextField("Anything else every answer should know", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
            } header: {
                Text("Other notes")
            } footer: {
                Text("Stays on this phone. Only included when you send a prompt, and you can turn it off in Ask AI.")
            }
        }
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            profile = store.settings.profile
            notes = store.settings.aboutMe
        }
        .onDisappear(perform: save)
    }

    private func row(_ label: String, text: Binding<String>, prompt: String, keyboard: UIKeyboardType = .default) -> some View {
        LabeledContent(label) {
            TextField(label, text: text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(label, text: text, prompt: Text(prompt), axis: .vertical)
                .lineLimit(1...4)
        }
        .padding(.vertical, 2)
    }

    private func save() {
        var settings = store.settings
        settings.profile = profile
        settings.aboutMe = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings != store.settings {
            store.updateSettings(settings)
        }
    }
}
