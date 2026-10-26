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
- **Navigation:** one `HaloLauncher` state holds the current screen. `EdgeSwipes` moves between screens (D-023 decides the Android gestures). A Home press and the back gesture both return to Home; back never leaves the launcher.
- **Design frame** (`lib/design_frame.dart`, D-024): screens are laid out on the 390-wide design frame inside the safe area, scaled by width, so absolute positions from the `.dc.html` sources keep working. The frame's height is whatever the safe area leaves at that scale; content tied to the arc is anchored from the bottom.
- **State:** plain Dart (D-015). `BackendBuilder` rebuilds on `HaloBackend.changes`; screen-local state lives in `State` objects.
- **Android manifest:** `MAIN` + `HOME` + `DEFAULT` intent filter, `singleTask`, `clearTaskOnLaunch`, `stateNotNeeded`, `excludeFromRecents`, no wallpaper (`windowShowWallpaper=false`; "no glass"). The launch and normal themes paint the Halo ground so a return to Home never flashes white or black.

## 4. The platform layer (`packages/halo_android`, D-019)

A Flutter plugin with a Kotlin side and a Dart side.

| Channel | Direction | Contents |
|---|---|---|
| `halo_android` (method) | Dart → Kotlin | `apps`, `icons {ids, size}`, `launch {id}`, `battery`, `isDefaultHome`, `requestDefaultHome` |
| `halo_android/events` (event) | Kotlin → Dart | `{type: apps \| home \| battery \| defaultHome}` |

- **Apps:** `LauncherApps.getActivityList` for the current user, minus Halo, sorted by label. The id is the short flattened component name (`com.example/.MainActivity`). Package changes come from `LauncherApps.Callback`. Manifest `<queries>` for `MAIN`/`LAUNCHER` provides package visibility on Android 11+.
- **Icons:** rendered off the main thread to 144 px PNGs. Adaptive icons are drawn full bleed without the system mask (cropped to the visible 72 of 108 dp) so Flutter can mask them to a circle; legacy icons are inset (D-025). Icons load after the list; only new ids are fetched on a package change.
- **Launch:** `LauncherApps.startMainActivity`.
- **Default home:** `RoleManager.ROLE_HOME`; the request falls back to the Home settings screen. The state is re-read when Halo resumes, since the user can change it in Settings.
- **Home press:** `onNewIntent` with `ACTION_MAIN` + `CATEGORY_HOME` → `home` event → `HaloBackend.homePressed`.
- **What isn't served yet** is empty, not invented: no agenda, notifications or Recents until Phases 4 and 6. Switchboard and System values are held in memory until Phase 5.

`AndroidBackend.create()` loads apps, battery and the default home state before the first frame, so Home never paints an empty arc.

## 5. Testing

- `halo_ui`: widget tests per widget.
- `halo_sdk`: unit tests for the mock.
- `halo_android`: `AndroidBackend` against mocked channels (`test/android_backend_test.dart`).
- `launcher`: widget tests per screen, navigation and launcher behavior (`test/launcher_test.dart`, including every screen with empty data), and golden tests at 390 × 844 in both appearances (skipped in CI, compared by eye).
- On a device or emulator: install the debug APK, set Halo as the home app, launch an app from the arc, and press Home.

## 6. Versions

Flutter 3.47.4 (`.flutter-version`), Android Gradle Plugin 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, Java 17 bytecode. `minSdk` 29, `targetSdk` and `compileSdk` 36 (D-018). Application id `com.harundemir.halolauncher` (D-020).
