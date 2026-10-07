import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    var onDone: () -> Void
    @State private var started = false

    var body: some View {
        NavigationStack {
            if started {
                PersonEditor(person: Person(relationship: .me), title: "About you") { person in
                    store.upsert(person)
                    onDone()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "eye.slash.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        Text("Take your family off the internet")
                            .font(.largeTitle.bold())
                        VStack(alignment: .leading, spacing: 14) {
                            point("magnifyingglass", "Scan", "Ready-made searches for your names, emails, phones and usernames.")
                            point("eraser", "Remove", "Step-by-step opt-outs for the biggest people-search sites and data brokers, with re-check reminders.")
                            point("envelope", "Letters", "Removal and do-not-share letters filled in for you. You review and send.")
                            point("lock.shield", "Protect", "Credit freezes, kids' protection and scam defense, one step at a time.")
                        }
                        Label("Everything stays on this iPhone. No account, no tracking, no servers.", systemImage: "lock.iphone")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button {
                            started = true
                        } label: {
                            Text("Get started").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
            }
        }
    }

    private func point(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

/// Add or edit one family member. Lists (emails, phones…) are typed one per line.
struct PersonEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (Person) -> Void

    @State private var person: Person
    @State private var otherNames: String
    @State private var emails: String
    @State private var phones: String
    @State private var usernames: String
    @State private var pastLocations: String
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date

    init(person: Person, title: String, onSave: @escaping (Person) -> Void) {
        self.title = title
        self.onSave = onSave
        _person = State(initialValue: person)
        _otherNames = State(initialValue: person.otherNames.listText)
        _emails = State(initialValue: person.emails.listText)
        _phones = State(initialValue: person.phones.listText)
        _usernames = State(initialValue: person.usernames.listText)
        _pastLocations = State(initialValue: person.pastLocations.listText)
        _hasBirthDate = State(initialValue: person.birthDate != nil)
        _birthDate = State(initialValue: person.birthDate ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date())
    }

    var body: some View {
        Form {
            Section {
                Picker("Who", selection: $person.relationship) {
                    ForEach(Relationship.allCases) { Text($0.label).tag($0) }
                }
                TextField("First name", text: $person.firstName).textContentType(.givenName)
                TextField("Middle name", text: $person.middleName).textContentType(.middleName)
                TextField("Last name", text: $person.lastName).textContentType(.familyName)
                Toggle("Add birth date", isOn: $hasBirthDate)
                if hasBirthDate {
                    DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                }
            } header: {
                Text("Name")
            } footer: {
                Text("Birth date is only used to tell adults from children and to fill in credit-freeze letters. The app never asks for a Social Security number.")
            }

            Section {
                TextField("City", text: $person.city).textContentType(.addressCity)
                TextField("State", text: $person.state).textContentType(.addressState)
                listField("Past cities, one per line", $pastLocations)
            } header: {
                Text("Where you live")
            } footer: {
                Text("Just the city. People-search results usually show city, so this helps tell your listings apart from someone else's.")
            }

            Section("Other names") {
                listField("Nicknames, maiden name, initials", $otherNames)
            }
            Section("Emails") {
                listField("One per line, including old ones", $emails)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            Section("Phone numbers") {
                listField("One per line, including old ones", $phones)
                    .keyboardType(.phonePad)
            }
            Section("Usernames") {
                listField("Social media and forum usernames", $usernames)
                    .textInputAutocapitalization(.never)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var saved = person
                    saved.otherNames = .fromList(otherNames)
                    saved.emails = .fromList(emails)
                    saved.phones = .fromList(phones)
                    saved.usernames = .fromList(usernames)
                    saved.pastLocations = .fromList(pastLocations)
                    saved.birthDate = hasBirthDate ? birthDate : nil
                    onSave(saved)
                    dismiss()
                }
                .disabled(person.firstName.trimmed.isEmpty)
            }
        }
    }

    private func listField(_ prompt: String, _ text: Binding<String>) -> some View {
        TextField(prompt, text: text, axis: .vertical)
            .lineLimit(1...6)
            .autocorrectionDisabled()
    }
}

/// Picker shared by the Scan, Remove and Protect tabs.
struct PersonPicker: View {
    let people: [Person]
    @Binding var selection: UUID?

    var body: some View {
        if people.count > 1 {
            // Show the first person as chosen until the user picks someone,
            // matching what the screens fall back to.
            Picker("Person", selection: Binding(
                get: { selection.flatMap { id in people.contains { $0.id == id } ? id : nil } ?? people.first?.id },
                set: { selection = $0 })) {
                ForEach(people) { Text($0.displayName).tag(Optional($0.id)) }
            }
            .pickerStyle(.menu)
        }
    }
}
