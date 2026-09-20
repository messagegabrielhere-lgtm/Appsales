# App Store submission runbook

This is every step between this repository and a live $0.99 listing, in order, with the
realistic time each one takes. Steps marked **(you)** need your Apple ID, a Mac, or a payment
method and cannot be done from this repo.

## Realistic timeline

| Step | Typical wait |
| --- | --- |
| Apple Developer Program enrollment approval | 24 to 48 hours (longer for a company) |
| App Store Connect banking and tax forms | Same day, but no sales can be paid until done |
| First App Review | 24 to 72 hours, sometimes rejected once |
| First payout after a sale | Apple pays roughly 30 to 45 days after the end of the month |

Same-day revenue from a new App Store app is not possible. Plan for the first dollars to
arrive about six weeks after the first sale.

## Revenue math at $0.99

| | Per sale | Sales needed for $50 |
| --- | --- | --- |
| Small Business Program (15% commission, apply once revenue is under $1M) | $0.84 | 60 |
| Standard (30% commission) | $0.69 | 73 |

Apple sets the local price in each storefront from the USD tier; the net per sale varies by
country and VAT.

## 1. Accounts (you)

1. Enroll at <https://developer.apple.com/programs/enroll/> ($99 per year). Use the same
   Apple ID you will sign in to Xcode with.
2. Once approved, open <https://appstoreconnect.apple.com>, go to **Business**, and complete
   the Paid Apps agreement, banking, and tax forms. Paid apps cannot be released until this
   shows **Active**.
3. Optional but worth it: apply for the App Store Small Business Program at
   <https://developer.apple.com/app-store/small-business-program/> to drop commission to 15%.

## 2. Project setup

1. Pick a bundle identifier you own, such as `com.yourname.kept`. Replace the two
   `com.example` values in `project.yml` (`bundleIdPrefix` and `PRODUCT_BUNDLE_IDENTIFIER`,
   plus the tests target's identifier).
2. Run `xcodegen generate` and open `Kept.xcodeproj`.
3. In **Signing & Capabilities**, choose your team. Xcode creates the App ID and provisioning
   profile automatically.
4. Build and run on a simulator. Add two habits, check one off, open its detail page, and
   confirm the calendar toggles.
5. Run the tests: Product > Test (Cmd-U).

## 3. App Store Connect record (you)

1. **My Apps > + > New App**. Platform iOS, name `Kept` (if the name is taken, try
   `Kept: Daily Habits`), primary language English (U.S.), bundle ID from step 2, SKU `kept-ios-1`.
2. **Pricing and Availability**: choose price **$0.99 (Tier 1)**. Make it available in all
   territories unless you have a reason not to.
3. **App Privacy**: click **Get Started**, answer **No, we do not collect data from this app**.
   This is true; the app has no network code.
4. **App Information**: category **Productivity**, secondary **Health & Fitness**. Age rating:
   answer no to everything, which yields 4+.
5. Paste the copy from `docs/APP_STORE_LISTING.md` into the version page.
6. Privacy Policy URL: host `docs/PRIVACY_POLICY.md` somewhere public. GitHub Pages on this
   repo works: Settings > Pages > Deploy from branch, then use
   `https://<your-user>.github.io/Appsales/docs/PRIVACY_POLICY`.
   Support URL can be the repo's Issues page.

## 4. Screenshots (you)

Apple requires at least the 6.7-inch iPhone set. If you support iPad (this project does), the
13-inch iPad set is required too.

1. Run on the **iPhone 15 Pro Max** simulator. Add three or four habits with a few days of
   history each (tap past days in the calendar).
2. Capture with Cmd-S in the simulator: the habit list with today's date, a habit's detail page
   with the month grid, and the editor. Three to five images is plenty.
3. Repeat on the **iPad Pro 13-inch** simulator.
4. Upload under **App Previews and Screenshots** on the version page.

## 5. Archive and upload (you)

1. Set the destination to **Any iOS Device (arm64)**.
2. Product > Archive.
3. In the Organizer, **Distribute App > App Store Connect > Upload**. Accept the defaults.
4. Wait for the "build has completed processing" email (10 to 30 minutes), then select the
   build on the version page.
5. Export compliance: the project already sets `ITSAppUsesNonExemptEncryption` to `NO`, so
   Apple will not ask.

## 6. Submit for review (you)

1. Under **App Review Information**, no sign-in is needed. Notes: "Local-only habit tracker.
   Tap the circle next to a habit to mark it done; tap a habit for its calendar and streak
   stats. No account, no network access."
2. Version Release: **Manually release this version** so you control launch day, or
   **Automatically release** if you want it live the moment it passes.
3. **Add for Review > Submit**.

## 7. Common first-submission rejections and the fix

- **Guideline 2.1, app crashes**: run on a physical device before archiving.
- **Guideline 4.0, iPad layout**: launch on an iPad simulator in landscape and portrait. The
  SwiftUI layout here adapts, but check it.
- **Guideline 5.1.1, privacy policy missing**: the URL must resolve publicly.
- **Guideline 2.3, screenshots don't match**: screenshots must be of the actual app.

## 8. After approval

- Search for "Kept" on the App Store to confirm it is live; new listings can take a few hours
  to index.
- Sales appear in **App Store Connect > Trends** with a one-day delay.
- Watch **Ratings and Reviews** and respond to the first few. Early reviews weigh heavily.
