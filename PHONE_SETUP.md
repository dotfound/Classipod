# PixelPod phone setup

The phone is a Pixel 6a on Android 16, set up as a dedicated iPod. This file
lists what was done over adb, the steps that have to be done by hand, and
how to undo everything.

## Steps to do by hand

1. **Pair Bluetooth headphones.** Open the maintenance exit (below), choose
   "Bluetooth settings", pair the headphones, then press Home. PixelPod
   reopens and the phone relocks.
2. **Remove the SIM, or turn on airplane mode and then turn Wi-Fi back on.**
   Podcasts download over Wi-Fi only by default. Airplane mode is in
   Android Settings → Network and internet, reached from the maintenance
   exit's "Wi-Fi settings".
3. **Set the screen timeout.** Android Settings → Display → Screen timeout
   (reach Settings through the maintenance exit), or from the Mac:

   ```bash
   adb shell settings put system screen_off_timeout 120000
   ```

   The value is in milliseconds. "Dock mode" in PixelPod's Settings keeps
   the screen on while charging instead.
4. **Disable any other apps you do not need.** The Google apps in the table
   below are already disabled. Use the same command for others:
   `adb shell pm disable-user --user 0 <package>`.

## Maintenance exit

The phone boots straight into PixelPod. Home and Recents cannot leave it,
and the status bar and notifications are blocked. To get out for Wi-Fi or
Bluetooth setup:

1. In PixelPod go to Settings → About.
2. Press the centre Select button 7 times.
3. Hold Select for 3 seconds, then let go.
4. Choose "Wi-Fi settings" or "Bluetooth settings".

The phone relocks the next time PixelPod comes to the front (press Home) or
after a reboot. Holding the power button still shows the power menu, so the
phone can be restarted or switched off.

## What was set over adb

- Music copied to `/sdcard/Music/PixelPod/`.
- PixelPod installed as `uk.dotfound.pixelpod` with `adb install -r -t`
  (the app is marked test-only so device owner can be removed, see below).
- Audio and notification permissions granted.
- Battery optimisation exemption:
  `adb shell dumpsys deviceidle whitelist +uk.dotfound.pixelpod`.
- Default home app:
  `adb shell cmd package set-home-activity uk.dotfound.pixelpod/com.adeeteya.classipod.MainActivity`.
- Android's swipe lock screen turned off, so the maintenance exit and Home
  go straight back to PixelPod: `adb shell locksettings set-disabled true`.
- Screen timeout set to 2 minutes:
  `adb shell settings put system screen_off_timeout 120000`.
- Device owner (this is what locks the phone):
  `adb shell dpm set-device-owner uk.dotfound.pixelpod/.PixelPodAdminReceiver`.

## Undoing the lock (no factory reset needed)

With the phone on USB and USB debugging still on:

```bash
adb shell dpm remove-active-admin uk.dotfound.pixelpod/.PixelPodAdminReceiver
```

This works because the app is installed as a test-only app. After it, the
phone behaves as a normal phone with PixelPod as its launcher. To get the
Pixel launcher back, open Android Settings → Apps → Default apps → Home
app, or uninstall PixelPod:

```bash
adb uninstall uk.dotfound.pixelpod
```

## Updating the app

Build on the Mac, then install over the top. Subscriptions, downloads and
positions are kept.

```bash
flutter build apk --release --flavor production --target-platform android-arm64
```

```bash
adb install -r -t build/app/outputs/flutter-apk/app-production-release.apk
```

## Adding podcasts later

Push an OPML file (an AntennaPod export works) to the app's folder, then
choose Settings → Podcasts → Import OPML in PixelPod:

```bash
adb push podcasts.opml /sdcard/Android/data/uk.dotfound.pixelpod/files/podcasts.opml
```

If that file is not there, Import OPML opens Android's file picker, which
only works after the maintenance exit.

## Disabled apps

Each was disabled with `adb shell pm disable-user --user 0 <package>`.
Settings, System UI, Bluetooth, the media provider, Wi-Fi, the keyboard,
the Pixel launcher, the dialler and the clock were left alone.

| Package | Re-enable |
|---|---|
| `com.android.chrome` | `adb shell pm enable com.android.chrome` |
| `com.android.vending` | `adb shell pm enable com.android.vending` |
| `com.google.android.youtube` | `adb shell pm enable com.google.android.youtube` |
| `com.google.android.apps.youtube.music` | `adb shell pm enable com.google.android.apps.youtube.music` |
| `com.google.android.apps.maps` | `adb shell pm enable com.google.android.apps.maps` |
| `com.google.android.gm` | `adb shell pm enable com.google.android.gm` |
| `com.google.android.apps.photos` | `adb shell pm enable com.google.android.apps.photos` |
| `com.google.android.googlequicksearchbox` | `adb shell pm enable com.google.android.googlequicksearchbox` |
| `com.google.android.videos` | `adb shell pm enable com.google.android.videos` |
| `com.google.android.calendar` | `adb shell pm enable com.google.android.calendar` |
| `com.google.android.apps.docs` | `adb shell pm enable com.google.android.apps.docs` |
| `com.google.android.apps.messaging` | `adb shell pm enable com.google.android.apps.messaging` |
| `com.google.android.apps.weather` | `adb shell pm enable com.google.android.apps.weather` |
| `com.google.android.apps.tips` | `adb shell pm enable com.google.android.apps.tips` |
| `com.google.android.apps.recorder` | `adb shell pm enable com.google.android.apps.recorder` |
| `com.google.android.apps.pixel.support` | `adb shell pm enable com.google.android.apps.pixel.support` |
| `com.google.android.projection.gearhead` | `adb shell pm enable com.google.android.projection.gearhead` |
| `com.google.android.contacts` | `adb shell pm enable com.google.android.contacts` |
| `com.google.android.calculator` | `adb shell pm enable com.google.android.calculator` |
