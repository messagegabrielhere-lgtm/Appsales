# Unlisted

A free iPhone app that helps a family find and remove their personal
information from the internet, and lock down their identity.

- **Scan:** ready-made searches for each family member's names, places, emails,
  phone numbers and usernames, opened in Safari. Log what you find and the app
  suggests the next step.
- **Remove:** step-by-step opt-outs for 27 people-search sites, data brokers,
  search engines and archives, with per-person status and re-check reminders
  (brokers re-list people).
- **Letters:** fills in data-broker deletion, website removal, do-not-share
  (banks and insurers), child credit freeze, Wayback Machine and license-plate
  camera letters. Opens them in Mail; the user reviews and sends.
- **Protect:** credit freezes, account security, phone-number protection, kids,
  home, scam defense and family safety net, tracked per adult, per child and
  per household.

## Privacy

- No account, no analytics, no ads, no network calls of its own. Searches and
  opt-out pages open in Safari; letters go through the user's own Mail app.
- Data lives in one JSON file in Application Support, written with
  `completeFileProtection`. Settings has Export and Delete all.
- There is no field for a Social Security number. Letters that need one print
  "[write in by hand]".
- Notifications never include names.
- `PrivacyInfo.xcprivacy` declares no tracking and no collected data, so the App
  Store privacy label is "Data Not Collected".

## Build

Requires a Mac with Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd Appsales/unlisted
xcodegen generate
open Unlisted.xcodeproj
```

Run the tests with Product > Test, or:

```bash
xcodebuild test -project Unlisted.xcodeproj -scheme Unlisted \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

CI runs the same build and tests on every change to this folder
(`.github/workflows/unlisted-ci.yml`).

## Publishing it free on the App Store

Copy for every App Store Connect field is in `AppStore/listing.md`. The
privacy policy is `PRIVACY.md` and the support page is `SUPPORT.md`.

**Screenshots** are taken automatically. On every push, CI boots a
6.9" iPhone simulator, opens each tab with a fictional demo family
(`-demo -tab N`) and commits the images to `AppStore/screenshots/`.

**Uploading builds** is done by `.github/workflows/unlisted-release.yml`,
using the team (MAP974T827) and bundle ID (`com.messagegabrielhere.unlisted`)
already set in `project.yml`:

1. In App Store Connect, open Users and Access > Integrations > App Store
   Connect API, create a key with the **Admin** role, and download the `.p8`
   file. Note the Key ID and Issuer ID. The same key also works for Kept.
2. In this GitHub repo, open Settings > Secrets and variables > Actions and
   add `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID` and
   `APP_STORE_CONNECT_API_KEY_P8` (paste the whole `.p8` file). Kept's release
   uses the same three.
3. Create the app in App Store Connect with bundle ID
   `com.messagegabrielhere.unlisted`.
4. Push a tag such as `unlisted-v1.0.0`. The workflow signs the app with cloud
   signing and uploads it. It shows up in TestFlight about 10-30 minutes later.
5. In App Store Connect, add the screenshots and listing copy, choose "Data Not
   Collected", select the build, and submit for review.

## Keeping the opt-out list current

Brokers change their opt-out pages often. The list is in
`Unlisted/Data/BrokerCatalog.swift` (last checked October 2026). The
protection checklist is in `Unlisted/Data/ChecklistCatalog.swift`.

The app gives general privacy guidance, not legal advice.
