import PhotosUI
import SwiftUI
import UIKit
import Vision

/// Take or choose a photo of a nutrition or supplement label. Text is read on the iPhone by
/// Apple's Vision framework, turned into one line, and handed to the list editor to review.
struct LabelScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (String) -> Void

    @State private var showingCamera = false
    @State private var photo: PhotosPickerItem?
    @State private var working = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 32)
                Text("Photograph the Nutrition Facts or Supplement Facts panel, flat and in good light.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take a Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                }

                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Choose a Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)

                if working {
                    ProgressView("Reading the label on this iPhone…")
                }
                if let problem {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }
                Spacer()
                Text("The photo is read on this iPhone and isn't saved or sent anywhere.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle("Scan a Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    showingCamera = false
                    if let image { read(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        read(image)
                    } else {
                        problem = "That photo couldn't be opened."
                    }
                    // So choosing the same photo again after a failed read tries again.
                    photo = nil
                }
            }
        }
    }

    private func read(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            problem = "That photo couldn't be read."
            return
        }
        working = true
        problem = nil
        let request = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async {
                working = false
                if let line = LabelParser.line(from: lines) {
                    onResult(line)
                    dismiss()
                } else {
                    problem = "No text found. Try again closer, flat and in good light."
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// The system camera, returning one photo.
private struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
