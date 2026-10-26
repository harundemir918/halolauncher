# Halo Launcher roadmap

Halo started as a mobile OS on the Linux kernel. It is now an **Android launcher built with Flutter**. The designs in `design/`, the design system (`packages/halo_ui`), the service interface and its mock (`packages/halo_sdk`) and the six screens in `shell/` carry over. The kernel, init, compositor and embedder work does not.

Phases are sequential, but work can overlap. Each phase lists exit criteria, and a phase is done only when all of them hold.

Legend: ☐ to do · ◐ in progress · ☑ done

---

## Phase 0: Pivot to a launcher
- ☑ README, ROADMAP and CLAUDE.md rewritten for the launcher
- ☑ Fresh git repository (old OS history archived outside the repo as `../halo_os-git-backup-2026-10-26.tar.gz`)
- ☑ Remove the OS-only trees: `system/`, `kernel/`, `embedder/`, `build/`, `tools/`, `third_party/`, `rust-toolchain.toml`, `docs/screenshots/` (the font licenses already live in `packages/halo_ui/assets/licenses`)
- ☐ Rewrite `docs/ARCHITECTURE.md` (launcher app, platform channels, `halo_sdk` backends, Android permissions) and `docs/DECISIONS.md` (close the OS decisions, add the launcher ones: min SDK, Lock, Recents, gestures). Drop or replace `docs/BUILD.md`
- ◐ CI: Dart only (format, analyze, test for `halo_ui`, `halo_sdk` and the launcher) ☑, plus an Android debug build ☐
- ☐ Pin versions: Flutter (`.flutter-version`), Android Gradle Plugin, Kotlin, `compileSdk` / `targetSdk` / `minSdk`

**Exit:** a clean checkout contains only the launcher, its packages, the designs and the docs, and CI is green.

## Phase 1: Launcher skeleton on Android
- ☐ Move `shell/` to `launcher/`, add the Android platform, application id and app name
- ☐ Register as a home app (`MAIN` + `HOME` intent filter, `singleTask`), and offer to become the default launcher (`RoleManager.ROLE_HOME`)
- ☐ Home button returns to Home Arc; the back gesture never leaves the launcher
- ☐ Edge-to-edge drawing, system bar colors from the Halo palette, safe areas and display cutouts
- ☐ Scale the 390-wide design frame to real screen sizes and densities (phones first; tablets and foldables later)
- ☐ Platform channel package (Kotlin): installed apps via `LauncherApps`, launch, app info, uninstall, package change events
- ☐ `HaloBackend` Android implementation (`HALO_BACKEND=android`), with the mock kept for macOS, tests and goldens
- ☐ Keep the macOS mock run working as the fast UI loop

**Exit:** installed on a physical phone, set as the default launcher, Home Arc lists the real installed apps and launches them, and Home returns to the launcher.

## Phase 2: Design system and screens (carried over)
- ☑ `packages/halo_ui`: tokens (colors, type, notch radii, spacing), bundled fonts, `NotchBorder`, `HaloTheme`
- ◐ Widgets: all done except CommandField ◐ (looks right, no text entry yet): Switch, ToggleRow, Segmented, Slider, Buttons, BatteryLine, BatteryCells, Kicker, Dial, Slats, Timeline, Arc, plus StatusRow, EventCard, ActionCard, AgendaRow, SummaryCard, MediaStrip, Avatar, Chip, icons
- ◐ `packages/halo_sdk` API surface plus the **mock** backend (fixtures matching the design copy: Elif, Design review, Room 3…). Clock, status, next event and notifications so far
- ☑ Screens: Lock, Home Arc, Recents, Switchboard, Stream, System (`shell/`). System: only Display has designed contents; the other sections say "not designed yet"
- ☑ Navigation and gestures on desktop: hold-to-open, the arc's drag/focus/launch, slat focus and flick-to-close, edge swipes (top right Switchboard, top left Stream, bottom up Home then Recents)
- ◐ Golden tests at 390 × 844 @2x: every screen has one (`shell/test/goldens/`), compared with `design/screens/*.png` by eye, not by pixel diff. CI skips them (`--exclude-tags golden`)
- ☑ Light appearance: palette, every widget and screen reading it, theme picked from System > Appearance (Auto follows the platform), light goldens against `design/screens/*_light.png`
- ☐ Accessibility pass: semantics labels, text scaling (System > Text size, and Android font scale), reduce motion (Android "remove animations")

**Exit:** all six screens match the designs in golden tests in both appearances, and the launcher is fully navigable on macOS with mock data.

## Phase 3: Home Arc with real apps
- ☐ Real app icons, drawn as circles (adaptive icons masked to a circle; monochrome/themed icons for the Volt focus state)
- ☐ Choose and reorder the apps on the arc; persist the choice
- ☐ More than 7 apps: the arc scrolls, plus an "all apps" view that is **not a grid** (see open questions)
- ☐ App search from the command field (letters to apps, then contacts and settings later)
- ☐ Long press: app shortcuts (`LauncherApps.getShortcuts`), app info, uninstall
- ☐ Work profile and private space apps, marked as such
- ☐ Home "NOW", agenda and action card fed by real data (Phase 4), with a clean empty state when permissions are missing

**Exit:** a phone with 100+ apps installed can reach every app from the launcher within two gestures, without a grid.

## Phase 4: Calendar and notifications
- ☐ Calendar via `CalendarContract` (`READ_CALENDAR`): Home "NOW", the `TODAY` agenda and the next-event card
- ☐ `NotificationListenerService` with an onboarding flow for the special access grant
- ☐ Stream: the timeline in `NOW` / `EARLIER`, unread (Flare), open, dismiss, inline reply and notification actions
- ☐ The Home action card for the top message, wired to the notification's reply action
- ☐ Media sessions (from the listener) for the Switchboard media strip

**Exit:** Stream shows the phone's real notifications, a reply sent from Stream or Home reaches the sender, and dismissing in Halo dismisses on Android.

## Phase 5: Switchboard and System
- ☐ Brightness dial (`WRITE_SETTINGS` grant, auto-brightness toggle)
- ☐ Sound dial (media volume, ringer mode)
- ☐ Media strip: play/pause, skip, artwork from the active media session
- ☐ Battery line and cells from `BatteryManager`; "full by" estimate while charging
- ☐ Connection rows (Wi-Fi, Bluetooth, Cellular, Airplane): show the real state; toggle where the API allows, otherwise open the Android Settings panel
- ☐ Focus row mapped to Do Not Disturb (notification policy access)
- ☐ System screen: launcher settings (appearance, text size, arc apps, permissions status) plus shortcuts into the Android Settings pages for the other sections

**Exit:** every control on Switchboard reflects real device state and either changes it or opens the right Android screen in one tap.

## Phase 6: Recents and the at-a-glance screen
- ☐ Recents from `UsageStatsManager` (usage access grant): slats for recently used apps, tap to switch; flick up removes from Halo's list
- ☐ Slat previews: app icon and color, since a launcher can't read other apps' task snapshots
- ☐ The Lock design as an at-a-glance screen (clock, next event, notification previews); how it is reached is an open question

**Exit:** Recents and the glance screen work on a phone with only the permissions the user granted.

## Phase 7: Halo intelligence
- ☐ Decide on-device versus cloud and the privacy model
- ☐ Rule-based first: the Stream summary ("Halo read 11 things for you / 3 need you"), the Home "NOW" pick, notification priority
- ☐ Ask Halo from the Home arc (voice and text), or hand off to the default assistant
- ☐ The rule-based path stays as the fallback when no model is available

**Exit:** summaries run within the latency and privacy budgets, with no data leaving the device unless the user opts in.

## Phase 8: Release
- ☐ Performance: cold start of the launcher, 60/120 fps on the arc, slats and transitions on a mid-range phone; low memory use so Android doesn't kill the launcher
- ☐ First-run onboarding: set as default, explain and request each permission, and work in a degraded state without any of them
- ☐ Privacy policy (notifications, calendar and usage data stay on the device)
- ☐ Signing, versioning, Play Store listing (or F-Droid), crash reporting that doesn't send personal data

**Exit:** a public beta on the Play Store.

---

## Open questions
- **Lock:** Android doesn't let a launcher replace the keyguard. Options: an at-a-glance page left of Home, the screen shown right after unlock, or drop it.
- **Recents:** the system recents (Overview) belongs to the system launcher; third-party launchers can't show live task surfaces or close tasks. Halo's Recents is a recently used apps view; should the system Overview still be reachable?
- **Gestures:** Android owns the bottom edge (home, Overview) and the side edges (back), and the top edge opens the system shade. Halo's edge swipes need new homes: swipes inside Home (down on the upper area for Stream/Switchboard, up on the arc for Recents) or on-screen affordances.
- **Status bar:** keep the system status bar, or hide it on Home and draw the Halo `StatusRow` instead.
- **Wallpaper:** "no glass" means the launcher draws its own opaque background. Ignore the system wallpaper, or offer Halo backgrounds only?
- **Arc with more than 7 apps** and an "all apps" view that respects "no grid".
- **Min SDK:** proposal: Android 10 (API 29) or later.
- **Motion spec:** none exists. DESIGN_SYSTEM §8 has interim rules.
- **AI approach** for summaries and Ask Halo.
