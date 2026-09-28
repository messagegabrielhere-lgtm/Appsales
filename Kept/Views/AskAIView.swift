import SwiftUI
import UIKit

/// Turns a period of the log into a prompt for any AI assistant. Kept never contacts an AI
/// itself: the user copies or shares the text to the assistant of their choice.
struct AskAIView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var range: AIExportRange = .week
    @State private var template: AIPromptTemplate = .patterns
    @State private var question = ""
    @State private var copied = false
    @State private var showingPreview = false

    private var days: [DayKey] {
        range.days(endingAt: DayKey.today())
    }

    private var exportText: String {
        AIExportBuilder.build(AIExportBuilder.Input(
            template: template,
            customQuestion: question,
            days: days,
            habits: store.habits,
            log: store.log,
            aboutMe: store.settings.includeAboutMe ? store.settings.aboutMe : nil
        ))
    }

    private var entryCount: Int {
        let included = Set(days)
        return store.log.filter { included.contains($0.day()) }.count
    }

    private var aboutMeSummary: String {
        let text = store.settings.aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Not set" : text
    }

    private var includeAboutMe: Binding<Bool> {
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
                Picker("Period", selection: $range) {
                    ForEach(AIExportRange.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Period")
            } footer: {
                Text(entryCount == 1 ? "1 entry in this period." : "\(entryCount) entries in this period.")
            }

            Section("What would you like to know?") {
                ForEach(AIPromptTemplate.allCases) { item in
                    Button {
                        withAnimation(.snappy) { template = item }
                    } label: {
                        TemplateRow(template: item, isSelected: item == template)
                    }
                    .buttonStyle(.plain)
                }
            }

            if template == .custom {
                Section("Your question") {
                    TextField("e.g. Why do I crash after lunch?", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                }
            }

            Section {
                Toggle("Include About Me", isOn: includeAboutMe)
                NavigationLink {
                    AboutMeEditor()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("About Me")
                        Text(aboutMeSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            } header: {
                Text("Context")
            } footer: {
                Text("Age, goals, diet, training. Better context gets better answers. It stays on this phone.")
            }

            Section {
                Button {
                    copy(text)
                } label: {
                    Label(copied ? "Copied" : "Copy for AI", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

                ShareLink(item: text) {
                    Label("Share to an App", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Paste into ChatGPT, Claude, Gemini or any AI assistant. Kept never sends your data anywhere; you choose where it goes.")
            }

            Section {
                DisclosureGroup(isExpanded: $showingPreview) {
                    Text(text)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text("Preview")
                        Spacer()
                        Text("\(text.count.formatted()) characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Kept doesn't give medical advice, and AI answers can be wrong. Talk to a doctor or pharmacist before changing supplements, medication or diet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Ask AI")
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        Haptics.success()
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { copied = false }
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

/// Free-text context about the user, included at the top of every prompt when enabled.
struct AboutMeEditor: View {
    @EnvironmentObject private var store: HabitStore
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 200)
            } footer: {
                Text("For example: 38, 64 kg, vegetarian. Training for a half marathon. Want steadier energy in the afternoon and better sleep.\n\nThis stays on this phone and is only included when you copy or share for AI.")
            }
        }
        .navigationTitle("About Me")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = store.settings.aboutMe
        }
        .onDisappear(perform: save)
    }

    private func save() {
        var settings = store.settings
        settings.aboutMe = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings != store.settings {
            store.updateSettings(settings)
        }
    }
}
