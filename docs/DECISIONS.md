# Decision log

Short architecture decision records. D-001 to D-016 date from Halo OS; D-017 turned the project into an Android launcher, and the OS-only entries are kept as history. Status is **Decided** (set by the project owner), **Proposed** (the current plan, open to change until the dependent phase starts) or **Open** (needs research).

When a decision changes, update its entry and note the date. Don't delete history.

---

## D-001 · Linux kernel, no distribution. **Decided** (2026-10-25) · **Superseded** by D-017 (2026-10-26)
Halo runs on the Linux kernel. No existing distribution (Ubuntu, Debian, Alpine, postmarketOS, AOSP userspace) is used as a base. We write PID 1, the service layer and the shell. Upstream libraries are built from source by our own recipes.

## D-002 · Flutter for all UI. **Decided** (2026-10-25)
The shell and all first-party apps are Flutter (Dart). Third-party apps target the Halo Flutter SDK.
*2026-10-26:* still holds for the launcher (D-017): all UI is Flutter. The "first-party apps" and "third-party SDK" parts lapsed with the OS.

## D-003 · Rust for system code. **Proposed** · **Superseded** by D-017 (2026-10-26)
haloinit, the compositor, all services and the build driver are Rust. C++ only where the Flutter Embedder API makes it the practical choice (halo-embedder). No new C code except kernel patches.
*Alternatives:* C/C++ (more risk), Go (GC pauses and a larger runtime in PID 1).

## D-004 · Own init (haloinit), not systemd. **Proposed** · **Superseded** by D-017 (2026-10-26)
Small, declarative TOML units, supervision, no D-Bus dependency. systemd would pull in D-Bus, journald and logind, and a lot of policy we don't need.

## D-005 · Compositor in Rust (Smithay) that embeds the shell's Flutter engine. **Proposed** · **Superseded** by D-017 (2026-10-26)
Apps are separate Wayland clients. App buffers become external textures in the shell scene. See ARCHITECTURE §5.
*Alternatives:* a single engine with multi-view (no isolation), the GTK embedder (heavy), wlroots in C (another language).
*Risk:* Flutter external-texture performance with dmabuf on the target GPUs. Prototype in Phase 3 before committing.

## D-006 · halo-bus: protobuf over Unix sockets, no D-Bus in core. **Proposed** · **Superseded** by D-017 (2026-10-26)
*Alternatives:* D-Bus (dbus-broker), Varlink, Cap'n Proto, gRPC.

## D-007 · glibc + LLVM/Clang toolchain. **Proposed** · **Superseded** by D-017 (2026-10-26)
Required by the practical constraints of the Flutter engine.

## D-008 · Read-only EROFS root, dm-verity, A/B updates. **Proposed** · **Superseded** by D-017 (2026-10-26)

## D-009 · Own build driver (`halo`) with TOML recipes, not Buildroot or Yocto. **Proposed** · **Superseded** by D-017 (2026-10-26)
*Risk:* this takes real effort. If it drags on in Phase 1, fall back to Buildroot only as the *builder* for base libraries, with no Buildroot defaults in the image.

## D-010 · First targets: QEMU aarch64, then Raspberry Pi 5 + touch panel. **Proposed** · **Superseded** by D-017 (2026-10-26)
The first phone is **Open** (OnePlus 6/6T, PinePhone Pro, Fairphone…).

## D-011 · Bluetooth and cellular stacks. **Open** · **Superseded** by D-017 (2026-10-26)
BlueZ and ModemManager both want D-Bus. Options: a private dbus-broker behind a Halo service, or our own thin layers (QMI/MBIM for modems).

## D-012 · Halo intelligence (summaries, Ask Halo). **Open**
On-device model versus opt-in cloud, the privacy model and the hardware requirements. The design depends on it (Stream summary card, Home "NOW"), so a rule-based fallback must exist.

## D-013 · Light appearance. **Decided** (2026-10-26): palette and components; **Open**: what `Auto` follows
The owner supplied the light designs (`design/source/*Light.dc.html`, `design/screens/*_light.png`). Same layout and shapes with swapped tokens: Volt splits into fill (with an ink edge), Moss for lines and Olive for text; switches invert; hairlines become ink at role-dependent alphas. The full map is DESIGN_SYSTEM §2b.
*Still open:* what `Auto` follows. Options: the system's brightness on a desktop; on the device, time of day (sunrise and sunset from `halo-time`/`halo-location`) or the ambient light sensor. Until decided, Auto means dark on the device and the platform setting on a desktop.
*2026-10-26, proposal for the launcher (D-017):* Auto follows Android's dark theme setting, which users can already schedule. This is what the code does today (`ThemeMode.system`).

## D-014 · Build host: Debian 13 (host tools only). **Decided** (2026-10-25) · **Superseded** by D-017 (2026-10-26)
Kernel, rootfs and image builds run on Debian 13 (trixie): in a Lima VM on macOS (`build/lima/halo-builder.yaml`) or in the container (`build/container/Containerfile`). It provides host tools only. No Debian package or file ends up in the target image, so D-001 holds. To do: pin the base image by digest and the apt packages by snapshot date once the container is built.

## D-015 · UI state: plain Dart, no state-management package. **Proposed** (2026-10-25)
`halo_sdk` exposes snapshots plus a broadcast `Stream<void> changes`, and mutators on `HaloBackend`. The shell rebuilds with a small `BackendBuilder` (a `StreamBuilder`). Screen-local state (the open accordion section, the focused slat or app) lives in `State` objects. Widgets stay stateless where they can, with explicit state passed in. No Provider, Riverpod or Bloc.
*Why:* the state is small, the SDK boundary is already an interface with a mock, and a third-party dependency would have to be vetted and pinned for the device image.
*Revisit if:* the SDK needs fine-grained subscriptions (per-notification streams) or a screen's state becomes hard to follow.

## D-016 · Flutter engine for early bring-up: prebuilt, then from source. **Decided** (2026-10-25): option C · **Superseded** by D-017 (2026-10-26)
BUILD.md §2 plans to build the Flutter engine from source (`third_party/flutter-engine`) to match our Clang. That is a very large build (GN, ninja, many GB) and it blocks every Flutter pixel on the device.

**Option A, prebuilt for bring-up.** Pin Google's CI artifact for the SDK we already pin (Flutter 3.47.4, engine `06a2e2a110089dff50fe635cffd2a61e1b24fbcd`) in `third_party/manifest.toml` with its checksum: `linux-arm64/linux-arm64-embedder.zip` (14.8 MB: `libflutter_engine.so` and `flutter_embedder.h`). The `linux-arm64-release` and `-profile` variants exist for AOT. This gets the embedder and the compositor running far sooner.
**Option B, from source now.** Matches the plan and our toolchain; nothing Flutter is visible until it finishes.
**Option C, recommended:** A until Phase 3 ends, B before Phase 7 (verified boot, reproducible images) and before any release. The embedder depends only on the Embedder API, so swapping the binary is a one-line manifest change.

*Costs of A:* one binary component is not built by our recipes, so it is an exception to "recipes only" in CLAUDE.md rule 1. It is built with Google's toolchain, not our LLVM (D-007). It is a BSD-3 binary we cannot patch.

*Prerequisite for A and B alike:* the engine is dynamically linked, so the image needs a glibc, and that glibc must come from our own recipe, not from the Debian build host (D-001, D-014). The Phase 1 sysroot comes first; then Mesa (EGL/GBM), libdrm and libinput, which the engine and the DRM embedder use.

Option C was chosen by the owner on 2026-10-25. It is in place: the pinned artifacts are in `third_party/manifest.toml`, `build/recipes/flutter-engine.toml` stages them, and the shell runs on them in QEMU. The sysroot's glibc is built from `build/recipes/glibc.toml`. `halo-splash` (a PNG blitted to the framebuffer) remains only as a fallback.

## D-017 · Halo becomes an Android launcher. **Decided** (2026-10-26)
The owner turned Halo from a Linux-based OS into an Android home-screen launcher built with Flutter. The designs, `halo_ui`, `halo_sdk` (interface and mock) and the six screens carry over; the kernel, init, compositor, embedder, build driver and recipes were removed. D-001, D-003 to D-011, D-014 and D-016 are superseded. The launcher has to run as a normal store app (CLAUDE.md rule 1), so what the designs show is bounded by what Android lets a launcher do (ROADMAP open questions).

## D-018 · Android versions: min SDK 29, target and compile SDK 36. **Proposed** (2026-10-26)
Android 10 (API 29) brings `RoleManager.ROLE_HOME` (asking to become the default launcher), gesture navigation and a system dark theme, and covers the vast majority of active phones. Target and compile SDK follow the newest stable platform installed with the pinned Flutter (36).
*Alternatives:* 26 (more old phones, more code paths for the default-launcher prompt and icons), 31 (monochrome-capable icons and a smaller test matrix, fewer phones).

## D-019 · Platform layer: a Kotlin Flutter plugin, `packages/halo_android`, over plain platform channels. **Proposed** (2026-10-26)
`halo_android` holds the Kotlin side (LauncherApps, intents, later notifications, calendar, settings) and the Dart `AndroidBackend` that implements `HaloBackend`. The launcher only sees `HaloBackend`, so `halo_sdk` stays pure Dart and the mock keeps working on macOS. One `MethodChannel` for calls and one `EventChannel` for changes; messages are maps of standard types.
*Alternatives:* Kotlin in the launcher's own `android/` module (fewer packages, but the backend can't be tested on its own), Pigeon codegen (typed, but one more pinned dependency and generated code to review).

## D-020 · Application id `com.baklavapp.halolauncher`. **Decided** (2026-10-26)
The id can't change once the app is published. It is also the Kotlin package name of the app (`com.baklavapp.halolauncher`) and of the plugin (`com.baklavapp.halolauncher.platform`).
*History:* proposed as `com.harundemir.halolauncher`; the owner chose `com.baklavapp.halolauncher` before anything was published.

## D-021 · Lock design on Android. **Open**
A launcher can't replace the keyguard. Options: an at-a-glance page reached from Home, the screen shown once after unlock, or drop it. Until decided, the Android build starts on Home and Lock is reachable only with `--dart-define=HALO_START=lock`.

## D-022 · Recents from usage stats. **Proposed** (2026-10-26)
The system Overview belongs to the system launcher; third-party launchers can't show live task surfaces or close tasks. Halo's Recents lists recently used apps from `UsageStatsManager` (usage access grant), tap to switch, flick up to drop from Halo's list.

## D-023 · Shell gestures on Android. **Open**
Android owns the bottom edge (home and Overview), the side edges (back) and the top edge (the notification shade). The desktop edge swipes (top left Stream, top right Switchboard, bottom Home/Recents) work today inside the launcher window, but the system takes most edge swipes first under gesture navigation. Options: swipes started away from the edges (down in the upper half of Home for Stream/Switchboard, up from the arc for Recents), or on-screen affordances.
*2026-10-26:* on Android, an up swipe from the arc band or the bottom edge of Home opens Apps (D-026); Recents has no Android route until Phase 6.

## D-024 · System bars and the design frame. **Proposed** (2026-10-26), interim
The launcher draws edge to edge behind transparent system bars, and lays out the 390-wide design frame inside the safe area, scaled by width (`launcher/lib/design_frame.dart`). The shell's own status row stays for now, so time and battery show twice. The owner decides whether to hide the system status bar on Home or drop the shell's status row (ROADMAP open question).

## D-025 · App icons on the arc: like `home.png`. **Decided** (2026-10-26)
The owner chose the design's look for every app on the arc, not only the focused one: a bone glyph on a `surface` circle, and the focused app a Volt circle with the glyph in carbon. No color icons on the arc.
- **The user's default apps for the design's roles** (maps, music, messages, camera, browser, phone) are drawn with the design's own glyphs, exactly as `home.png`.
- **Every other app** is drawn from a monochrome mask, padded to a glyph's share of the circle: the icon's own monochrome layer (Android 13+ themed icons) when it has one, else a mask derived from the icon (the parts of an adaptive icon that differ from its background layer; for a legacy icon, what differs from its edge color).
- The color icon is used only if no mask can be made. The Apps list keeps color icons, to help find an app.
*History:* first proposed as color icons with a Volt ring on the focused app, then monochrome only when focused; the owner asked for `home.png`.

## D-026 · Apps: a list, the arc you keep, and a long-press menu. **Proposed** (2026-10-26)
The designs have no "all apps" view. With 100+ apps the arc alone can't reach everything, and rule 01 forbids a grid. Proposal, built in Phase 3:
- **Apps screen:** an up swipe on the arc (the band above the bottom edge, so the edge still means Recents on desktop) opens one list of every app. Title `Apps` with a Volt count, a working command field ("find an app"), then A to Z with mono letter headings and a letter index down the right edge (the letter in view is Volt: current). Rows are a 40 px app circle, the name in `rowTitle`, and mono tags: `WORK`, and a Volt `ON ARC` (yours).
- **Search:** label prefix, then word prefix, then anywhere; case and Latin accents (Turkish included) ignored. Go opens the best match. Two gestures reach any app: open Apps, then type or jump by letter.
- **The arc you keep:** the arc shows the apps the user pins, in their order, saved on the phone. The first time it is filled with the default apps for the Home design's roles (maps, music, messages, camera, browser, phone; Notes has no standard role), or the first seven apps when none resolve.
- **Long-press menu** (on the arc and in the list): a solid `surface` notch card with the app's shortcuts (only while Halo is the default home app, an Android rule), Add to / Remove from arc, Move left / right, App info and Uninstall (hidden for system apps). No scrim: tapping outside or back closes it.
- **Search sources** (Phase 3, done): results come in APPS, CONTACTS and SETTINGS sections. Contacts need `READ_CONTACTS`, asked for only from search with an inline "Search your contacts too · ALLOW" row and the note "Names stay on this phone"; after a permanent no, the row opens Halo's App info. Contacts show initials in a notch (circles are for apps). Settings pages are a fixed list mapped to system screens. Go opens the best app, else the best settings page.
- **Private space** (Android 15+): its apps appear, tagged `PRIVATE`, only while it is unlocked; a row at the end of Apps locks or unlocks it (the system asks for the lock).
- **On a phone, the bottom edge of Home opens Apps too**, since a thumb starts just above the gesture bar and Recents is empty on Android until Phase 6 (see D-023).
*Open for the owner:* the gesture (up on the arc versus an on-screen affordance), whether the per-row `ON ARC` Volt is too much Volt, and how reordering should feel (drag on the arc instead of Move left / right).

