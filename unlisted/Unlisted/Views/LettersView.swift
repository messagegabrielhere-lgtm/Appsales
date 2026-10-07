import SwiftUI
import MessageUI
import UIKit

struct LettersView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(LetterKind.allCases) { kind in
                        NavigationLink {
                            LetterComposerView(kind: kind)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title)
                                    Text(kind.summary).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: kind.symbol)
                            }
                        }
                    }
                } footer: {
                    Text("Letters are filled in from your details. Anything in [brackets] needs your input. You review every word and send it yourself; the app never sends anything.")
                }
            }
            .navigationTitle("Letters")
        }
    }
}

struct LetterComposerView: View {
    @Environment(AppStore.self) private var store
    let kind: LetterKind

    @State private var senderID: UUID?
    @State private var childIDs: Set<UUID> = []
    @State private var bureau: CreditBureau = .equifax
    @State private var recipientName: String
    @State private var recipientAddress = ""
    @State private var recipientEmail: String
    @State private var urls: String
    @State private var account = ""
    @State private var plates = ""
    @State private var letter = Letter(to: "", subject: "", body: "")
    @State private var showMail = false
    @State private var copied = false

    init(kind: LetterKind, urls: [String] = [], recipientName: String = "", recipientEmail: String = "", personID: UUID? = nil) {
        self.kind = kind
        _urls = State(initialValue: urls.listText)
        _recipientName = State(initialValue: recipientName)
        _recipientEmail = State(initialValue: recipientEmail.isEmpty ? kind.defaultRecipientEmail : recipientEmail)
        _senderID = State(initialValue: personID)
    }

    private var sender: Person {
        if let chosen = store.person(senderID), !chosen.isMinor { return chosen }
        return store.me ?? store.adults.first ?? Person()
    }

    private var context: LetterContext {
        LetterContext(sender: sender,
                      children: store.children.filter { childIDs.contains($0.id) },
                      recipientName: recipientName,
                      recipientAddress: recipientAddress,
                      recipientEmail: recipientEmail,
                      urls: .fromList(urls),
                      accountHint: account,
                      plates: .fromList(plates),
                      bureau: bureau)
    }

    /// Changes whenever an input changes, so the letter can be rebuilt.
    private var inputsKey: String {
        [senderID?.uuidString ?? "", childIDs.map(\.uuidString).sorted().joined(), bureau.rawValue,
         recipientName, recipientAddress, recipientEmail, urls, account, plates].joined(separator: "\u{1F}")
    }

    var body: some View {
        Form {
            Section {
                PersonPicker(people: store.adults, selection: $senderID)
            } header: {
                Text(kind.usesChildren ? "Parent signing" : "From")
            }

            if kind.usesChildren {
                Section {
                    if store.children.isEmpty {
                        Text("Add your children on the Home tab first.").foregroundStyle(.secondary)
                    }
                    ForEach(store.children) { child in
                        Toggle(child.displayName, isOn: Binding(
                            get: { childIDs.contains(child.id) },
                            set: { on in if on { childIDs.insert(child.id) } else { childIDs.remove(child.id) } }))
                    }
                    Picker("Credit bureau", selection: $bureau) {
                        ForEach(CreditBureau.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("Children")
                } footer: {
                    Text("Make one letter for each bureau. Young children's freezes must be mailed, by certified mail, with copies of the documents listed at the bottom of the letter.")
                }
            }

            if kind.usesRecipient {
                Section("To") {
                    TextField("Company, site or agency name", text: $recipientName)
                    TextField("Mailing address (optional)", text: $recipientAddress, axis: .vertical)
                    TextField("Email (optional)", text: $recipientEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            if kind.usesURLs {
                Section(kind == .archiveRemoval ? "Your websites" : "Links") {
                    TextField(kind == .archiveRemoval ? "yourdomain.com, one per line" : "Paste links, one per line",
                              text: $urls, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            if kind.usesAccount {
                Section("Account") {
                    TextField("Last 4 digits of account or policy", text: $account)
                }
            }

            if kind.usesPlates {
                Section("Vehicles") {
                    TextField("State and plate, one per line", text: $plates, axis: .vertical)
                        .textInputAutocapitalization(.characters)
                }
            }

            Section {
                if !letter.subject.isEmpty {
                    LabeledContent("Subject", value: letter.subject)
                }
                TextEditor(text: $letter.body)
                    .font(.callout)
                    .frame(minHeight: 320)
            } header: {
                Text("Letter (you can edit it)")
            }

            Section {
                if !kind.isMailedOnly && MFMailComposeViewController.canSendMail() {
                    Button { showMail = true } label: { Label("Open in Mail", systemImage: "envelope") }
                }
                ShareLink(item: letter.body, subject: Text(letter.subject)) {
                    Label(kind.isMailedOnly ? "Share or print" : "Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.string = letter.body
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy letter", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                Button("Start over from the template") { letter = LetterRenderer.render(kind, context) }
            } footer: {
                Text(kind.isMailedOnly
                     ? "Print it, fill in the blanks by hand, sign it, and mail it. Never email your Social Security number."
                     : "The app doesn't send anything. Mail opens with the letter ready for you to review and send.")
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if childIDs.isEmpty { childIDs = Set(store.children.map(\.id)) }
            letter = LetterRenderer.render(kind, context)
        }
        .onChange(of: inputsKey) { _, _ in
            letter = LetterRenderer.render(kind, context)
            copied = false
        }
        .sheet(isPresented: $showMail) {
            MailComposeView(letter: letter) { showMail = false }
                .ignoresSafeArea()
        }
    }
}

/// Apple's mail sheet. The user presses Send; the app never sends on its own.
struct MailComposeView: UIViewControllerRepresentable {
    let letter: Letter
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        if !letter.to.isEmpty { controller.setToRecipients([letter.to]) }
        controller.setSubject(letter.subject)
        controller.setMessageBody(letter.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            onFinish()
        }
    }
}
