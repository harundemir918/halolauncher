# Halo Launcher architecture

Halo is an Android home-screen launcher written in Flutter (D-017). This document covers how the pieces fit. The design language is in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), and the reasons behind choices are in [DECISIONS.md](DECISIONS.md).

## 1. Goals and constraints

- **A normal Android app.** No root, no system signature, no hidden APIs (CLAUDE.md rule 1). What the designs show is bounded by what Android gives a launcher (ROADMAP open questions).
- **One UI codebase, two hosts.** The same screens run on Android with real data and on macOS with fixtures. The macOS mock run stays the fast UI loop.
- **Optional permissions.** Every screen works without notification access, calendar, usage access, write settings or DND access.
- **On-device data.** Notifications, calendar and usage data never leave the phone unless the user opts in.

## 2. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ launcher/            Flutter app (Dart)                      │
│   screens: Lock, Home Arc, Recents, Switchboard, Stream,     │
│   System · EdgeSwipes · DesignFrame · BackendBuilder         │
├──────────────────────────────────────────────────────────────┤
│ packages/halo_ui     tokens, fonts, widgets (Dart)           │
├──────────────────────────────────────────────────────────────┤
│ packages/halo_sdk    HaloBackend interface, models,          │
│                      MockBackend (pure Dart)                 │
├───────────────────────────────┬──────────────────────────────┤
│ packages/halo_android         │ (macOS, tests, goldens)      │
│   AndroidBackend (Dart)       │   MockBackend                │
│   HaloAndroidPlugin (Kotlin)  │                              │
├───────────────────────────────┴──────────────────────────────┤
│ Android framework: LauncherApps, RoleManager, BatteryManager │
│ (later: NotificationListenerService, CalendarContract,       │
│  UsageStatsManager, MediaSession, Settings panels)           │
└──────────────────────────────────────────────────────────────┘
```

Screens depend on `halo_ui` and on the `HaloBackend` interface only. They never call platform channels (CLAUDE.md rule 4).

## 3. The launcher app (`launcher/`)

- **Entry** (`lib/main.dart`): picks the backend (`HALO_BACKEND`, default `android` on Android and `mock` elsewhere) and the start screen (`HALO_START`, default Home on Android and Lock with the mock, D-021). On Android it switches to edge-to-edge drawing first.
- **Navigation:** one `HaloLauncher` state holds the current screen and the open long-press menu. `EdgeSwipes` moves between screens (D-023 decides the Android gestures); on Home, an up swipe in the arc band opens Apps (D-026). A Home press returns to Home; back closes the menu first, then returns to Home, and never leaves the launcher.
- **Apps and the menu** (`lib/apps/`, `lib/app_menu.dart`, D-026): the Apps list and search use `searchApps` from `halo_sdk`; the menu is drawn inside the design frame over the current screen, so it scales with it and needs no route.
- **Design frame** (`lib/design_frame.dart`, D-024): screens are laid out on the 390-wide design frame inside the safe area, scaled by width, so absolute positions from the `.dc.html` sources keep working. The frame's height is whatever the safe area leaves at that scale; content tied to the arc is anchored from the bottom.
- **State:** plain Dart (D-015). `BackendBuilder` rebuilds on `HaloBackend.changes`; screen-local state lives in `State` objects.
- **Android manifest:** `MAIN` + `HOME` + `DEFAULT` intent filter, `singleTask`, `clearTaskOnLaunch`, `stateNotNeeded`, `excludeFromRecents`, no wallpaper (`windowShowWallpaper=false`; "no glass"). The launch and normal themes paint the Halo ground so a return to Home never flashes white or black.

## 4. The platform layer (`packages/halo_android`, D-019)

A Flutter plugin with a Kotlin side and a Dart side.

| Channel | Direction | Contents |
|---|---|---|
| `halo_android` (method) | Dart → Kotlin | `apps`, `icons {ids, size}`, `launch {id}`, `defaultApps`, `roles`, `getPref {key}`, `setPref {key, value}`, `shortcuts {id}`, `startShortcut {id, shortcut}`, `appInfo {id}`, `uninstall {id}`, `openSettings {id}`, `canSearchContacts`, `requestContacts`, `searchContacts {query}`, `openContact {id}`, `privateSpace`, `setPrivateSpaceLocked {locked}`, `openAssistant`, `battery`, `isDefaultHome`, `requestDefaultHome` |
| `halo_android/events` (event) | Kotlin → Dart | `{type: apps \| home \| battery \| defaultHome \| contacts}` |

- **Apps:** `LauncherApps.getActivityList` for every profile (`LauncherApps.profiles`), minus Halo, sorted by label, with `work` and `canUninstall` (false for system apps that weren't updated). The id is the short flattened component name (`com.example/.MainActivity`), with `#<user serial>` for another profile. Package changes come from `LauncherApps.Callback`. Manifest `<queries>` provide package visibility on Android 11+ for launcher entries and for the default-app roles.
- **Arc and settings:** saved in the app's `SharedPreferences` (`halo`) through `getPref`/`setPref`: the arc as a JSON list of ids, plus `appearance` and `textSize`. With no saved arc, `defaultApps` resolves the user's maps, music, SMS, camera, browser and dialer apps (D-026). Ids of apps that are gone stay saved but aren't shown.
- **Search sources:** contacts through `ContactsContract.Contacts.CONTENT_FILTER_URI` (at most five, off the main thread), only with `READ_CONTACTS`, requested from search; after a permanent no, Halo's App info opens instead. Settings pages map the shared ids in `halo_sdk` (`defaultSettingsPages`) to `android.provider.Settings` actions, falling back to Settings itself.
- **Private space** (Android 15+, `ACCESS_HIDDEN_PROFILES`): found by `LauncherApps.getLauncherUserInfo(...).userType`; its apps are left out while it is in quiet mode, and `requestQuietModeEnabled` locks and unlocks it. Profile availability broadcasts send `apps`.
- **Ask Halo's long press:** `openAssistant` starts `ACTION_ASSIST`, else `ACTION_VOICE_COMMAND`, the user's own assistant app; Halo has none (D-012, D-027).
- **Shortcuts, App info, uninstall:** `LauncherApps.getShortcuts`/`startShortcut` (Android only allows these to the default home app), `startAppDetailsActivity`, and `ACTION_DELETE` (`REQUEST_DELETE_PACKAGES`; the system asks the user).
- **Icons:** rendered off the main thread to 144 px PNGs, plus a monochrome mask as `mono`: the adaptive icon's monochrome layer (Android 13+) or one derived from the icon, cleaned to white with near-invisible pixels dropped. The arc tints it like the design's glyphs (D-025). `roles` names the user's default app for each design role (maps, music, messages, camera, web, phone); those apps are drawn with the design's glyphs. Adaptive icons are drawn full bleed without the system mask (cropped to the visible 72 of 108 dp) so Flutter can mask them to a circle; legacy icons are inset (D-025). Icons load after the list; only new ids are fetched on a package change.
- **Launch:** `LauncherApps.startMainActivity`.
- **Default home:** `RoleManager.ROLE_HOME`; the request falls back to the Home settings screen. The state is re-read when Halo resumes, since the user can change it in Settings.
- **Home press:** `onNewIntent` with `ACTION_MAIN` + `CATEGORY_HOME` → `home` event → `HaloBackend.homePressed`.
- **What isn't served yet** is empty, not invented: no agenda, notifications or Recents until Phases 4 and 6. Switchboard values are held in memory until Phase 5.

`AndroidBackend.create()` loads apps, battery and the default home state before the first frame, so Home never paints an empty arc.

## 5. Testing

- `halo_ui`: widget tests per widget.
- `halo_sdk`: unit tests for the mock.
- `halo_android`: `AndroidBackend` against mocked channels (`test/android_backend_test.dart`).
- `launcher`: widget tests per screen, navigation and launcher behavior (`test/launcher_test.dart`, including every screen with empty data), Apps, search and the menu (`test/apps_test.dart`), and golden tests at 390 × 844 in both appearances (skipped in CI, compared by eye).
- On a device or emulator: install the debug APK, set Halo as the home app, launch an app from the arc, and press Home.

## 6. Versions

Flutter 3.47.4 (`.flutter-version`), Android Gradle Plugin 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, Java 17 bytecode. `minSdk` 29, `targetSdk` and `compileSdk` 36 (D-018). Application id `com.baklavapp.halolauncher` (D-020).
