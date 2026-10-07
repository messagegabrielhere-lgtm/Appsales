import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: Person?
    @State private var adding = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                progressSection
                recheckSection
                nextStepsSection
                familySection
            }
            .navigationTitle("Unlisted")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(item: $editing) { person in
                NavigationStack {
                    PersonEditor(person: person, title: "Edit") { store.upsert($0) }
                }
            }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    PersonEditor(person: Person(relationship: store.me == nil ? .me : .spouse), title: "Add family member") { store.upsert($0) }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var progressSection: some View {
        let checklist = store.checklistProgress
        let brokersTotal = BrokerCatalog.all.count * max(store.adults.count, 1)
        let brokersDone = store.adults.reduce(0) { $0 + store.brokersDone(for: $1) }
        return Section("Progress") {
            ProgressRow(title: "Opt-outs handled", symbol: "eraser", done: brokersDone, total: brokersTotal)
            ProgressRow(title: "Protection steps", symbol: "lock.shield", done: checklist.done, total: checklist.total)
            HStack {
                Label("Findings to deal with", systemImage: "exclamationmark.magnifyingglass")
                Spacer()
                Text("\(store.openFindings.count)").foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var recheckSection: some View {
        let due = store.adults.flatMap { person in store.recheckDue(for: person).map { DueItem(person: person, broker: $0) } }
        if !due.isEmpty {
            Section {
                ForEach(due) { item in
                    NavigationLink {
                        BrokerDetailView(broker: item.broker, personID: item.person.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.broker.name)
                            Text(item.person.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Time to re-check")
            } footer: {
                Text("Sites often re-list people after a few months. Search again and re-submit if you're back.")
            }
        }
    }

    @ViewBuilder
    private var nextStepsSection: some View {
        let next = store.applicableSteps().filter { !store.isDone($0.0, person: $0.1) }.prefix(4)
        if !next.isEmpty {
            Section("Next steps") {
                ForEach(next.map { StepItem($0) }) { step in
                    ChecklistRow(item: step.item, person: step.person, showPerson: true)
                }
                NavigationLink("See all protection steps") { ProtectView(embedded: true) }
            }
        }
    }

    private var familySection: some View {
        Section {
            ForEach(store.data.people) { person in
                Button { editing = person } label: {
                    HStack {
                        Image(systemName: person.isMinor ? "figure.child" : "person.fill")
                            .frame(width: 24)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(person.displayName).foregroundStyle(.primary)
                            Text(person.relationship.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for person in offsets.map({ store.data.people[$0] }) { store.remove(person) }
            }
            Button { adding = true } label: { Label("Add family member", systemImage: "plus") }
        } header: {
            Text("Family")
        } footer: {
            Text("Adults can make their own opt-out requests. For children, the app focuses on credit freezes and keeping them off the internet.")
        }
    }
}

struct ProgressRow: View {
    let title: String
    let symbol: String
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text("\(done) of \(total)").foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
        }
        .padding(.vertical, 2)
    }
}

private struct DueItem: Identifiable {
    let person: Person
    let broker: Broker
    var id: String { "\(broker.id)|\(person.id.uuidString)" }
}

struct StepItem: Identifiable {
    let item: ChecklistItem
    let person: Person?
    var id: String { "\(item.id)|\(person?.id.uuidString ?? "household")" }

    init(_ step: (ChecklistItem, Person?)) {
        item = step.0
        person = step.1
    }
}
