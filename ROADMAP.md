# Halo Launcher roadmap

Halo started as a mobile OS on the Linux kernel. It is now an **Android launcher built with Flutter**. The designs in `design/`, the design system (`packages/halo_ui`), the service interface and its mock (`packages/halo_sdk`) and the six screens (now in `launcher/`) carry over. The kernel, init, compositor and embedder work does not.

Phases are sequential, but work can overlap. Each phase lists exit criteria, and a phase is done only when all of them hold.

Legend: ☐ to do · ◐ in progress · ☑ done

---

## Phase 0: Pivot to a launcher
- ☑ README, ROADMAP and CLAUDE.md rewritten for the launcher
- ☑ Fresh git repository (old OS history archived outside the repo as `../halo_os-git-backup-2026-10-26.tar.gz`)
- ☑ Remove the OS-only trees: `system/`, `kernel/`, `embedder/`, `build/`, `tools/`, `third_party/`, `rust-toolchain.toml`, `docs/screenshots/` (the font licenses already live in `packages/halo_ui/assets/licenses`)
- ☑ Rewrite `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` (OS decisions superseded, launcher ones D-017 to D-025), drop `docs/BUILD.md`
- ☑ CI: format, analyze and test for `halo_ui`, `halo_sdk`, `halo_android` and the launcher, plus an Android debug build
- ☑ Pin versions: Flutter 3.47.4 (`.flutter-version`), AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, `minSdk` 29 / `targetSdk` and `compileSdk` 36 (D-018)

**Exit:** a clean checkout contains only the launcher, its packages, the designs and the docs, and CI is green.

## Phase 1: Launcher skeleton on Android
- ☑ Move `shell/` to `launcher/`, add the Android platform, application id (`com.baklavapp.halolauncher`, D-020) and app name (Halo)
- ☑ Register as a home app (`MAIN` + `HOME` intent filter, `singleTask`), and offer to become the default launcher (`RoleManager.ROLE_HOME`) from a Home action card
- ☑ Home button returns to Home Arc; the back gesture never leaves the launcher
- ☑ Edge-to-edge drawing, transparent system bars with icons matching the appearance, launch theme in the Halo ground, safe areas (D-024). Display cutouts in landscape are not handled (the launcher is portrait)
- ◐ Scale the 390-wide design frame to real screen sizes and densities (`DesignFrame`, D-024) ☑ for phones; tablets and foldables ☐
- ☑ Platform plugin `packages/halo_android` (Kotlin, D-019): installed apps via `LauncherApps`, icons, launch, package change events, battery, default home state, Home presses. App info and uninstall move to Phase 3 with the long press
- ☑ `HaloBackend` Android implementation (`AndroidBackend`, the default on Android), with the mock kept for macOS, tests and goldens
- ☑ Keep the macOS mock run working as the fast UI loop

**Exit:** installed on a physical phone, set as the default launcher, Home Arc lists the real installed apps and launches them, and Home returns to the launcher.

*Status (2026-10-26):* met on the Pixel 10 emulator (API 37): Halo set as the home app, the installed apps on the arc with their icons, an app launched from the arc, Home and back return to Halo, both appearances. Not yet tried on a physical phone.

## Phase 2: Design system and screens (carried over)
- ☑ `packages/halo_ui`: tokens (colors, type, notch radii, spacing), bundled fonts, `NotchBorder`, `HaloTheme`
- ◐ Widgets: all done except CommandField ◐ (looks right, no text entry yet): Switch, ToggleRow, Segmented, Slider, Buttons, BatteryLine, BatteryCells, Kicker, Dial, Slats, Timeline, Arc, plus StatusRow, EventCard, ActionCard, AgendaRow, SummaryCard, MediaStrip, Avatar, Chip, icons
- ◐ `packages/halo_sdk` API surface plus the **mock** backend (fixtures matching the design copy: Elif, Design review, Room 3…). Clock, status, next event and notifications so far
- ☑ Screens: Lock, Home Arc, Recents, Switchboard, Stream, System (`launcher/`). System: only Display has designed contents; the other sections say "not designed yet"
- ☑ Navigation and gestures on desktop: hold-to-open, the arc's drag/focus/launch, slat focus and flick-to-close, edge swipes (top right Switchboard, top left Stream, bottom up Home then Recents)
- ◐ Golden tests at 390 × 844 @2x: every screen has one (`launcher/test/goldens/`), compared with `design/screens/*.png` by eye, not by pixel diff. CI skips them (`--exclude-tags golden`)
- ☑ Light appearance: palette, every widget and screen reading it, theme picked from System > Appearance (Auto follows the platform), light goldens against `design/screens/*_light.png`
- ◐ Accessibility pass: semantics labels, text scaling (System > Text size, and Android font scale), reduce motion (Android "remove animations"): built and tested against the semantics tree, 48 dp touch targets, real text size with per-screen caps, reduce motion, screen-reader actions for Stream and the arc (D-036); a by-hand TalkBack pass on a phone is still to do

**Exit:** all six screens match the designs in golden tests in both appearances, and the launcher is fully navigable on macOS with mock data.

## Phase 3: Home Arc with real apps ☑
- ☑ App icons on the arc like `home.png` (D-025): bone glyphs on `surface`, the focused app carbon on Volt. Default apps for the design's roles get the design's glyphs; other apps their monochrome layer or a mask derived from their icon
- ☑ Choose and reorder the apps on the arc, saved on the phone; first filled with the default apps (D-026)
- ☑ More than 7 apps: the arc scrolls, plus the Apps list, **not a grid**: A to Z with letter headings and a letter index, opened by an up swipe on the arc (D-026)
- ☑ Search from the command field, in APPS, CONTACTS and SETTINGS sections: apps (prefix, word, anywhere; Turkish-aware), contacts behind an optional permission asked for from search with "Names stay on this phone", and system settings pages. Go opens the best app, else the best settings page
- ☑ Long press on the arc or in the list: app shortcuts (while Halo is the default home app), Add to / Remove from arc, Move left / right, App info, Uninstall (not for system apps)
- ☑ Work profile apps listed, launched in their profile and marked `WORK`; private space (Android 15+) apps listed while it is unlocked, marked `PRIVATE`, with a lock / unlock row at the end of Apps
- ☑ Home's clean empty state: "Clear for the day" and no `TODAY` heading without events. Real data for "NOW", the agenda and the action card is Phase 4
- ☑ On a phone, an up swipe from the bottom edge of Home opens Apps as well (Recents has nothing to show on Android until Phase 6)

**Exit:** a phone with 100+ apps installed can reach every app from the launcher within two gestures, without a grid.

*Status (2026-10-26): done.* The exit holds: on a Galaxy S20 FE (Android 13, 150 apps, release build) every app is two gestures away (open Apps, then type or jump by letter). Checked there: the arc filled with the default apps, Apps by an up swipe, the letter index, Turkish-aware search with the Samsung keyboard, the keyboard keeping the frame full size. Checked on a Pixel 10 Pro emulator (Android 17): the monochrome focus state, the long-press menu with a real shortcut, Move right, contact search through the permission dialog, opening a contact and a settings page, and locking and unlocking a private space. Not checked on a device: Uninstall's system dialog. The Apps design (D-026) is still a proposal awaiting the owner.

## Phase 3b: Ask Halo, step 1 ☑
- ☑ Tap Ask Halo: search opens with the keyboard up ("find anything": apps, contacts, settings) (D-027)
- ☑ Long press: the assistant the user picked in Android, if any; Halo has no AI of its own (D-012)

## Phase 3c: Status row ☑
- ☑ Halo's status row no longer repeats Android's time, date and battery: `STREAM` (with a Flare dot while something is unread) and `SWITCHBOARD`, each opening its screen; the battery line stays (D-024)

## Phase 4: Calendar and notifications ☑
- ☑ Calendar via `CalendarContract` (`READ_CALENDAR`, asked for from Home's TODAY): Home "NOW", the `TODAY` agenda and the next event, live when the calendar changes. All-day events show as `ALL DAY` and are never the next event
- ☑ `NotificationListenerService` with an onboarding screen in Stream for the special access grant ("Nothing leaves this phone")
- ☑ Stream: the timeline in `NOW` / `EARLIER` with unread (since Stream was last left), the current message (Volt) and alerts (Flare); tap to open, swipe to dismiss on the phone, inline REPLY, LATER snoozes for an hour (D-028); up to two of the app's own actions (Mark as read, Archive…) follow them
- ☑ The Home action card for the newest unread message: Reply opens it in Stream with the reply field ready; Later snoozes it
- ☑ Media sessions (from the listener) for the Switchboard media strip, with play/pause; the progress bar moves each second while a track plays; title above artist
- ☑ "Navigate" opens the maps app at the event's place (hidden without one); for a real event the second button is "Open event" in the calendar app, the design's sample keeps "Open notes"

**Exit:** Stream shows the phone's real notifications, a reply sent from Stream or Home reaches the sender, and dismissing in Halo dismisses on Android.

*Status (2026-10-26):* the exit holds on a Pixel 10 Pro emulator (Android 17): a real SMS showed in Stream and on Home's card, a reply typed in Stream (opened from the card) went out as an SMS to the sender, a swipe cleared it from the phone's notifications, LATER snoozed one, a tap opened Messages, and a calendar event showed on Home the moment it was added. Not yet checked on the Galaxy S20 FE. One crash of Halo's process inside Android's process start (framework frames only, around a reinstall) was seen once and not reproduced.

## Phase 5: Switchboard and System ☑
- ☑ Brightness dial: reads the real level and auto mode, sets it with the `WRITE_SETTINGS` grant; without it the dial reads only and its footer (`TAP TO ALLOW`) opens the grant screen. With the grant the footer turns auto brightness on and off
- ☑ Sound dial: media volume, set directly; the footer shows the ringer mode (`MEDIA · RING`, `VIBRATE`, `SILENT`) read-only
- ☑ Media strip: play/pause, flick left or right across the card to skip. Artwork ☐ (the design has no place for it)
- ☑ Battery line and cells from `BatteryManager`; "full by" from `computeChargeTimeRemaining()` while charging (unit tested; the emulator is at 100%, so not seen on screen)
- ☑ Connection rows (Wi-Fi, Bluetooth, Cellular, Airplane) show the real state and stay in step when it changes; Android doesn't let an app switch them, so the switch opens the matching Settings panel (D-029)
- ☑ Focus row mapped to Do Not Disturb: on and off with notification policy access, which the row asks for when it is missing
- ☑ System screen: Display is the designed one (appearance, text size); Connections, Sound, Focus, Privacy and Battery open the matching Android Settings page, and Privacy lists each optional access (Notifications, Calendar, Contacts, Write settings, Do not disturb) with a switch that opens its grant. Arc apps stay in the Apps menu (D-026)
- ☑ A `Theme` row after Focus (dark on, light off), the rows in a fixed scrolling band, and a `System ›` button in Switchboard's top right: the button is how you reach System in the running launcher

**Exit:** every control on Switchboard reflects real device state and either changes it or opens the right Android screen in one tap.

*Status (2026-10-27):* the exit holds on a Pixel 10 Pro emulator (Android 17): Wi-Fi, Bluetooth, Cellular, Airplane and Focus showed the real state; the Wi-Fi switch opened the Wi-Fi panel and the row followed when Wi-Fi was turned off there; Focus switched Do Not Disturb on and the Sound footer moved to `SILENT`; with Write settings granted a tap on the Light ring set the system brightness (25 % is 63 of 255, auto off) and one on the Sound ring set the media volume; without it the dial read only and its footer opened the grant screen. The System button opened System and the Theme switch flipped the theme both ways (checked before it became a row). On the Galaxy S20 FE the System screen showed the real grants (Notifications, Calendar, Write settings and Do not disturb granted, Contacts not) and `1 ALERT`; the Switchboard there is in use by the owner. Not checked: the "full by" time while charging, nor the "full by" time while charging, nor skip with a real player.

## Phase 6: Recents and the at-a-glance screen ☑
- ☑ Recents from usage events (`PACKAGE_USAGE_STATS`, the user's usage access): up to five slats for the apps used in the last hour (a history of use: Android doesn't tell a launcher which apps are still open), newest left, tap the focused slat to switch to it, flick one up to drop it from Halo's list (it returns once used again; Android lets a launcher close nothing). Without the grant Recents explains and offers it. Work profile apps don't show (their usage isn't visible)
- ☑ Slat previews: the app's icon on a wash of the icon's own color, since a launcher can't read other apps' task snapshots; collapsed slats carry the icon's monochrome mask
- ☑ A route to Recents on Android: a `Recents ›` button in Apps' header (an up swipe on the arc opens Apps). The bottom-edge climb Home, Apps, Recents stays, but gesture navigation gives that strip to Android's own Recents (D-023, proposed)
- ☑ The Lock design as an at-a-glance screen (clock, next event, notification previews), the page left of Home: a swipe right on Home opens it, a swipe left or the hold ring returns (D-021, decided: option A). The Camera shortcut starts the user's camera app. Flashlight ☐ (hidden until it works; `CameraManager.setTorchMode` needs no permission)

**Exit:** Recents and the glance screen work on a phone with only the permissions the user granted.

*Status (2026-10-27):* Recents holds on a Pixel 10 Pro emulator (Android 17): without usage access it asks and the button opens Settings > Usage access; with it, apps opened a moment before showed newest first, each with its icon and a wash of its color, a flick dropped Maps and the next app took the last slot, and a tap on the focused slat brought Settings to the front. Not yet checked on the Galaxy S20 FE. The glance page opened with a swipe right on Home, showed the real clock, the date and a real notification preview with only the Camera shortcut, and a swipe left returned to Home.

## Phase 7: Rule-based Halo (no AI, D-012) ☑ (D-030)
- ☑ Decided: no AI, on the phone or in the cloud (D-012)
- ☑ The Stream summary from rules ("Halo read 11 things for you / 3 need you"): what counts as read, what needs you (replies waiting, missed calls, events soon)
- ☑ The Home "NOW" pick from rules: the next event, else the top message, else "Clear for the day"
- ☑ Notification priority from rules (people over apps, the user's starred contacts, Focus)
- ☑ Ask Halo step 2: rule-based commands typed into the search field ("next", "reply Elif …", "dark", "battery"), shown as results above the search sections

**Exit:** summaries, the NOW pick and commands work offline from Halo's own data, with nothing leaving the phone.

## Phase 8: Release
- ☑ Performance: cold start of the launcher, 60/120 fps on the arc, slats and transitions on a mid-range phone; low memory use so Android doesn't kill the launcher. Release build on the Galaxy SM-G780G (120 Hz, Android 13): the bench holds about 120 fps with build about 1 ms and raster about 2.7 ms (p99 4.6 ms) against an 8.3 ms frame; cold start about 0.53 s; about 156 MB PSS. On the Pixel 10 Pro emulator: cold start about 0.5 s, about 185 MB PSS. Not yet tried on a low-end phone
- ☑ First-run onboarding: set as default, explain and request each permission, and work in a degraded state without any of them (D-031)
- ◐ Privacy policy (notifications, calendar and usage data stay on the device): drafted in `docs/PRIVACY.md`; needs the owner's contact and a public URL
- ◐ Signing, versioning, Play Store listing (or F-Droid), crash reporting that doesn't send personal data: signing reads `key.properties` and versioning is documented (ARCHITECTURE §7); crash reporting is the store's (D-032); waiting on the owner for the keystore, the store choice and the listing

**Exit:** a public beta on the Play Store.

---

## Open questions
- **Lock (D-021):** Android doesn't let a launcher replace the keyguard. Options: an at-a-glance page left of Home, the screen shown right after unlock, or drop it.
- **Recents (D-022):** the system recents (Overview) belongs to the system launcher; third-party launchers can't show live task surfaces or close tasks. Halo's Recents is a recently used apps view; should the system Overview still be reachable?
- **Gestures (D-023):** Android owns the bottom edge (home, Overview) and the side edges (back), and the top edge opens the system shade. Halo's edge swipes need new homes: swipes inside Home (down on the upper area for Stream/Switchboard, up on the arc for Recents) or on-screen affordances.
- **Status bar (D-024):** decided: Android's status bar shows the time and battery; Halo's row leads to Stream and Switchboard.
- **Wallpaper:** "no glass" means the launcher draws its own opaque background. Ignore the system wallpaper, or offer Halo backgrounds only?
- **Apps view (D-026):** built as a list reached by an up swipe on the arc. Still open: the gesture and how much Volt the list carries. Drag-to-reorder on the arc is built (D-035).
- **Min SDK (D-018):** proposed Android 10 (API 29); the code uses 29.
- **Motion spec:** none exists. DESIGN_SYSTEM §8 has interim rules.
- **Brightness curve:** Android's brightness slider isn't linear, and Halo maps its ring straight onto the setting's 0 to 255. Low values may feel off.
- **Ringer mode on the Sound dial:** read-only for now. Silent needs Do Not Disturb access, vibrate does not; should a tap on the footer cycle them?
- **Radios (D-029):** Android doesn't let an app switch Wi-Fi, Bluetooth, mobile data or airplane mode, so those rows open a Settings panel.
- **Notification actions beyond reply:** which ones Stream should show (Mark as read, Archive, Call back), and how without crowding the design.
- **Ask Halo commands:** the first set is `next`, `battery`, `dark`, `light`, `focus` and `reply` (D-030); more to add if wanted.
