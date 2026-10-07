import SwiftUI

struct ScanView: View {
    @Environment(AppStore.self) private var store
    @State private var personID: UUID?
    @State private var engine: SearchEngine = .google
    @State private var newFinding = false

    private var people: [Person] { store.adults + store.children }
    private var person: Person? { store.person(personID) ?? people.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PersonPicker(people: people, selection: $personID)
                    Picker("Search with", selection: $engine) {
                        ForEach(SearchEngine.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Each search opens in Safari. When you find a page about \(person?.firstName.isEmpty == false ? person!.firstName : "you"), come back and log it below.")
                }

                if let person {
                    let queries = SearchPlan.queries(for: person)
                    Section("Searches to run") {
                        if queries.isEmpty {
                            Text("Add a name, email or phone number on the Home tab to get searches.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(queries) { query in
                            if let url = engine.url(for: query.query) {
                                Link(destination: url) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(query.query).font(.callout.monospaced()).foregroundStyle(.primary)
                                        Text(query.label).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    if person.isMinor {
                        Section {
                            Label("For children, focus on the Protect tab: credit freezes and keeping their names and schools off public posts.", systemImage: "figure.child")
                                .font(.footnote)
                        }
                    }
                }

                Section {
                    let findings = store.data.findings.filter { personID == nil || $0.personID == personID }
                    if findings.isEmpty {
                        Text("Nothing logged yet.").foregroundStyle(.secondary)
                    }
                    ForEach(findings) { finding in
                        NavigationLink {
                            FindingDetailView(findingID: finding.id)
                        } label: {
                            FindingRow(finding: finding)
                        }
                    }
                    .onDelete { offsets in
                        for finding in offsets.map({ findings[$0] }) { store.remove(finding) }
                    }
                    Button { newFinding = true } label: { Label("Log a page I found", systemImage: "plus") }
                } header: {
                    Text("What I found")
                }
            }
            .navigationTitle("Scan")
            .sheet(isPresented: $newFinding) {
                NavigationStack { FindingEditor(finding: Finding(personID: person?.id)) }
            }
        }
    }
}

struct FindingRow: View {
    let finding: Finding

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(finding.title.isEmpty ? (finding.host ?? finding.url) : finding.title).lineLimit(1)
            HStack(spacing: 6) {
                Text(finding.status.label)
                Text("·")
                Text(finding.kind.label).lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct FindingEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var finding: Finding

    var body: some View {
        Form {
            Section {
                TextField("Paste the link", text: $finding.url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: finding.url) { _, newValue in
                        let (kind, _) = Finding.classify(newValue)
                        finding.kind = kind
                    }
                TextField("Short description (optional)", text: $finding.title)
            }
            Section {
                PersonPicker(people: store.data.people, selection: $finding.personID)
                Picker("What is it?", selection: $finding.kind) {
                    ForEach(FindingKind.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                Text(finding.kind.nextStep)
            }
            Section("Notes") {
                TextField("Anything to remember", text: $finding.note, axis: .vertical)
            }
        }
        .navigationTitle("Log a page")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    finding.url = Finding.normalized(finding.url)
                    store.upsert(finding)
                    dismiss()
                }
                .disabled(finding.url.trimmed.isEmpty)
            }
        }
    }
}

struct FindingDetailView: View {
    @Environment(AppStore.self) private var store
    let findingID: UUID
    @State private var editing = false

    var body: some View {
        if let finding = store.data.findings.first(where: { $0.id == findingID }) {
            let match = Finding.classify(finding.url).1
            List {
                Section {
                    if let url = URL(string: finding.url) {
                        Link(destination: url) { Label(finding.host ?? finding.url, systemImage: "safari") }
                    }
                    Picker("Status", selection: Binding(
                        get: { finding.status },
                        set: { status in var f = finding; f.status = status; store.upsert(f) })) {
                        ForEach(FindingStatus.allCases) { Text($0.label).tag($0) }
                    }
                    if let person = store.person(finding.personID) {
                        LabeledContent("About", value: person.displayName)
                    }
                }
                Section("What to do") {
                    Text(finding.kind.nextStep)
                    if let match, let person = store.person(finding.personID) ?? store.me {
                        NavigationLink("Open \(match.name) opt-out") {
                            BrokerDetailView(broker: match, personID: person.id)
                        }
                    }
                    switch finding.kind {
                    case .thirdParty:
                        NavigationLink("Write a removal request") {
                            LetterComposerView(kind: .websiteRemoval, urls: [finding.url], personID: finding.personID)
                        }
                    case .dataBroker where match == nil:
                        NavigationLink("Write a deletion request") {
                            LetterComposerView(kind: .dataBrokerDeletion, urls: [finding.url], personID: finding.personID)
                        }
                    case .deadLink:
                        if let google = URL(string: "https://search.google.com/search-console/remove-outdated-content") {
                            Link("Google Outdated Content tool", destination: google)
                        }
                        if let bing = URL(string: "https://www.bing.com/webmaster/tools/contentremoval") {
                            Link("Bing Content Removal tool", destination: bing)
                        }
                    default:
                        EmptyView()
                    }
                }
                if !finding.note.isEmpty {
                    Section("Notes") { Text(finding.note) }
                }
            }
            .navigationTitle(finding.title.isEmpty ? "Finding" : finding.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Edit") { editing = true } }
            .sheet(isPresented: $editing) {
                NavigationStack { FindingEditor(finding: finding) }
            }
        } else {
            ContentUnavailableView("Removed", systemImage: "trash")
        }
    }
}
