# The screen recording App Review asked for

Apple requires a recording made on a **physical iPhone**, not the simulator, running a current
version of iOS. It must start with the app launching and show a typical user flow end to end.

Kept has no accounts, no user-generated content, and no in-app purchases, so none of the three
special cases in Apple's list apply. A single continuous take of about a minute is enough.

## Getting the app onto your phone

### Fastest: straight from the Mac over the cable

No TestFlight, no App Store Connect, no invite email. Plug the phone in with a cable that
carries data, unlock it, and tap **Trust** if the phone asks. Then:

```sh
cd ~/Appsales
git pull
scripts/install_on_phone.sh
```

The script finds the phone, registers it with your developer account, builds, signs, and
installs. If it cannot see the phone it prints the five things to check, in order.

Afterwards the first launch will refuse to open and mention an untrusted developer. That is
expected for a build installed this way. On the phone go to **Settings > General > VPN &
Device Management**, tap your Apple ID, and tap **Trust**. Then open the app normally.

Apple does not care how the app got onto the device. The recording just has to be a real
phone rather than the simulator.

### Fallback: TestFlight

If the cable route will not work, for example because you have no usable cable:

1. On the iPhone, install **TestFlight** from the App Store.
2. In App Store Connect, open the app and click the **TestFlight** tab.
3. Under **Internal Testing**, click **+**, name the group, and add yourself as a tester.
4. In that group click the **Builds** tab, click **+**, and pick the uploaded build.
5. Accept the email invitation on the phone and install through TestFlight.

## Recording

Turn on the recording control once: Settings, Control Center, add **Screen Recording**.

Swipe down from the top-right corner, tap the record button, wait for the countdown, then go to
the home screen before opening the app. Stop it from the red pill at the top of the screen when
you are done. The file lands in Photos.

## What to show, in order

Delete the app and reinstall it first so the recording starts from a genuinely fresh state.
Move slowly, and pause a beat on each screen so the reviewer can read it.

For a 1.0 build:

1. Tap the Kept icon on the home screen. Let the empty first screen sit for two seconds.
2. Tap + in the top right. Type "Drink water". Tap a droplet icon and a blue color. Tap Save.
3. Add a second habit the same way, for example "Read 10 pages".
4. Tap the circle on the first row. It fills in and the streak text updates.
5. Tap the first row to open it. Let the stats and the month calendar sit for three seconds.
6. Tap two or three past days in the calendar. They fill in and the streak numbers change.
7. Tap back, then tap the i button, and let the About screen sit for two seconds.
8. Tap Done. Stop the recording.

For a 2.0 build, add these after step 7, because the widgets are the feature a reviewer is most
likely to miss:

9. Leave the app. Long-press an empty area of the home screen, tap Edit then Add Widget, search
   for Kept, and add the medium widget.
10. On the home screen, tap a check circle inside the widget itself. It fills in without opening
    the app.
11. Open the app to show the same habit now marked done.
12. Hold the side button and say "Mark drink water done in Kept."

## Attaching it

Reply in Resolution Center and attach the video file. If it is too large, put it on any link the
reviewer can open without signing in, such as an unlisted YouTube video or a public file link,
and paste that URL in the reply.
