import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

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
                        AboutMeEditor()
                    } label: {
                        Label("About Me for AI", systemImage: "person.text.rectangle")
                    }
                }

                Section {
                    ShareLink(
                        item: CSVDocument(text: CSVExport.csv(log: store.log, habits: store.habits)),
                        preview: SharePreview("Kept log", image: Image(systemName: "tablecells"))
                    ) {
                        Label("Export Spreadsheet (CSV)", systemImage: "tablecells")
                    }
                    ShareLink(
                        item: BackupDocument(data: backupData),
                        preview: SharePreview("Kept backup", image: Image(systemName: "externaldrive"))
                    ) {
                        Label("Export Complete Backup (JSON)", systemImage: "externaldrive")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Every entry and checklist tick. Keep it anywhere you like.")
                }

                Section {
                    Label {
                        Text("Everything stays on this phone. Kept has no account, no analytics and no network access.")
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
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
