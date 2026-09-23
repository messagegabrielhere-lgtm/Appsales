# When App Review rejects a build

Apple's rejection notice in email only names the guideline. The sentence that says what to
actually fix lives in App Store Connect under the submission, in **Resolution Center**.
Open the app, click the rejected submission, and read the message; it usually names a
device and iOS version and often attaches a screenshot or a crash log.

Start there every time. The guideline number alone is not enough to act on.

## Guideline 2.1 Performance: App Completeness

By far the most common first-submission rejection. It covers four different problems, and
the Resolution Center text tells you which one you have.

| What the message says | What it means | Fix |
| --- | --- | --- |
| "crashed on launch" or "we discovered one or more bugs" | Reviewer hit a crash or a dead end | Get the attached crash log, symbolicate it in Xcode under Window > Organizer, fix, resubmit |
| "we were unable to locate" a feature from your description or screenshots | Metadata promises something the binary does not do | Either cut the claim from the listing or ship a build that has it |
| "placeholder content" | Lorem ipsum, a stock icon, a TODO string, a test bundle id | Replace it |
| "we need a demo account" | The app has a login | Not applicable to Kept; it has no accounts |

### The metadata trap, specifically

Kept's listing copy is versioned on purpose:

- `docs/listing/v1.0.md` describes only what a 1.0 build does.
- `docs/listing/v2.0.md` adds widgets, reminders, rest days, the heatmap, and Siri.

**Never paste v2.0 copy onto a 1.0 binary.** The description would advertise widgets and
Siri that the build does not contain, which is exactly the "unable to locate" rejection.
The same applies to screenshots: the widget screenshot must not appear on a 1.0 listing.

## Replying

Rejection is not the end of the submission; it is a conversation. In Resolution Center you
can reply in the same thread. Two useful moves:

- **If it is a misunderstanding**, reply explaining where the feature is, with steps. No
  new build needed. Review usually answers within a day.
- **If it is a real bug**, fix it, upload a new build with `scripts/release.sh`, attach the
  new build to the version, and resubmit. Say in the reply what changed.

Keep the App Review notes in the listing copy current. Most "unable to locate" rejections
are avoided by spelling out, step by step, how to reach each feature.

## After a rejection, before resubmitting

1. Read the Resolution Center message and note the exact device and iOS version.
2. Reproduce on that device in the simulator.
3. Run the tests: `xcodebuild test -project Kept.xcodeproj -scheme Kept -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'`.
4. Check the listing against the binary, claim by claim.
5. Upload, attach, resubmit.
