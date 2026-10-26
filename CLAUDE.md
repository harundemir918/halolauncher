# CLAUDE.md

Guide for AI agents and contributors working in this repository.

## What this is

**Halo Launcher** is an **Android home-screen launcher built with Flutter**. It brings the Halo design language (no grid, no glass, no dock; apps on an arc, one notification stream, controls that look like controls) to stock Android phones.

The project began as Halo OS, a mobile OS on the Linux kernel. The owner has moved it to a launcher. What carries over: the designs in `design/`, the design system `packages/halo_ui`, the service interface and mock backend `packages/halo_sdk`, and the six screens (now in `launcher/`). The kernel, init, compositor and embedder work does not carry over.

Current status: **pre-alpha.** On Android, Halo can become the default home app, lists the installed apps on the arc with their icons and launches them; the other screens are empty there until their phases land. All six screens run on macOS against mock data. Check [ROADMAP.md](ROADMAP.md) for the active phase before starting work, and tick off items (☐ → ◐ → ☑) as you complete them.

## Read first

| Doc | Read it when |
|---|---|
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | You touch any UI (launcher screens, `halo_ui`) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | You touch the platform layer, `halo_sdk`, navigation or the Android manifest |
| `design/` | Visual truth. PNGs for looks, `.dc.html` sources for exact numbers (see `design/README.md`) |
| [ROADMAP.md](ROADMAP.md) | Before starting work. The open questions list what Android doesn't allow a launcher to do |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Before you make or change an architectural choice |

In `docs/DECISIONS.md`, D-001 to D-016 date from Halo OS; the ones marked *Superseded* are history only. The launcher decisions start at D-017.

## Hard rules

1. **A normal Android app.** The launcher must work as a regular app installed from a store: no root, no system signature, no hidden or reflection-based APIs, no privileged permissions. When Android doesn't allow something the design shows, degrade cleanly (show state read-only, or open the right Android Settings screen) and note it in ROADMAP open questions. Don't fake it.
2. **Don't silently change decisions.** Decisions marked *Decided* in `docs/DECISIONS.md` are the owner's call, so don't contradict them. Decisions marked *Proposed* may be challenged: write the case in DECISIONS.md and ask, don't just change course in code.
3. **Design fidelity.** UI must follow `docs/DESIGN_SYSTEM.md`:
   - **No grid, no glass, no dock.** No icon grids (the "all apps" view too), no `BackdropFilter`/blur/translucent surfaces, no persistent dock.
   - **Volt `#D6FF3F` means on, active or yours, nothing else. Flare `#FF5B2E` means unread or alert, nothing else.**
   - Use the **notch** shapes (big top-left radius, three small). **Circles are for apps only.**
   - Bricolage Grotesque for the voice. DM Mono, UPPERCASE and tracked, for labels, counts and times.
   - Use `halo_ui` tokens and widgets. Never hard-code colors, radii or text styles in launcher code.
   - Read exact values from `design/source/*.dc.html` (inline styles). Don't eyeball them from the PNGs.
   - Both appearances (dark and light, D-013) for every screen and widget.
4. **Platform access goes through `halo_sdk`.** Screens never call platform channels or Android APIs directly. Every `halo_sdk` API has a mock implementation, so the launcher keeps running on macOS and in tests.
5. **Missing permissions are normal.** Notification access, calendar, usage access, write settings and DND access are all optional grants. Every screen must render and stay usable without them, with a clear way to grant them.
6. **Personal data stays on the device.** Notifications, calendar, contacts and usage data are never sent off the device unless the user explicitly opts in.
7. **No network at runtime for assets.** Fonts and images are bundled. Never use `google_fonts` runtime fetching.

## Languages and where they go

| Area | Language | Location |
|---|---|---|
| Launcher UI | Dart / Flutter | `launcher/` |
| Design system | Dart package | `packages/halo_ui` |
| Service API and mock backend | Dart package (pure Dart) | `packages/halo_sdk` |
| Android platform code and `AndroidBackend` | Kotlin + Dart (Flutter plugin) | `packages/halo_android` (D-019) |
| App manifest, themes, `MainActivity` | XML, Kotlin | `launcher/android/` |

No new Java, C or C++. Kotlin only where Dart can't reach the Android API.

## Repo layout

```
design/        design exports (png) and sources (.dc.html). Read-only reference
docs/          architecture, design system, decisions, screenshots
packages/      halo_ui, halo_sdk, halo_android
launcher/      the launcher (Flutter): lock, home, recents, switchboard, stream, system
```

Create directories when the work needs them. Don't scaffold empty trees ahead of time.

## Commands

Only document commands that work. When you add one (for example the Android run), document it here and in README.md in the same change.

What works today:

```sh
# Dart (Flutter pinned in .flutter-version)
cd packages/halo_ui && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test

cd packages/halo_sdk && dart pub get && dart analyze && dart test

cd packages/halo_android && flutter analyze && flutter test

# Launcher on macOS, 390 x 844 window, mock data. Starts on Lock; swipe edges to move around.
cd launcher && flutter run -d macos
# Open on another screen: --dart-define=HALO_START=lock|home|apps|switchboard|stream|recents|system
cd launcher && flutter test                 # add --update-goldens after a deliberate visual change

# Launcher on an Android device or emulator (Android backend, starts on Home)
cd launcher && flutter run -d <device>      # --dart-define=HALO_BACKEND=mock shows the design fixtures
cd launcher && flutter build apk --debug
# Make it the home app without the dialog (emulator or test phone):
adb shell cmd role add-role-holder android.app.role.HOME com.baklavapp.halolauncher 0

# Token gallery on macOS
cd packages/halo_ui/example && flutter run -d macos
```

The fast UI loop stays on macOS with the mock backend at 390 × 844, even after the Android target exists. Check Android-specific behavior (insets, gestures, permissions, real data) on a physical device or emulator. Boot an existing AVD headless with `emulator -avd <name> -no-window -read-only` so the run leaves no state behind.

## Conventions

**Dart / Flutter**
- `dart format` plus `flutter analyze` with no warnings, using each package's `analysis_options.yaml`.
- State: plain Dart, no state-management package (D-015). `halo_sdk` exposes snapshots plus a broadcast `changes` stream; screens rebuild with `BackendBuilder`. Stateless widgets with explicit state where possible.
- Mock fixtures reuse the copy from the designs (Elif, "Design review · Room 3", Karaköy, Night Drive / Mira Okafor) so golden tests line up with `design/screens/`.
- Lay out against the 390-wide design frame and scale to the device. Respect system insets and display cutouts.

**Kotlin / Android**
- Keep the platform layer thin: fetch and convert data, forward events. Logic and UI decisions live in Dart.
- Ask for a permission only when the user reaches the feature that needs it, and explain why first.
- Run long work (icon loading, queries) off the main thread.

**Testing**
- Flutter: widget tests for every `halo_ui` widget, golden tests for every screen in both appearances against the design PNGs, and unit tests for `halo_sdk` (mock and Android backend mapping).
- Run the relevant tests before claiming work is done. Report failures as they are.

**Git**
- Work on `dev`. `main` is the release branch. Open PRs from `dev` (or feature branches) to `main`.
- Write small, focused commits with imperative messages, prefixed with the area (`launcher:`, `halo_ui:`, `halo_sdk:`, `android:`, `docs:`, `ci:`).
- Commit or push only when asked.

## Keeping docs current
- A change to architecture updates `docs/ARCHITECTURE.md` and, if it reverses a choice, `docs/DECISIONS.md`.
- A new design token or component updates `docs/DESIGN_SYSTEM.md` and `halo_ui` together.
- Finishing a roadmap item updates the checkbox in `ROADMAP.md`.
