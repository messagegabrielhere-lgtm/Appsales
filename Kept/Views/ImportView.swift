import SwiftUI
import UniformTypeIdentifiers

/// Moves a history in from somewhere else: a notes app, another tracker's spreadsheet export,
/// a text file, or a Fuelprint backup from another phone. Everything except a backup goes
/// through the list editor, so the user sees each line, its type and any duplicates first.
struct ImportView: View {
    @EnvironmentObject private var store: HabitStore

    @State private var showingList = false
    @State private var listRequest: ListRequest?
    @State private var choosingFile = false
    @State private var pendingBackup: KeptBackup?
    @State private var message: ImportMessage?

    struct ListRequest: Identifiable {
        let id = UUID()
        var text: String
        var note: String?
    }

    struct ImportMessage: Identifiable {
        let id = UUID()
        var title: String
        var body: String
    }

    var body: some View {
        Form {
            Section {
                step(1, "Open the note in Notes (or any notes app).")
                step(2, "Tap and hold the text, choose Select All, then Copy.")
                step(3, "Come back and tap Paste a List, then Paste.")
                Button {
                    showingList = true
                } label: {
                    Label("Paste a List", systemImage: "list.bullet.clipboard")
                }
            } header: {
                Text("From Apple Notes")
            } footer: {
                Text("Put a date line like 10/06/26 or Oct 6 before each day to bring in many days at once.")
            }

            Section {
                Button {
                    choosingFile = true
                } label: {
                    Label("Choose a File", systemImage: "folder")
                }
            } header: {
                Text("From another app")
            } footer: {
                Text("Use a spreadsheet (CSV) export from a food, mood or fitness tracker, a text file, or a \(Brand.name) backup. Most apps have Export or Download Your Data in their settings; choose CSV if asked.")
            }

            Section {
                Label("Nothing is added until you review it and tap Add.", systemImage: "eye")
                Label("Lines you already logged are skipped.", systemImage: "checkmark.circle")
                Label("Imports stay on this phone.", systemImage: "lock.shield")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingList) {
            BulkEntryView(day: DayKey.today())
                .environmentObject(store)
        }
        .sheet(item: $listRequest) { request in
            BulkEntryView(day: DayKey.today(), initialText: request.text, note: request.note)
                .environmentObject(store)
        }
        .fileImporter(
            isPresented: $choosingFile,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { open(url) }
            case .failure:
                message = ImportMessage(title: "Couldn't Open the File", body: "Try saving it to Files first, then choose it again.")
            }
        }
        .confirmationDialog(
            "Restore this backup?",
            isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }),
            titleVisibility: .visible,
            presenting: pendingBackup
        ) { backup in
            Button("Add to My Data") { restore(backup) }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("\(backup.log.count.formatted()) entries and \(backup.habits.count) checklist items. Anything already here is kept, and nothing is added twice.")
        }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.body))
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }

    private func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            message = ImportMessage(title: "Couldn't Read the File", body: "It may still be downloading. Try again in a moment.")
            return
        }

        if let backup = try? JSONDecoder.kept.decode(KeptBackup.self, from: data) {
            pendingBackup = backup
            return
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = ImportMessage(title: "Nothing to Import", body: "That file is empty or isn't text.")
            return
        }

        let namedSpreadsheet = ["csv", "tsv"].contains(url.pathExtension.lowercased())
        let looksLikeSpreadsheet = namedSpreadsheet
            || text.prefix(while: { $0 != "\n" }).filter({ $0 == "," || $0 == ";" || $0 == "\t" }).count >= 2
        // A note whose first line is "Breakfast: eggs, toast, coffee" has commas too; if it
        // isn't a spreadsheet with dates, read it as a list instead of refusing it.
        let conversion = looksLikeSpreadsheet ? CSVImport.convert(text) : nil
        if looksLikeSpreadsheet && conversion == nil && !namedSpreadsheet {
            listRequest = ListRequest(text: text, note: "From \(url.lastPathComponent).")
        } else if looksLikeSpreadsheet {
            guard let conversion else {
                message = ImportMessage(
                    title: "No Dates Found",
                    body: "\(Brand.name) needs a column with dates, such as Date or Day. Check the export, or copy the rows you want and use Paste a List."
                )
                return
            }
            var note = "\(conversion.rows.formatted()) rows from \(url.lastPathComponent)."
            if conversion.skippedRows > 0 {
                note += " \(conversion.skippedRows.formatted()) without a readable date were left out."
            }
            listRequest = ListRequest(text: conversion.text, note: note)
        } else {
            listRequest = ListRequest(text: text, note: "From \(url.lastPathComponent).")
        }
    }

    private func restore(_ backup: KeptBackup) {
        let result = store.merge(backup)
        Haptics.success()
        if result.changed {
            var parts: [String] = []
            if result.addedEntries > 0 { parts.append("\(result.addedEntries.formatted()) entries") }
            if result.addedHabits > 0 { parts.append("\(result.addedHabits) checklist items") }
            if result.addedTicks > 0 { parts.append("\(result.addedTicks.formatted()) check-offs") }
            message = ImportMessage(title: "Backup Restored", body: "Added " + parts.joined(separator: ", ") + ".")
        } else {
            message = ImportMessage(title: "Already Up to Date", body: "Everything in that backup is already here.")
        }
    }
}
