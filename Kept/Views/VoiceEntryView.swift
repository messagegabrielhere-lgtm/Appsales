import AVFoundation
import Speech
import SwiftUI

/// Live speech-to-text that only runs on the iPhone. Fuelprint never sends audio or text
/// anywhere, so recognition is on-device or not at all.
@MainActor
final class SpeechTranscriber: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var problem: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func start() async {
        problem = nil
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speechAllowed else {
            problem = "Allow Speech Recognition for \(Brand.name) in Settings to log by voice."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            problem = "Allow the microphone for \(Brand.name) in Settings to log by voice."
            return
        }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            problem = "This iPhone can't recognize speech on the device for your language. Use the microphone on the keyboard in Type or Paste a List instead."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            request.addsPunctuation = true
            self.request = request

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let done = error != nil || (result?.isFinal ?? false)
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if done { self.finish() }
                }
            }
        } catch {
            problem = "The microphone couldn't start. Try again."
            finish()
        }
    }

    func stop() {
        request?.endAudio()
        finish()
    }

    private func finish() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Talk through your day; the transcript is split into entries and opened in the list editor
/// to review before anything is added.
struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechTranscriber()
    @State private var finishing = false

    let onFinish: (String) -> Void

    private var lines: [String] {
        SpeechSplitter.list(from: speech.transcript).components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ScrollView {
                    Group {
                        if speech.transcript.isEmpty {
                            Text("Say it the way you'd tell a friend:\n\n\"Two eggs and toast with black coffee, then five grams of creatine, a thirty minute walk at lunch, and a glass of red wine with dinner.\"\n\nStart with \"Yesterday\" to log yesterday.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(speech.transcript)
                                .font(.title3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                if let problem = speech.problem {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }

                Button {
                    Haptics.tap()
                    if speech.isRecording {
                        speech.stop()
                    } else {
                        Task { await speech.start() }
                    }
                } label: {
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(speech.isRecording ? Color.red.gradient : Color.accentColor.gradient, in: Circle())
                        .symbolEffect(.pulse, isActive: speech.isRecording)
                }
                .accessibilityLabel(speech.isRecording ? "Stop listening" : "Start listening")

                Text(speech.isRecording ? "Listening on this iPhone…" : "Your voice never leaves this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("Speak Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speech.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lines.isEmpty ? "Review" : "Review \(lines.count)") {
                        review()
                    }
                    .fontWeight(.semibold)
                    .disabled(speech.transcript.isEmpty || finishing)
                }
            }
            .task { await speech.start() }
        }
    }

    /// Stops listening, waits a moment for the final words, then hands over the list.
    private func review() {
        finishing = true
        speech.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onFinish(SpeechSplitter.list(from: speech.transcript))
            dismiss()
        }
    }
}
