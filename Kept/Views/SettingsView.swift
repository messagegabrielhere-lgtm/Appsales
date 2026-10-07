import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingDisclaimer = false

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var glassOptions: [Int] {
        Array(Set(VolumeFormat.glassOptions() + [store.settings.glassMilliliters])).sorted()
    }

    private var glassBinding: Binding<Int> {
        Binding(
            get: { store.settings.glassMilliliters },
            set: { newValue in
                var settings = store.settings
                settings.glassMilliliters = newValue
                store.updateSettings(settings)
            }
        )
    }

    private var backupData: Data {
        let backup = KeptBackup(exportedAt: Date(), habits: store.habits, log: store.log, settings: store.settings)
        let encoder = JSONEncoder.kept
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(backup)) ?? Data()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Glass size", selection: glassBinding) {
                        ForEach(glassOptions, id: \.self) { option in
                            Text(VolumeFormat.string(milliliters: option)).tag(option)
                        }
                    }
                } header: {
                    Text("Water")
                } footer: {
                    Text("One tap on the water button adds a glass this size.")
                }

                Section {
                    NavigationLink {
                        ChecklistManagerView()
                    } label: {
                        Label("Supplements & Routines", systemImage: "checklist")
                    }
                    NavigationLink {
                        ProfileEditor()
                    } label: {
                        Label("My Profile for AI", systemImage: "person.text.rectangle")
                    }
                    Button {
                        showingDisclaimer = true
                    } label: {
                        Label("AI Is Not Medical Advice", systemImage: "exclamationmark.shield")
                    }
                }

                Section {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Label("Import from Notes or Other Apps", systemImage: "square.and.arrow.down")
                    }
                    ShareLink(
                        item: CSVDocument(text: CSVExport.csv(log: store.log, habits: store.habits)),
                        preview: SharePreview("\(Brand.name) log", image: Image(systemName: "tablecells"))
                    ) {
                        Label("Export Spreadsheet (CSV)", systemImage: "tablecells")
                    }
                    ShareLink(
                        item: BackupDocument(data: backupData),
                        preview: SharePreview("\(Brand.name) backup", image: Image(systemName: "externaldrive"))
                    ) {
                        Label("Export Complete Backup (JSON)", systemImage: "externaldrive")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Bring in a history from Apple Notes, another tracker's CSV export, or a backup. Export every entry and checklist tick to keep anywhere you like.")
                }

                Section {
                    Label {
                        Text("Everything stays on this phone. \(Brand.name) has no account, no analytics and no network access.")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(Color.accentColor)
                    }
                    .font(.subheadline)
                } header: {
                    Text("Privacy")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("\(Brand.name) is made by \(Brand.company).")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDisclaimer) {
                AIDisclaimerView(alreadyAccepted: true) {
                    showingDisclaimer = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Reorder, delete, and add checklist items.
struct ChecklistManagerView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var adding = false

    var body: some View {
        List {
            ForEach(store.habits) { habit in
                NavigationLink {
                    HabitDetailView(habitID: habit.id)
                } label: {
                    HStack(spacing: 12) {
                        Text(habit.emoji)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name)
                            if let dose = habit.dose, !dose.isEmpty {
                                Text(dose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
            .onMove { source, destination in
                store.move(from: source, to: destination)
            }
        }
        .overlay {
            if store.habits.isEmpty {
                ContentUnavailableView(
                    "Nothing on your checklist",
                    systemImage: "pills",
                    description: Text("Tap + to add a supplement or daily routine.")
                )
            }
        }
        .navigationTitle("Supplements & Routines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !store.habits.isEmpty {
                    EditButton()
                }
                Button {
                    adding = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $adding) {
            HabitEditorView(mode: .create) { habit in
                store.add(habit)
            }
        }
    }
}
