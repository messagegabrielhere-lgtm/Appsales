#if canImport(FoundationModels)
import FoundationModels
#endif
import SwiftUI
import UIKit

/// Apple's on-device language model (Apple Intelligence, iOS 26 and later). Answers come from
/// the iPhone itself: nothing leaves the device, nothing is paid for per question, and the
/// App Store privacy label stays "Data Not Collected". It is smaller than the big cloud
/// assistants, so it handles short periods and Send to AI remains for deep analysis.
enum OnDeviceAI {
    enum Status: Equatable {
        case available
        /// The iPhone supports it but Apple Intelligence is off.
        case notEnabled
        /// Apple Intelligence is on and the model is still downloading.
        case preparing
        /// Older iPhone or iOS.
        case unsupported
    }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .appleIntelligenceNotEnabled: return .notEnabled
                case .modelNotReady: return .preparing
                default: return .unsupported
                }
            }
        }
        #endif
        return .unsupported
    }

    /// The on-device model reads about 4,000 tokens, so prompts over this are refused up front
    /// with a clear message instead of failing partway.
    static let maxPromptCharacters = 9_000

    static let instructions = """
    You are a careful assistant inside a food, drink, supplement and activity diary app. Use only \
    the log and details you are given. Be concise: short headings and bullet points. Give ranges \
    rather than false precision and say what you assumed. You are not a doctor: never diagnose, \
    and never tell the user to start, stop or change a medication or supplement. Suggest checking \
    with a doctor or pharmacist where it matters.
    """
}

/// The row in Send to AI that answers on the iPhone, or explains how to turn it on.
struct OnDeviceAIRow: View {
    let prompt: String
    let title: String

    var body: some View {
        switch OnDeviceAI.status {
        case .available:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                NavigationLink {
                    OnDeviceAnswerView(prompt: prompt, title: title)
                } label: {
                    label(subtitle: "Private: the answer is made on this iPhone")
                }
            }
            #else
            EmptyView()
            #endif
        case .notEnabled:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                label(subtitle: "Turn on Apple Intelligence in Settings to use it")
            }
        case .preparing:
            label(subtitle: "Apple Intelligence is still downloading. Try again soon.")
                .opacity(0.6)
        case .unsupported:
            EmptyView()
        }
    }

    private func label(subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "iphone")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Answer on This iPhone")
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct OnDeviceAnswerView: View {
    let prompt: String
    let title: String

    @State private var answer = ""
    @State private var failure: String?
    @State private var working = false
    @State private var copied = false
    @State private var savedDays = 0
    @EnvironmentObject private var store: HabitStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Made on this iPhone by Apple Intelligence. AI answers can be wrong and are not medical advice.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if working {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Thinking on this iPhone…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                if let failure {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                if !answer.isEmpty {
                    Text(formatted(answer))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let estimates = EstimateParser.parse(answer)
                    if !estimates.isEmpty {
                        Button {
                            savedDays = store.saveEstimates(estimates)
                            Haptics.success()
                        } label: {
                            Label(savedDays > 0 ? "Saved to Trends" : "Save \(estimates.count) days to Trends",
                                  systemImage: savedDays > 0 ? "checkmark" : "chart.xyaxis.line")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(savedDays > 0)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !answer.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = answer
                        Haptics.success()
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(item: answer)
                }
            }
        }
        .task { await run() }
    }

    private func run() async {
        guard answer.isEmpty, !working else { return }
        guard prompt.count <= OnDeviceAI.maxPromptCharacters else {
            failure = "This period is too long for the on-device model. Choose 7 days or less, or send it to another assistant."
            return
        }
        working = true
        defer { working = false }
        do {
            let session = LanguageModelSession(instructions: OnDeviceAI.instructions)
            let response = try await session.respond(to: prompt)
            answer = response.content
            Haptics.success()
        } catch {
            failure = "Apple Intelligence couldn't answer this one. Try a shorter period, or send it to another assistant."
        }
    }

    /// Renders the model's light Markdown (bold, lists) while keeping its line breaks.
    private func formatted(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
#endif
