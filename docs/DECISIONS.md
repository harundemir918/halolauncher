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

## D-012 · Halo intelligence (summaries, Ask Halo). **Decided** (2026-10-26): no AI
The owner decided Halo integrates no AI: no on-device model, no cloud model. The Stream summary, the Home "NOW" pick, notification priority and Ask Halo are rule-based, built from Halo's own data on the phone. Ask Halo may hand off to the assistant the user picked in Android (D-027); that app is the user's choice, not part of Halo.
*History:* was Open (on-device model versus opt-in cloud).

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

## D-021 · Lock design on Android. **Decided** (2026-10-27): option A, the glance page
A launcher can't replace the keyguard. Options: an at-a-glance page reached from Home, the screen shown once after unlock, or drop it. Until decided, the Android build starts on Home and Lock is reachable only with `--dart-define=HALO_START=lock`.
*The case (2026-10-27), for the owner to pick:*
- **A. A glance page left of Home**, reached by a swipe right on Home (not from the edge, which Android's back gesture owns) and left by the same swipe back. Clock, the next event and notification previews, with the design's hold ring turned into a "back to Home" hold. Cheapest, always one move away, never in the way.
- **B. Shown once after unlock** when Halo comes to the front from a screen-off. Closest to the design, but a launcher can't tell an unlock from any return to Home, so it risks appearing when the user wants Home. It needs `ACTION_USER_PRESENT` or `SCREEN_OFF` receivers.
- **C. Drop it.** Home already has the next event and Stream has the notifications.
Recommended: A. It gives the design its screen with the least risk, and the data (calendar, notifications) is already served.
*Decided (2026-10-27):* the owner took the recommendation. Built: the Lock screen is the glance page left of Home on Android. A swipe right on Home (anywhere above the arc; the arc's own drag zone is the bottom 260 px) opens it, and a swipe left, the hold ring, back or the Home button returns. It says `GLANCE` instead of `LOCKED`, leaves out the network it doesn't know, and shows the Camera shortcut (it starts the user's camera app) but not Flashlight, which does nothing yet. On macOS and in the goldens Lock is unchanged.

## D-022 · Recents from usage stats. **Proposed** (2026-10-26)
The system Overview belongs to the system launcher; third-party launchers can't show live task surfaces or close tasks. Halo's Recents lists recently used apps from `UsageStatsManager` (usage access grant), tap to switch, flick up to drop from Halo's list.
*Built (2026-10-27):* usage events (`ACTIVITY_RESUMED`, the last hour and since the phone started) give the packages, newest first, minus Halo; each maps to the owner's launcher entry (work profile apps are out, their usage isn't visible). Five slats at most, as in the design, so the focused one keeps its width. A tap on the focused slat starts the app; a flick drops it into `recentsDropped` (package and time) and it returns once used again. The preview is the app's icon on a wash of its own color (taken from the icon in Kotlin); a drawn surface stays only for the mock's Maps. Without the grant Recents says what it needs and offers it.
*Not the system's Overview:* Android tells a launcher nothing about which apps are still open, and the public usage events only say an app left the screen, not whether it was closed (the event that says so is hidden, so rule 1 rules it out). Recents is therefore a history of use, kept short (the last hour, five slats, drop what you don't want), not a list of open apps.
*Open for the owner:* which slat starts focused (the design's middle one, as now, or the app used last).

## D-023 · Shell gestures on Android. **Open**
Android owns the bottom edge (home and Overview), the side edges (back) and the top edge (the notification shade). The desktop edge swipes (top left Stream, top right Switchboard, bottom Home/Recents) work today inside the launcher window, but the system takes most edge swipes first under gesture navigation. Options: swipes started away from the edges (down in the upper half of Home for Stream/Switchboard, up from the arc for Recents), or on-screen affordances.
*2026-10-26:* on Android, an up swipe from the arc band or the bottom edge of Home opens Apps (D-026); Recents has no Android route until Phase 6.
*2026-10-27 (proposed):* on Android the bottom-edge swipe climbs: Home, Apps, Recents; from anywhere else it goes Home. No new gesture, and Recents sits one step above Apps. Other options: a link in Apps' header, or a long-press on Home.
*Checked on the Pixel 10 Pro emulator (2026-10-27):* the climb works when the swipe starts in the 44 px strip just above the system's gesture bar, which is narrow. Apps, Stream and System end their scrollers 44 px above the bottom so a list doesn't take that drag first (before this, the swipe did nothing on those screens). *Result on the owner's Galaxy (2026-10-27):* with gesture navigation Android keeps that strip and a swipe up there opens the system's own Recents, so the gesture can't be relied on. *Changed:* Apps' header has a `Recents ›` button (like `System ›` on Switchboard). The way in is now: an up swipe on the arc to Apps, then the button. The bottom-edge climb stays for phones where it works.

## D-024 · System bars, the design frame and Halo's status row. **Decided** (2026-10-26): the status row; **Proposed**: the frame
The launcher draws edge to edge behind transparent system bars, and lays out the 390-wide design frame inside the safe area, scaled by width (`launcher/lib/design_frame.dart`).
*Status row, decided by the owner:* Android's status bar stays and shows the time and the battery, so Halo's row no longer repeats them. Its left side is `STREAM` and its right side `SWITCHBOARD`, and tapping one opens that screen. A Flare dot before `STREAM` means something is unread; the screen shown is Volt. The 3 px battery line across the very top stays. Lock keeps its own `LOCKED` row.
*History:* first both rows showed, so the time and battery appeared twice.

## D-025 · App icons on the arc: like `home.png`. **Decided** (2026-10-26)
The owner chose the design's look for every app on the arc, not only the focused one: a bone glyph on a `surface` circle, and the focused app a Volt circle with the glyph in carbon. No color icons on the arc.
- **The user's default apps for the design's roles** (maps, music, messages, camera, browser, phone) were drawn with the design's own glyphs, exactly as `home.png`. *Changed 2026-10-28 (owner):* they looked out of place next to the masks, so on Android they are drawn from their own monochrome icon like every other app. The design's glyph is used only when no mask can be made for one of them (never its color icon); the mock, macOS and the goldens keep the glyphs, since there are no real icons there.
- **Every other app** is drawn from a monochrome mask, padded to a glyph's share of the circle: the icon's own monochrome layer (Android 13+ themed icons) when it has one, else a mask derived from the icon (the parts of an adaptive icon that differ from its background layer; for a legacy icon, what differs from its edge color).
- The color icon is used only if no mask can be made (for an app that fills no role). The Apps list keeps color icons, to help find an app.
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

## D-027 · The Ask Halo button. **Decided** (2026-10-26)
The designs show the button under the arc but not what it does. Owner approved:
- **Tap:** opens search (the Apps screen) with the keyboard up, placeholder "find anything": apps, contacts and settings pages (D-026).
- **Long press:** opens the assistant the user picked in Android (`ACTION_ASSIST`, else `ACTION_VOICE_COMMAND`); nothing happens if there is none. Halo has no assistant of its own (D-012).
- **Later (Phase 7):** rule-based commands typed into the same field ("next", "reply Elif …", "dark", "battery").

## D-029 · Switchboard and System hand over what Android reserves. **Proposed** (2026-10-27)
Rule 1 (a normal app) means Halo shows real state and hands over what it can't change itself:
- **Set directly:** media volume (`AudioManager`), brightness and auto brightness (with the user's Write settings grant), Do Not Disturb on and off (with notification policy access), media play/pause and skip.
- **Handed over:** Wi-Fi, Bluetooth, mobile data and airplane mode are read (`ConnectivityManager`, `WifiManager`, the Bluetooth adapter, `Settings.Global`) and kept current by broadcasts and a network callback, but the switch opens the Settings panel (`Settings.Panel.ACTION_WIFI`, `ACTION_INTERNET_CONNECTIVITY`, the Bluetooth and airplane pages). The row follows when the user comes back.
- **Not shown on purpose:** the Wi-Fi network's name and the count of paired Bluetooth devices, which need location and Bluetooth permissions. Rows say `CONNECTED`, `ON` or `OFF`.
- **System:** only Display is designed. The other sections open the matching Android Settings page, and Privacy lists the optional accesses with a switch that opens the grant. Android lets the user take an access back only in Settings, so a granted switch opens Settings too.
- **Deviations from the design:** the Light dial's footer is a button (auto brightness, or the grant when missing); a flick across the media strip skips; the strip stacks title above artist; the Switchboard's toggle rows scroll in a fixed band, with a `Theme` row after Focus (on is dark; flipping it sets that appearance by hand, System keeps Auto), and a `System ›` button in the top right is the only way into Halo's System screen. The button sits at the top because the frame is only about 800 high on a phone with a cutout and a nav bar, so nothing fits below the battery cells.
*Open for the owner:* whether the Sound footer should cycle the ringer mode.

## D-028 · Notification rules in Stream and on Home. **Proposed** (2026-10-26)
Android doesn't track whether a notification was read, and the designs show the result, not the rules. Rule-based, no AI (D-012):
- **Unread** is what arrived since the user last left Stream (saved on the phone as `streamSeen`). Unread items are in `NOW`, the rest in `EARLIER`.
- **Marks:** the newest unread message that can be replied to is the current one (Volt); other unread items are alerts (Flare); read items are hollow.
- **Actions:** a tap sends the notification's own tap action; a sideways swipe clears it from the phone (only clearable ones); REPLY opens a field under the item and sends through the app's reply action; LATER snoozes it for an hour.
- **Summary:** new = unread; "Halo read N things" = the rest; "need you" = unread messages to reply to ("Reply to Elif").
- **Home's card:** the newest unread message that can be replied to; Reply opens it in Stream with the reply field ready, Later snoozes it. The designs' Yes stays for their fixture question.
- Hidden from Stream: Halo's own notifications, ongoing ones (music, calls, downloads) and group summaries.
*Open for the owner:* the snooze length, and whether opening Stream (rather than leaving it) should mark things seen.

## D-030 · Priority, the summary, NOW and Ask Halo commands. **Proposed** (2026-10-28)
Phase 7 builds on D-028. All rule-based, all from data on the phone (D-012); the rules are in `packages/halo_sdk` (`rules.dart`, `ask.dart`).
- **Priority:** starred people, then people, then apps. A person is what the app names as one (a chat's people or messaging style, a call, a missed call); starred is the app marking them important or a starred contact (needs the contacts grant, else it is simply not known). With **Focus** on, what isn't a person is *held*: it stays in Stream but never counts as needing the user and is never the top message.
- **Top message:** among unread messages with a reply action, or from a person whose app offers none, the highest priority, then the newest. It is the current (Volt) one in Stream. A message nobody can answer from here (Messages that posts no reply action, say) is opened instead: NOW and the card on Home offer `Open` where they'd offer `Reply`, and the summary says `Read Elif`. A missed call, and what an app posts with no person behind it and no reply, are not messages.
- **Summary, "need you":** in order: starred people's replies and calls, an event starting within the hour ("Design review in 19 min"), other people's replies, missed calls ("Call back Anne"), then app messages.
- **NOW on Home:** the next event today, else the top message ("Elif wrote you", Reply and Later), else "Clear for the day". When NOW shows the message, the card above the arc is hidden so it isn't shown twice.
- **Ask Halo commands**, typed in the search field and shown as a row under ASK HALO above the other results (Enter runs it): `next` (the next event), `battery` (the charge; the row opens Android's battery settings), `dark` and `light` (the appearance), `focus`, `focus on`, `focus off`, and `reply <name> <text>` (sends through the app's reply action; the name is a sender's full or first name). A one-word command matches from its third letter. Anything else is an ordinary search.
- **Not done on purpose:** an event or a missed call as the NOW pick (the roadmap says event, else top message), and learning from the user's behaviour (that would be a model).
- **Unverified:** the missed-call category (`missed_call`) is set by the stock dialer apps but isn't a public constant; other dialers may not set it, and then a missed call is just an app notification.
*Open for the owner:* the one-hour window for "event soon", and whether a missed call should be a NOW pick. *Decided 2026-10-28 (owner):* a person's message with no reply action may be the NOW pick, opened with `Open`.

## D-031 · First-run welcome. **Proposed** (2026-10-28)
The first time Halo starts on Android it shows a Welcome screen instead of Home: "Make Halo your home" with a row for the home app and one for each optional access (the same rows as System's Privacy, each saying what it is for), and a Continue button that is always there. Nothing is required; tapping a row opens the usual Android dialog or Settings page, and the rows follow when the user comes back. Continue records `welcomed` in Halo's own preferences, so it is shown once. Without the grants Home still renders and keeps its own ALLOW rows and the "Set Halo as home?" card (CLAUDE.md rule 5).
- There is no design for this screen. It is built from existing parts (kicker, headline, toggle rows, button) in the Home layout, in both appearances. *Open for the owner:* the copy and whether it deserves a designed screen.
- Existing installs see it once after updating, since they have no `welcomed` yet.
- Not done: a re-run from System, a step-by-step flow with one permission per page.

## D-032 · Crash reporting and the privacy policy. **Proposed** (2026-10-28)
Rule 6 and rule 7 rule out a crash reporter SDK that sends data, and the release build has no internet permission at all (checked in the built APK), so Halo can't send anything. Crash data comes from the store instead: Play Console's Android vitals (crashes and ANRs from users who opted in to share diagnostics with Google) needs nothing inside Halo. `docs/PRIVACY.md` says so.
- **Releasing needs the owner:** a keystore (see ARCHITECTURE, Releasing), a contact address and a public URL for the policy, and the choice of store (Play, F-Droid, or both). F-Droid builds from source and signs with its own key unless reproducible builds are set up.
*Open for the owner:* store, and whether a local "last crash" log the user can share by hand is wanted.

## D-033 · Plus slots at the ends of the arc. **Proposed** (2026-10-28)
Adding an app to the arc meant the long-press menu's "Add to arc", which always put it at the right end. The arc now has a plus slot at each end (`HaloArc.onAddStart`, `onAddEnd`): rotate to it, tap it, and Apps opens as a picker (`Add app`: only apps not on the arc, search works, Go adds the best match, back adds nothing). The chosen app is added at that end and Home returns with it focused. `pinToArc` takes `atStart`.
- The design has no such slot. It is drawn in the notch shape (not a circle, since it isn't an app) with the arc's own outline and focus treatment, so it stays inside rule 3. It is Android only: the macOS and golden screens pass no callbacks and look as designed.
- With no apps on the arc there is a single plus (the end one).
- Not done: dragging an app to a chosen place in the middle (the menu's Move left and right still do that). The arc's length is limited by D-034.
*Open for the owner:* whether the plus slots should also be reachable from outside the arc's reach (they only show when the arc is rotated near an end).

## D-034 · The arc holds at most 10 apps. **Decided** (2026-10-28)
The owner asked for the Home arc to hold at most 10 apps: with more, swiping to the one wanted gets slow, and every other app is one swipe up in the Apps list and in search.
- `maxArcApps` in `halo_sdk` is the limit. `pinToArc` does nothing on a full arc, at either end.
- A full arc has no plus slots. The long-press menu of an app that isn't on it says `Arc is full` (disabled) instead of `Add to arc`. Removing an app makes room again.
- An arc that already holds more than 10 (from before this) is left as it is: nothing is removed, it just can't grow until it is below 10.

## D-035 · Reordering the arc by dragging. **Proposed** (2026-10-28)
Press and hold an app on the arc: the moment the hold registers it lifts (it grows to 1.4 times its size, bigger than the focused app, with a Volt ring and a haptic tick, so reorder mode is plain). Moving the finger then drags it along the arc, and the others slide aside to make room. Letting go drops it in the nearest place, saves it (`moveOnArc`) and focuses it. This answers the open question in D-026 about how reordering should feel.
- **On the curve:** only the finger's angle around the arc's center counts, not its distance, so the app stays on the ring however the finger strays. It stays between the first and last app; the plus slots are not drop places and are hidden meanwhile.
- **Edges:** with the finger far round the arc (about 46 degrees from the top, near the screen's side) the arc turns, faster the closer to the edge, to carry the app past what is in view.
- **The menu moves:** the long-press menu now opens when you let go if you didn't move (it used to open as soon as the hold registered). Moving more than about 10 px after the hold starts the drag. Letting go without moving puts the app down again and opens the menu. A quick sideways swipe still turns the arc.
- **Accessibility:** a drag isn't possible with a screen reader, so Move left and Move right stay in the menu.
- Not done: reordering in the Apps list, and dragging an app off the arc to remove it.
*Open for the owner:* the menu now opens after the app has lifted and been put down, which may feel odd; an alternative is a separate way to open it.

## D-036 · Accessibility. **Proposed** (2026-10-28)
Built from an audit of every screen in both appearances, with Flutter's accessibility checks and the semantics tree (`launcher/test/accessibility_test.dart`).
- **Touch targets are at least 48 dp, and the design doesn't move.** `HaloTapTarget` gives a control its semantics and a 48 dp target around the size the design draws (44 high buttons, 32 high inline actions, text links, segments, the avatar) without changing the layout. Where a parent's own bounds end (a tight row) the reach is cut short there; controls placed on a screen's stack get all of it. The one exception is the Recents slats, 36 wide by about 600 high at 6 apart as designed (a taller strip is easy to hit). The letter index is left out of semantics: a screen reader has the list and search.
- **Text size is real now.** System's Text size (12 to 20 px, 16 is as designed) used to be saved and unused. It now multiplies Android's font size, kept between 0.75 and a cap per screen (`haloTextScaleCaps`): 1.15 on the screens laid out edge to edge (Home, Lock, Switchboard, Recents), 1.5 on the ones that scroll (Apps, Stream, System, Welcome). The scaler works like Android's own nonlinear one: body text grows fully, bigger type grows less, and display type (36 and up: the clock, titles, the NOW headline) doesn't grow, so the design's layout holds. Stream and Welcome stack their header and list, so larger text moves the list down instead of running under the card.
- **Reduce motion.** With Android's "Remove animations" on, the arc turns, the reorder lift and the Recents slats happen in one frame (`haloMotion`). The Lock hold ring still takes its time, since the hold is the gesture.
- **Screen readers.** Stream: each notification is one node (text, open, Dismiss) with Reply, Later and the app's actions as buttons under it (they were unreachable). The arc: activating an app opens it (no focusing step), Move left and Move right are named actions (no drag needed), and the plus slots are buttons. System: only an accordion's header is the button, and its controls are nodes of their own. Recents: one node per slat, with Close.
- **Contrast.** Text colors meet WCAG AA (4.5:1) in both appearances on the grounds they are drawn on, checked on the palette (`contrast_test.dart`). A pixel check on 11 px mono labels reads their thin strokes as low contrast, so it isn't used.
- **Not done:** a by-hand TalkBack pass on a phone (tested through the semantics tree only); Android's largest font sizes beyond the caps; high-contrast text and bold text settings; reading order beyond Flutter's default.
*Open for the owner:* the caps. 1.15 on the fixed screens is what their layouts hold without moving anything; more would need those screens to scroll or reflow.

## D-037 · The media card slides long titles and seeks. **Proposed** (2026-10-28)
Two additions to the Switchboard's media card, which the designs don't show:
- **Marquee:** a track title wider than the card rests 1.5 s with its beginning in view, then moves left at a steady 36 px a second and comes round again from the right (after a 48 px gap), over and over, and never turns back; a title that fits sits still, and a new title starts from its beginning. With Android's "Remove animations" it stays still and ends in an ellipsis. The artist line keeps its ellipsis.
- **Seek:** the bottom 28 px of the card is a seek bar. Drag along it (the bar thickens to 7 px while a finger has it) or tap it; the track moves when the finger lets go (`seekMedia`, a fraction of the track). A flick across the title and artist still skips. A screen reader gets a slider that steps by 5%.
- **Only where the player allows it (rule 1):** Android's `MediaController.transportControls.seekTo` works when the session has a length and offers seeking (`ACTION_SEEK_TO`); `MediaSession.canSeek` says so. Radios, live streams and players that don't offer it get a bar that only shows (nothing is faked). The new position shows at once and is held for a second while the player catches up, so the bar doesn't jump back.
*Decided 2026-10-28 (owner):* the artist line doesn't slide. *Open for the owner:* whether seeking should show the time while dragging (the design has none).

## D-038 · A long NOW headline, System's search, no avatar without an account. **Proposed** (2026-10-28)
Three things found on the phone:
- **NOW headline:** it is two lines, what and when (or who and what). A title too wide for its line shrinks to fit, down to 60% of the 42 px, and past that ends in an ellipsis; the line keeps its full height, so nothing under it moves. The whole title is still in the TODAY row.
- **System's "find a setting"** was a bare field that did nothing. It now filters System's sections by their name or what is in them (typing "bluetooth" finds Connections, "text size" finds Display), lists Android's own settings pages that match (they open the real page), and Go opens the best match. Choosing a section closes the results and opens it.
- **No avatar without an account.** Android tells a launcher nothing about who the user is, so the System title's avatar was an empty box. It is drawn only when the backend has initials (the mock does).

