import SwiftUI

/// Shown in Settings. Keep in sync with PRIVACY.md, which is the
/// public copy linked from the App Store listing.
enum PrivacyPolicy {
    static let updated = "October 3, 2026"

    struct Section: Identifiable {
        let title: String
        let text: String
        var id: String { title }
        init(_ title: String, _ text: String) { self.title = title; self.text = text }
    }

    static let sections: [Section] = [
        Section("The short version",
         "Unlisted does not collect, store, sell or share any of your information. There are no accounts, no ads, no analytics and no tracking. Everything you type stays on your device."),
        Section("What the app stores",
         "Names, cities, emails, phone numbers and usernames you enter for your family; your progress on opt-outs and checklists; and links you log. This is saved in a single file on your device, encrypted by iOS while your device is locked. The app never asks for a Social Security number."),
        Section("What leaves your device",
         "Nothing, unless you choose it. When you tap a search or an opt-out page, it opens in Safari and that website's own privacy policy applies. When you send a letter, it goes through your own Mail app, and you decide whether to send it."),
        Section("Notifications",
         "Reminders are scheduled on your device. They never include names."),
        Section("Backups",
         "If you use iCloud or computer backups, your device backup may include the app's file, protected by Apple's backup encryption. Use Settings > Delete all my data to erase everything in the app."),
        Section("Children",
         "The app is meant for parents and adults. Children's details are entered by a parent and stay on the parent's device."),
        Section("Changes and contact",
         "If this policy changes, the new version will be in the app and at the public link in the App Store listing. Questions: messagegabrielhere@gmail.com."),
    ]
}

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            ForEach(PrivacyPolicy.sections) { section in
                SwiftUI.Section(section.title) { Text(section.text) }
            }
            SwiftUI.Section {
                Text("Last updated \(PrivacyPolicy.updated)").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
