import SwiftUI
import UIKit

/// Walks the user through the Internet Archive's Wayback Machine exclusion form,
/// one site at a time, with every answer filled in and ready to copy.
struct ArchiveRemovalView: View {
    @Environment(AppStore.self) private var store
    let personID: UUID?

    @State private var sites: String
    @State private var email = ""
    @State private var copied: String?

    init(personID: UUID? = nil, sites: [String] = []) {
        self.personID = personID
        _sites = State(initialValue: sites.listText)
    }

    private var person: Person? { store.person(personID) ?? store.me ?? store.adults.first }
    private var requests: [ArchiveExclusion.Request] { ArchiveExclusion.requests(from: .fromList(sites)) }

    var body: some View {
        Form {
            Section {
                TextField("yourdomain.com, one per line", text: $sites, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Your websites")
            } footer: {
                Text("Paste links from anywhere, even from an email or an old Wayback Machine capture. The app cleans them up and makes one request per site.")
            }

            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Contact email")
            } footer: {
                Text("Use your own address, not a general customer service one. The Archive replies here.")
            }

            ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                Section {
                    LabeledContent("Contact Email", value: email.trimmed.isEmpty ? "[Your email]" : email.trimmed)
                    LabeledContent("Type of URL", value: request.type.rawValue)
                    LabeledContent("URL to exclude", value: request.url)
                    if !request.alsoCovers.isEmpty {
                        LabeledContent("Also covers") {
                            Text(request.alsoCovers.joined(separator: "\n")).multilineTextAlignment(.trailing)
                        }
                    }
                    copyButton("Copy URL", value: request.url, key: request.id + "url")
                    copyButton("Copy all answers", value: request.answers(email: email.trimmed), key: request.id + "all")
                    Link(destination: ArchiveExclusion.formURL) {
                        Label("Open the exclusion form", systemImage: "safari")
                    }
                    if let captures = request.capturesURL {
                        Link(destination: captures) {
                            Label("See what's archived", systemImage: "archivebox")
                        }
                    }
                } header: {
                    Text(requests.count > 1 ? "Request \(index + 1) of \(requests.count): \(request.host)" : request.host)
                } footer: {
                    Text(request.proofHint)
                }
            }

            Section {
                Text("1. Open the form and paste the answers above.")
                Text("2. Solve the CAPTCHA, press Continue, and answer the rest truthfully: what to remove (all captures), and when you owned the site.")
                Text("3. Submit one site at a time. Repeat for each request above.")
                Text("4. Mark the Internet Archive as Request sent on the Remove tab. The app reminds you to check back.")
            } header: {
                Text("How to submit")
            } footer: {
                Text("The form has a CAPTCHA, so you submit it yourself; the app never sends anything. Removal isn't guaranteed, but site owners who can prove control are usually approved.")
            }

            Section {
                NavigationLink {
                    LetterComposerView(kind: .archiveRemoval, urls: requests.map(\.url),
                                       recipientEmail: "info@archive.org", personID: person?.id)
                } label: {
                    Label("Also email info@archive.org", systemImage: "envelope")
                }
            } footer: {
                Text("Optional. If you've already emailed them, reply to their message saying you've submitted the form.")
            }
        }
        .navigationTitle("Wayback Machine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if email.isEmpty { email = person?.emails.cleaned.first ?? "" }
        }
        .onChange(of: sites) { _, _ in copied = nil }
    }

    private func copyButton(_ title: String, value: String, key: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copied = key
        } label: {
            Label(copied == key ? "Copied" : title, systemImage: copied == key ? "checkmark" : "doc.on.doc")
        }
    }
}
