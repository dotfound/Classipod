# PixelPod — one-session build plan

Turn an old Pixel into a dedicated iPod Classic: click wheel, haptics, iPod
styling, local music, podcasts that auto-download when feeds update, and an
Up Next queue that mixes songs and episodes.

Base: a fork of github.com/adeeteya/Classipod (Flutter, open source). It
already has the click wheel, haptics, click sounds, Cover Flow, iPod skins,
background playback and lock-screen controls. This session adds podcasts,
background auto-download, Up Next, and loads the phone.

**How to start the session (prompt for Claude Code, run in the fork's root):**

> Read AGENTS.md and BUILD_PLAN.md. Work through the steps in order, run the
> checks at the end of each step, and commit after each one. Ask me for the
> three inputs before you start Step 1.

---

## Inputs (collect before Step 1)

1. **Music folder** on the laptop (absolute path).
2. **Podcast list**: either `podcasts.opml` (exported from AntennaPod),
   or `podcasts.txt` with names or feed URLs, one per line. Put it in the
   repo root. Prefer the OPML when both exist; names are resolved in
   Step 4.
3. **Phone connected** by USB with Developer options → USB debugging on.
   `adb devices` shows it as `device`, not `unauthorized`.

## Definition of done

All of these are verified on the phone, not just in tests:

- [ ] App installs as its own app (**PixelPod**), alongside or instead of
      store ClassiPod, and opens to the iPod main menu.
- [ ] Main menu: Music, Podcasts, Settings, Shuffle Songs, Now Playing, with
      haptics and click sounds on.
- [ ] The whole music folder is on the phone and browsable by Artists,
      Albums, Songs and Cover Flow, with artwork.
- [ ] Every podcast in `podcasts.txt` is subscribed on first launch with no
      typing on the phone.
- [ ] The newest 3 episodes of each show download automatically over Wi-Fi.
- [ ] A new episode appearing in a feed downloads in the background with the
      app closed (proved with the forced-run check in Step 10).
- [ ] Episodes resume where they were left off, are marked played near the
      end, and support 1× / 1.25× / 1.5× / 2× speed.
- [ ] "Play Next" and "Add to Up Next" work for songs, albums and episodes.
      Up Next plays before the rest of the current queue and can mix both.
- [ ] Played episodes' files are cleaned up automatically.
- [ ] The phone is dedicated to PixelPod: it boots straight into it, Home
      and Recents can't leave it, and the status bar and notifications are
      blocked.
- [ ] A hidden maintenance exit (Step 9b) unlocks the phone for Wi-Fi or
      Bluetooth setup, and it relocks on the next launch.
- [ ] `flutter analyze` is clean, and `flutter test` passes.

---

## Step 0 — Toolchain and phone check (stop and report if anything fails)

- `flutter --version`: the repo pins Flutter in `pubspec.yaml`
  (`environment.flutter`). Switch to that version (e.g. via fvm) if needed.
- `flutter doctor`: the Android toolchain is OK. `android/app/build.gradle*`
  uses `compileSdk = 37`, so install that platform if it's missing.
- `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`,
  `flutter gen-l10n`, `flutter analyze`, `flutter test`: the baseline is green
  before any changes.
- `adb shell getprop ro.build.version.release`: note the phone's Android
  version.
- `adb shell dumpsys account | grep -c "Account {"` should be 0. Device
  owner (Step 9b) only works on a phone with no accounts. If any exist,
  stop and ask G to factory reset, then set it up with Wi-Fi only (skip the
  Google account) and re-enable USB debugging.
- `adb shell df /sdcard`: free space versus `du -sh <music folder>`. If the
  music won't fit, stop and ask.

## Step 1 — Make it our app

- Change the Android `applicationId` to `uk.dotfound.pixelpod`, and the app
  label to "PixelPod".
- Android only. Don't touch other platforms, and don't rely on the upstream
  release workflow, because it needs signing secrets.
- Build signing: if release signing requires `key.properties`, generate a
  local keystore outside the repo (gitignored) and wire it up. If that's
  fiddly, ship a debug-signed release build. Don't spend long here.
- Check: `flutter build apk` succeeds, then `adb install -r` it, and it
  launches.

## Step 2 — Podcast data and feeds

New code lives in `lib/core/podcasts/` and `lib/features/podcasts/`, following
AGENTS.md conventions.

- Hive CE models (register the adapters, regenerate):
  - `PodcastShow`: feedUrl (key), title, author, artworkUrl,
    localArtworkPath, lastRefreshed, etag, lastModified, autoDownload
    (default true), keepLatest (default 3).
  - `PodcastEpisode`: id (guid, else enclosure URL), showFeedUrl, title,
    description (plain text), pubDate, enclosureUrl, durationSeconds,
    localPath?, downloadState (none/queued/downloading/done/failed),
    positionSeconds, isPlayed, playedAt?.
- `PodcastFeedClient`: fetch with the existing `http` package, sending
  If-None-Match / If-Modified-Since so unchanged feeds are cheap. Parse RSS
  with the `xml` package:
  - `itunes:duration` can be seconds, MM:SS or HH:MM:SS.
  - Prefer `itunes:image` over `<image><url>`.
  - Strip HTML from descriptions.
  - Skip items with no audio enclosure.
- `PodcastRepository`: subscribe (URL), unsubscribe (deletes files),
  refreshAll / refreshOne. Merge by episode id, never duplicate, and keep
  local state on refresh.
- Tests in `test/unit_tests/`: three fixture feeds (normal; odd duration
  formats; missing guids), merge-without-duplicates, and 304 handling.

## Step 3 — Downloads and background auto-download

- `PodcastDownloadService`: one download at a time, streamed to
  `getApplicationDocumentsDirectory()/podcasts/<showHash>/<episodeHash>.<ext>`.
  Write to `.part` and rename when complete. Progress goes to a Riverpod
  provider, and failures are retried on the next run. App-private storage
  keeps episodes out of the music library scan.
- Auto-download rule, after every refresh: for each show with autoDownload
  on, queue the newest `keepLatest` unplayed episodes that aren't
  downloaded yet.
- Cleanup rule: delete files of episodes played more than 24h ago. Never
  delete in-progress episodes.
- Background: `workmanager` periodic task every 2 hours, constrained to
  unmetered network. It runs refresh → auto-download → cleanup headlessly
  (initialise Hive in the callback). Also run the same pipeline on app start,
  throttled to once per 30 min, and from a "Refresh" row in Podcasts.
- Ask for the notification permission (Android 13+) if a notification is
  needed for the worker. Request the battery-optimisation exemption with the
  repo's existing `disable_battery_optimization` package.
- Add a debug-only hidden Settings row, "Run podcast sync now", for testing.

## Step 4 — Seed subscriptions from podcasts.txt

- If `podcasts.opml` exists, validate each feed URL (fetch and parse it).
  Copy the valid ones into the seed and report any that fail, then skip the
  name lookup.
- Otherwise, script `tool/build_seed_opml.dart`: for each line of
  `podcasts.txt`, use
  it directly if it's a URL. Otherwise query
  `https://itunes.apple.com/search?media=podcast&limit=3&term=<name>`, take
  the top match's `feedUrl`, and print the matched title so G can confirm.
  If a match is ambiguous, list the top 3 and ask G to pick.
- Write `assets/podcasts_seed.opml` and register it in `pubspec.yaml`.
- On first launch, import the seed OPML once (store a flag in
  shared_preferences), then run the sync pipeline immediately.
- In-app adding for later: Settings → Podcasts → "Add feed URL" (reuse
  `custom_input_text_screen.dart`) and "Import OPML" (`file_picker`).

## Step 5 — Podcast screens (click-wheel native)

Use `CustomScreen` + `DisplayListTile`, like `music_menu_screen.dart`. New
strings go in `lib/l10n/app_en.arb` only.

- **Main menu:** add **Podcasts** between Music and Settings.
- **Podcasts:** shows sorted by newest episode, with a blue dot if any are
  unplayed. The last row is Refresh.
- **Show:** episodes newest first. Each shows a blue dot (unplayed), a half
  dot (in progress), and a download state or percentage.
  - Select plays the episode if downloaded, otherwise downloads it then plays.
  - More-options modal: Play Next, Add to Up Next, Download / Delete
    download, Mark played / unplayed, Unsubscribe.
- **Settings → Podcasts:**
  - Wi-Fi only (default on)
  - Episodes to keep per show (default 3)
  - Storage used
  - Delete all played

## Step 6 — Playing episodes

- Map an episode to the track model the playback handler uses
  (`MusicMetadata` / `library_audio_handler.dart`). Use show as album,
  author as artist, local artwork, and the file path as the source. Add an
  `isPodcastEpisode` flag (or an episode id field) rather than a parallel
  player.
- Selecting an episode plays it as its own queue. Episodes never enter
  Shuffle Songs or the music library lists.
- Resume from `positionSeconds`. Save position every 10s, on pause, stop
  and track change. Mark played at ≥95% or the last 60s.
- Now Playing shows the show and episode title. More options adds speed
  (`setSpeed`), shown for episodes only and remembered per show. Reset speed
  to 1× for songs.

## Step 7 — Up Next queue (songs and episodes)

- Implement Up Next as a separate ordered list in the playback layer,
  consulted before advancing the existing `LogicalQueue`:
  - **Play Next** inserts at the front of Up Next.
  - **Add to Up Next** appends to it.
  - When the current track ends, if Up Next is non-empty, play and remove
    its head, then fall back to the normal queue.
  - Shuffle and repeat apply to the normal queue only.
- Add Play Next and Add to Up Next to the more-options modals for songs,
  albums (adds all tracks in order), playlists and episodes.
- **Up Next screen** under Now Playing's more options. It lists items, and
  selecting one gives Remove, Move to top and Clear Up Next.
- Persist Up Next across restarts, alongside the existing session restore.
- Episodes played from Up Next still save position and mark played.
- Tests: ordering, fallthrough to the normal queue, persistence, and mixed
  song/episode items.

## Step 8 — Load the music

- `adb push "<music folder>/." /sdcard/Music/PixelPod/` (show progress; this
  can take a while).
- Trigger a media scan: on Android 10+, run
  `adb shell content call --method scan_volume --uri content://media --arg external_primary`.
  Then open the app and use its library rescan.
- Check the song count in the app against `find <music folder> -type f \(
  -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.flac' -o -iname '*.ogg' \)
  | wc -l`. If more than a handful are missing, use the app's
  missing-tracks screen to find out why.

## Step 9 — Install and set up the phone as an iPod

- `flutter build apk --release`, then `adb install -r -t`, then grant audio
  and notification permissions.
- Confirm in the app's settings that haptics and click sounds are on, and
  choose a device colour.
- Set the battery-optimisation exemption for PixelPod.
- Write a short `PHONE_SETUP.md` for G with the manual steps adb can't do:
  - pair Bluetooth headphones via the maintenance exit
  - remove the SIM / airplane mode with Wi-Fi on
  - disable the Google apps not needed
  - set the screen timeout

## Step 9b — Make PixelPod the whole phone

- **Home launcher:** add a `HOME` + `DEFAULT` intent-filter to the main
  activity. The phone then boots into PixelPod, and the Home button returns
  to it. Set it as the default home app, via
  `adb shell cmd package set-home-activity uk.dotfound.pixelpod/<activity>`
  or by tapping Home once.
- **Device owner + lock task mode:**
  - Add a minimal `DeviceAdminReceiver` (Kotlin, in `android/`) and its
    `device_admin.xml`.
  - Install, then run
    `adb shell dpm set-device-owner uk.dotfound.pixelpod/.PixelPodAdminReceiver`.
  - On launch, the app whitelists itself with `setLockTaskPackages` and
    calls `startLockTask()`, so the status bar, notifications, Recents and
    other apps are unavailable.
  - Also set `setStatusBarDisabled(true)`, and keep the screen on while
    charging if G wants a dock mode (setting, default off).
  - Expose this through a small platform channel; keep it in one file.
- **Maintenance exit:** in Settings → About, select "Version" 7 times, then
  hold Select for 3s. This calls `stopLockTask()` and opens Android Wi-Fi or
  Bluetooth settings (offer both as a two-row menu). The next app launch or
  reboot relocks.
- **Debloat:**
  - `adb shell pm disable-user --user 0 <pkg>` for unneeded Google and
    carrier apps: Chrome, YouTube, Maps, Gmail, Photos, Assistant/Google app,
    Play Store and similar. Log every package disabled to
    `PHONE_SETUP.md` with the matching `pm enable` command.
  - Never disable Settings, System UI, Bluetooth, the media provider,
    Wi-Fi or the keyboard.
- **Escape hatch for G:** mark the app `android:testOnly="true"` and
  install with `adb install -r -t`. Device owner can then be removed with
  `adb shell dpm remove-active-admin uk.dotfound.pixelpod/.PixelPodAdminReceiver`
  rather than needing a factory reset. Document both in `PHONE_SETUP.md`.

## Step 10 — Verify on device (Definition of done)

- Go through every Definition of done item on the phone.
- Reboot the phone. It should come up in PixelPod. Home, Recents and
  pulling down the status bar all do nothing. Then use the maintenance exit
  to reach Bluetooth settings, and relaunch to relock.
- **Background auto-download proof:**
  1. Delete one show's newest downloaded episode and mark it unplayed.
  2. Close the app.
  3. Force the worker with
     `adb shell cmd jobscheduler run -f uk.dotfound.pixelpod <jobId>`
     (find the id with `adb shell dumpsys jobscheduler | grep pixelpod`),
     or use the debug "Run podcast sync now" row and then kill the app.
  4. Confirm the file reappears.
- Report back: what passed, anything that didn't, and the APK path.

---

## Guardrails

- After each step, run `flutter analyze` and `flutter test`, then commit
  with an emoji-prefixed message per AGENTS.md.
- Don't refactor existing ClassiPod code beyond what a step needs.
- If time runs short, cut in this order:
  1. Up Next persistence
  2. Up Next reordering (keep Play Next / Add / Clear)
  3. Storage-used row
  4. Per-show speed memory (keep global speed)

  Never cut background auto-download, resume, or the seed import.
- Out of scope: video podcasts, chapters, in-app podcast search, streaming
  without download, cloud sync.
