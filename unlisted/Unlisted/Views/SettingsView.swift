import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("No account. No tracking. No servers.", systemImage: "lock.iphone")
                    Text("Everything you enter is saved only on this device, in a file iOS encrypts when your phone is locked. The app has no Social Security number field. Searches and opt-out pages open in Safari; letters are sent from your own Mail app, by you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("Privacy policy") { PrivacyPolicyView() }
                } header: {
                    Text("Your privacy")
                }

                Section {
                    Toggle("Re-check reminders", isOn: Binding(
                        get: { store.data.remindersEnabled },
                        set: { newValue in
                            Task { @MainActor in
                                let allowed = newValue ? await Reminders.requestPermission() : false
                                store.update { $0.remindersEnabled = allowed }
                                if !allowed { Reminders.cancelAll(); store.update { $0.weeklyScanReminder = false } }
                            }
                        }))
                    Toggle("Weekly scan reminder (Mondays)", isOn: Binding(
                        get: { store.data.weeklyScanReminder },
                        set: { newValue in
                            store.update { $0.weeklyScanReminder = newValue }
                            Reminders.setWeeklyScan(newValue)
                        }))
                    .disabled(!store.data.remindersEnabled)
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Reminders never show names on your lock screen.")
                }

                Section {
                    ShareLink(item: String(decoding: store.encoded(), as: UTF8.self),
                              preview: SharePreview("Unlisted backup")) {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete all my data", systemImage: "trash")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("The export contains everything you entered. Keep it somewhere private.")
                }

                Section("About") {
                    Text("Unlisted is free and has no ads. It isn't legal advice. Companies change their opt-out pages often; if a link breaks, look for \"Opt out\" or \"Do Not Sell\" in the site's footer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Delete everything?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    Reminders.cancelAll()
                    store.deleteEverything()
                    dismiss()
                }
            } message: {
                Text("This removes your family's details, progress and findings from this device. It can't be undone.")
            }
        }
    }
}
