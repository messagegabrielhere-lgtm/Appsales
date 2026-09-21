# Releasing

## Path 1: from your Mac, one command

With Xcode installed and signed in to your Apple ID (Xcode > Settings > Accounts):

```sh
git clone https://github.com/messagegabrielhere-lgtm/Appsales.git
cd Appsales
scripts/release.sh YOUR_TEAM_ID
```

The script installs XcodeGen if needed, generates the project, archives with automatic
signing (which registers the bundle ID and creates certificates for you), pauses so you can
create the app record in App Store Connect, then uploads. Screenshots:

```sh
scripts/screenshots.sh
```

## Path 2: from GitHub, no Mac required

The **Release to App Store Connect** workflow archives, signs, and uploads a build from a
GitHub-hosted Mac. Once it runs green, the build sits in App Store Connect ready to attach to
your 1.0 version and submit for review. Set it up once; every later release is one click.

You still need an Apple Developer Program membership ($99/year) and a one-time visit to a Mac
or a friend's Mac to export a distribution certificate (step 3). Everything else is a browser.

## 1. Enroll and create the app record

1. Enroll at <https://developer.apple.com/programs/enroll/>. Approval takes 24 to 48 hours.
2. In <https://appstoreconnect.apple.com> go to **Business** and complete the Paid Apps
   agreement, banking, and tax forms. Paid apps cannot go on sale until this is **Active**.
3. **My Apps > + > New App**. Name `Kept: Daily Habit Streaks`, bundle ID of your choosing
   (register it first at <https://developer.apple.com/account/resources/identifiers/list>,
   for example `com.yourname.kept`), SKU `kept-ios-1`.
4. Set the price to **$0.99 (Tier 1)** under Pricing and Availability.

## 2. Create an App Store Connect API key

1. App Store Connect > **Users and Access > Integrations > App Store Connect API**.
2. **Generate API Key**, name `GitHub Release`, access **App Manager**.
3. Note the **Issuer ID** (top of the page) and the **Key ID**. Download the `.p8` file. Apple
   only lets you download it once.

## 3. Export a distribution certificate (one-time, needs any Mac)

1. Open Xcode, sign in under Settings > Accounts, select your team, **Manage Certificates**,
   press **+** and choose **Apple Distribution**.
2. Open **Keychain Access**, find the `Apple Distribution: <your name>` certificate under
   My Certificates, right-click, **Export**, save as `.p12` with a password you'll remember.

No Mac at all? Ask anyone with Xcode to do this on your account, or use a cloud Mac such as
MacStadium or a one-hour MacinCloud rental. It takes five minutes.

## 4. Add repository secrets

In this repository: **Settings > Secrets and variables > Actions > New repository secret**.

| Secret | Value |
| --- | --- |
| `BUNDLE_ID` | The bundle ID from step 1, e.g. `com.yourname.kept` |
| `APPLE_TEAM_ID` | 10-character Team ID from <https://developer.apple.com/account> under Membership |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from step 2 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID from step 2 |
| `APP_STORE_CONNECT_API_KEY_P8` | The `.p8` file contents, base64-encoded: `base64 -i AuthKey_XXXX.p8 \| pbcopy` on Mac, or `base64 -w0 AuthKey_XXXX.p8` on Linux |
| `DIST_CERT_P12_BASE64` | The `.p12` from step 3, base64-encoded the same way |
| `DIST_CERT_PASSWORD` | The password you set when exporting the `.p12` |

## 5. Run it

1. **Actions > Release to App Store Connect > Run workflow**. Keep version `1.0.0`.
2. It takes about 10 minutes. The build number is the workflow run number, so every run is
   unique and you never have to bump it by hand.
3. In App Store Connect, the build appears under **TestFlight** after Apple processes it
   (10 to 30 minutes). You may get an email about "Missing Compliance"; the project already
   declares no encryption, so that email should not arrive, but if it does answer **No**.
4. On the **1.0 Prepare for Submission** page, pick the build, fill in the listing from
   `docs/APP_STORE_LISTING.md`, add screenshots (see `docs/APP_STORE_SUBMISSION.md`), and
   press **Add for Review**.

## Troubleshooting

- **"No signing certificate found"**: the `.p12` was exported without its private key. In
  Keychain Access expand the certificate, select both the certificate and the key, and export
  them together.
- **"No profiles for bundle ID"**: `-allowProvisioningUpdates` creates one automatically with
  the API key, but the bundle ID must already be registered in your developer account.
- **"Unable to authenticate"**: the API key needs **App Manager** access, not Developer.
- **Upload succeeds but nothing appears**: wait 30 minutes and check the email address on
  your Apple ID for a processing failure notice.
