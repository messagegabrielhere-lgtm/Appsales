import SwiftUI
import UIKit

struct RemoveView: View {
    @Environment(AppStore.self) private var store
    @State private var personID: UUID?
    @State private var search = ""

    private var person: Person? { store.person(personID) ?? store.me ?? store.adults.first }

    var body: some View {
        NavigationStack {
            List {
                if let person {
                    Section {
                        PersonPicker(people: store.adults, selection: $personID)
                        ProgressRow(title: "Handled", symbol: "eraser",
                                    done: store.brokersDone(for: person), total: BrokerCatalog.all.count)
                    } footer: {
                        Text("Search each site for \(person.firstName.isEmpty ? "yourself" : person.firstName). If you're listed, opt out; if not, mark it Not listed. You'll be reminded to check again.")
                    }
                    ForEach(BrokerCategory.allCases) { category in
                        let brokers = BrokerCatalog.all.filter {
                            $0.category == category && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
                        }
                        if !brokers.isEmpty {
                            Section {
                                ForEach(brokers) { broker in
                                    NavigationLink {
                                        BrokerDetailView(broker: broker, personID: person.id)
                                    } label: {
                                        BrokerRow(broker: broker, progress: store.progress(broker, for: person))
                                    }
                                }
                            } header: {
                                Text(category.title)
                            } footer: {
                                Text(category.footnote)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Add yourself first", systemImage: "person.crop.circle.badge.plus",
                                           description: Text("Add your details on the Home tab."))
                }
            }
            .searchable(text: $search, prompt: "Find a site")
            .navigationTitle("Remove")
        }
    }
}

struct BrokerRow: View {
    let broker: Broker
    let progress: BrokerProgress

    var body: some View {
        HStack {
            Image(systemName: progress.status.symbol)
                .foregroundStyle(progress.status == .notStarted ? Color.secondary : Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(broker.name)
                if progress.status != .notStarted {
                    Text(progress.isRecheckDue(for: broker) ? "Re-check due" : progress.status.label)
                        .font(.caption)
                        .foregroundStyle(progress.isRecheckDue(for: broker) ? Color.orange : Color.secondary)
                }
            }
        }
    }
}

struct BrokerDetailView: View {
    @Environment(AppStore.self) private var store
    let broker: Broker
    let personID: UUID
    @State private var copied = false

    var body: some View {
        if let person = store.person(personID) {
            let progress = store.progress(broker, for: person)
            List {
                Section("How to opt out") {
                    Text(broker.instructions)
                    if let url = broker.optOutURL {
                        Link(destination: url) { Label("Open the opt-out page", systemImage: "safari") }
                    }
                    if let email = broker.email {
                        NavigationLink {
                            LetterComposerView(kind: broker.category == .archive ? .archiveRemoval : .dataBrokerDeletion,
                                               recipientName: broker.name, recipientEmail: email, personID: person.id)
                        } label: {
                            Label("Email a deletion request", systemImage: "envelope")
                        }
                    }
                    Button {
                        UIPasteboard.general.string = formDetails(person)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy my details for the form", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }

                Section {
                    Picker("Status", selection: Binding(
                        get: { progress.status },
                        set: { status in
                            store.setStatus(status, broker: broker, person: person)
                            if store.data.remindersEnabled {
                                if status == .notStarted { Reminders.cancelRecheck(broker, for: person) }
                                else { Reminders.scheduleRecheck(broker, for: person) }
                            }
                        })) {
                        ForEach(BrokerStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Status for \(person.displayName)")
                } footer: {
                    if progress.status != .notStarted {
                        Text("Updated \(progress.updated.formatted(date: .abbreviated, time: .omitted)). Check again after about \(broker.recheckDays) days.")
                    }
                }

                Section("Notes") {
                    TextField("Confirmation number, date, anything", text: Binding(
                        get: { progress.note },
                        set: { store.setStatus(progress.status, note: $0, broker: broker, person: person, now: progress.updated) }),
                              axis: .vertical)
                }
            }
            .navigationTitle(broker.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Person removed", systemImage: "person.slash")
        }
    }

    private func formDetails(_ p: Person) -> String {
        var lines = [p.fullName]
        if !p.location.isEmpty { lines.append(p.location) }
        lines += p.emails.cleaned.prefix(1)
        lines += p.phones.cleaned.prefix(1)
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
