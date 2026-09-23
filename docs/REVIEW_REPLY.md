# Reply to App Review: new-account information request

Apple sends this Guideline 2.1 "Information Needed" request to developer accounts with
limited review history. It is not a defect report. Nothing in the app or the listing has to
change; Apple is asking you to introduce yourself and the app.

Two things to deliver:

1. A screen recording made on a physical iPhone. See `docs/SCREEN_RECORDING.md`.
2. The written answers below, posted twice: as a reply in Resolution Center, and pasted into
   the **App Review Information > Notes** field so future submissions already have them.

---

## Answers, ready to paste

Copy everything between the rules. It answers Apple's points 2 through 6 in order; point 1 is
the recording, which you attach to the same reply.

---

**2. Purpose and target audience**

Kept is a habit tracker for iPhone and iPad. It solves one problem: people who want to build a
small daily routine abandon most habit apps because those apps demand a subscription, an
account, and attention. Kept is a one-time $0.99 purchase with no subscription, no account, no
advertising, and no analytics.

The audience is general consumers who want to track a handful of everyday personal habits, such
as drinking water, walking, reading, or stretching. There is no professional, medical, clinical,
or enterprise use. The app makes no health claims, offers no advice, and is not a medical or
fitness device. It records only whether the user tapped a button on a given calendar day.

**3. Setting up and accessing the main features**

No login, account, credentials, sample files, or configuration of any kind are required. The app
is fully functional the moment it is installed, offline, on a device that has never been signed
in to anything.

Step by step, from a fresh install:

1. Launch the app. The first screen explains that no habits exist yet.
2. Tap the + button in the top right. Type a name, for example "Drink water". Optionally pick an
   icon and a color. Tap Save.
3. The habit appears in the list. Tap the circle on the right of the row to mark it done for
   today. Tap it again to undo.
4. Tap the row itself to open the habit. This screen shows the current streak, the best streak,
   the total number of days completed, and the completion rate over the last thirty days,
   followed by a month calendar.
5. Tap any past day in that calendar to add or remove a completion for that day. This is how a
   user corrects a check-in they forgot.
6. Tap the ... button in the top right of that screen to edit or delete the habit.
7. Tap the i button on the main list to open About, which shows the version, a statement of the
   privacy model, and a button that exports all data as plain JSON through the standard iOS
   share sheet.

**4. External services, tools, and platforms used to deliver core functionality**

None. The app contains no networking code of any kind. Specifically, it uses:

- No backend, server, or API of our own or anyone else's.
- No data providers or content feeds.
- No authentication or identity service. There are no accounts.
- No payment processor. The purchase price is handled entirely by the App Store.
- No analytics, attribution, crash reporting, or advertising SDK.
- No artificial intelligence or machine learning service, on-device or remote.
- No third-party libraries or frameworks at all. The app is written in Swift and SwiftUI and
  links only Apple's own system frameworks.

All user data is a single JSON file inside the app's private container on the device. It is
never transmitted. The accompanying privacy manifest declares no tracking and no collected data
types, and the App Privacy section of the listing declares that no data is collected.

**5. Regional differences**

There are none. The app behaves identically in every region and on every storefront. There is no
region-specific content, no geo-gating, and no feature that varies by country, because the app
never contacts a network and has no remote configuration.

The only locale-sensitive behavior is standard iOS formatting: dates and weekday names are
rendered through the system formatters, and the month calendar starts the week on whichever day
the user's region uses. This is presentation only and does not change functionality.

**6. Regulated industry and third-party material**

The app does not operate in a regulated industry and contains no protected third-party material.

- It is not a health, medical, fitness, or wellness service. It makes no health claims, provides
  no advice or diagnosis, and does not integrate with HealthKit or any health data source. It
  records a tap against a calendar day and counts consecutive days.
- It involves no finance, gambling, lending, insurance, cryptocurrency, dating, or messaging.
- It contains no user-generated content, no social features, no sharing between users, and no
  way for one user to see another user's data.
- All artwork is original. The app icon was produced for this app. The only other imagery is
  standard Unicode emoji and Apple's SF Symbols, both supplied by the operating system.
- The app name "Kept" is used descriptively and does not incorporate any third-party trademark.

---

## Where to paste it

1. **Resolution Center.** Open App Store Connect, go to the app, click the rejected
   submission, and use **Reply to App Review**. Paste the answers and attach the recording.
2. **App Review Information > Notes**, on the version page. Paste the same text. Apple asked
   for this explicitly so that future submissions already carry the context.
