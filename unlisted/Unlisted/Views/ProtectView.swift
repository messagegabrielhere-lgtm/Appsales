import SwiftUI

struct ProtectView: View {
    @Environment(AppStore.self) private var store
    var embedded = false

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        List {
            let progress = store.checklistProgress
            Section {
                ProgressRow(title: "Family protection", symbol: "lock.shield", done: progress.done, total: progress.total)
            } footer: {
                Text("Steps for adults appear once per adult. Steps for kids appear once per child.")
            }
            ForEach(ChecklistSection.allCases) { section in
                let steps = store.applicableSteps().filter { $0.0.section == section }.map { StepItem($0) }
                if !steps.isEmpty {
                    Section {
                        ForEach(steps) { step in
                            ChecklistRow(item: step.item, person: step.person,
                                         showPerson: step.person != nil && store.data.people.count > 1)
                        }
                    } header: {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
            }
        }
        .navigationTitle("Protect")
    }
}

struct ChecklistRow: View {
    @Environment(AppStore.self) private var store
    let item: ChecklistItem
    let person: Person?
    var showPerson = false
    @State private var writingLetter = false

    var body: some View {
        let done = store.isDone(item, person: person)
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggle(item, person: person)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(done ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(done)
                    .foregroundStyle(done ? Color.secondary : Color.primary)
                if showPerson, let person {
                    Text(person.displayName).font(.caption.weight(.semibold)).foregroundStyle(.tint)
                }
                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    if let url = item.url {
                        Link("Open", destination: url).font(.caption.weight(.semibold))
                    }
                    if item.letter != nil {
                        Button("Write the letter") { writingLetter = true }
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $writingLetter) {
            if let letter = item.letter {
                NavigationStack {
                    LetterComposerView(kind: letter, personID: person?.isMinor == true ? nil : person?.id)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { writingLetter = false }
                            }
                        }
                }
            }
        }
    }
}
