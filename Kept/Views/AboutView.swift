import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var exportText: String {
        guard let data = try? JSONEncoder.keptPretty.encode(store.habits) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image("AppIconPreview")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("Kept")
                            .font(.title2.bold())
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Privacy") {
                    Label {
                        Text("Your habits never leave this device. Kept has no account, no analytics, and no network access.")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(Color.accentColor)
                    }
                    .font(.subheadline)
                }

                Section {
                    ShareLink(
                        item: exportText,
                        preview: SharePreview("Kept habits", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Export data as JSON", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("A plain-text copy of every habit and check-in. Keep it anywhere you like.")
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension JSONEncoder {
    static var keptPretty: JSONEncoder {
        let encoder = JSONEncoder.kept
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

#Preview {
    AboutView()
        .environmentObject(HabitStore.preview())
}
