# Decision log

Short architecture decision records. Status is **Decided** (set by the project owner), **Proposed** (the current plan, open to change until the dependent phase starts) or **Open** (needs research).

When a decision changes, update its entry and note the date. Don't delete history.

---

## D-001 · Linux kernel, no distribution. **Decided** (2026-10-25)
Halo runs on the Linux kernel. No existing distribution (Ubuntu, Debian, Alpine, postmarketOS, AOSP userspace) is used as a base. We write PID 1, the service layer and the shell. Upstream libraries are built from source by our own recipes.

## D-002 · Flutter for all UI. **Decided** (2026-10-25)
The shell and all first-party apps are Flutter (Dart). Third-party apps target the Halo Flutter SDK.

## D-003 · Rust for system code. **Proposed**
haloinit, the compositor, all services and the build driver are Rust. C++ only where the Flutter Embedder API makes it the practical choice (halo-embedder). No new C code except kernel patches.
*Alternatives:* C/C++ (more risk), Go (GC pauses and a larger runtime in PID 1).

## D-004 · Own init (haloinit), not systemd. **Proposed**
Small, declarative TOML units, supervision, no D-Bus dependency. systemd would pull in D-Bus, journald and logind, and a lot of policy we don't need.

## D-005 · Compositor in Rust (Smithay) that embeds the shell's Flutter engine. **Proposed**
Apps are separate Wayland clients. App buffers become external textures in the shell scene. See ARCHITECTURE §5.
*Alternatives:* a single engine with multi-view (no isolation), the GTK embedder (heavy), wlroots in C (another language).
*Risk:* Flutter external-texture performance with dmabuf on the target GPUs. Prototype in Phase 3 before committing.

## D-006 · halo-bus: protobuf over Unix sockets, no D-Bus in core. **Proposed**
*Alternatives:* D-Bus (dbus-broker), Varlink, Cap'n Proto, gRPC.

## D-007 · glibc + LLVM/Clang toolchain. **Proposed**
Required by the practical constraints of the Flutter engine.

## D-008 · Read-only EROFS root, dm-verity, A/B updates. **Proposed**

## D-009 · Own build driver (`halo`) with TOML recipes, not Buildroot or Yocto. **Proposed**
*Risk:* this takes real effort. If it drags on in Phase 1, fall back to Buildroot only as the *builder* for base libraries, with no Buildroot defaults in the image.

## D-010 · First targets: QEMU aarch64, then Raspberry Pi 5 + touch panel. **Proposed**
The first phone is **Open** (OnePlus 6/6T, PinePhone Pro, Fairphone…).

## D-011 · Bluetooth and cellular stacks. **Open**
BlueZ and ModemManager both want D-Bus. Options: a private dbus-broker behind a Halo service, or our own thin layers (QMI/MBIM for modems).

## D-012 · Halo intelligence (summaries, Ask Halo). **Open**
On-device model versus opt-in cloud, the privacy model and the hardware requirements. The design depends on it (Stream summary card, Home "NOW"), so a rule-based fallback must exist.

## D-013 · Light appearance. **Decided** (2026-10-26): palette and components; **Open**: what `Auto` follows
The owner supplied the light designs (`design/source/*Light.dc.html`, `design/screens/*_light.png`). Same layout and shapes with swapped tokens: Volt splits into fill (with an ink edge), Moss for lines and Olive for text; switches invert; hairlines become ink at role-dependent alphas. The full map is DESIGN_SYSTEM §2b.
*Still open:* what `Auto` follows. Options: the system's brightness on a desktop; on the device, time of day (sunrise and sunset from `halo-time`/`halo-location`) or the ambient light sensor. Until decided, Auto means dark on the device and the platform setting on a desktop.

## D-014 · Build host: Debian 13 (host tools only). **Decided** (2026-10-25)
Kernel, rootfs and image builds run on Debian 13 (trixie): in a Lima VM on macOS (`build/lima/halo-builder.yaml`) or in the container (`build/container/Containerfile`). It provides host tools only. No Debian package or file ends up in the target image, so D-001 holds. To do: pin the base image by digest and the apt packages by snapshot date once the container is built.

## D-015 · UI state: plain Dart, no state-management package. **Proposed** (2026-10-25)
`halo_sdk` exposes snapshots plus a broadcast `Stream<void> changes`, and mutators on `HaloBackend`. The shell rebuilds with a small `BackendBuilder` (a `StreamBuilder`). Screen-local state (the open accordion section, the focused slat or app) lives in `State` objects. Widgets stay stateless where they can, with explicit state passed in. No Provider, Riverpod or Bloc.
*Why:* the state is small, the SDK boundary is already an interface with a mock, and a third-party dependency would have to be vetted and pinned for the device image.
*Revisit if:* the SDK needs fine-grained subscriptions (per-notification streams) or a screen's state becomes hard to follow.

## D-016 · Flutter engine for early bring-up: prebuilt, then from source. **Decided** (2026-10-25): option C
BUILD.md §2 plans to build the Flutter engine from source (`third_party/flutter-engine`) to match our Clang. That is a very large build (GN, ninja, many GB) and it blocks every Flutter pixel on the device.

**Option A, prebuilt for bring-up.** Pin Google's CI artifact for the SDK we already pin (Flutter 3.47.4, engine `06a2e2a110089dff50fe635cffd2a61e1b24fbcd`) in `third_party/manifest.toml` with its checksum: `linux-arm64/linux-arm64-embedder.zip` (14.8 MB: `libflutter_engine.so` and `flutter_embedder.h`). The `linux-arm64-release` and `-profile` variants exist for AOT. This gets the embedder and the compositor running far sooner.
**Option B, from source now.** Matches the plan and our toolchain; nothing Flutter is visible until it finishes.
**Option C, recommended:** A until Phase 3 ends, B before Phase 7 (verified boot, reproducible images) and before any release. The embedder depends only on the Embedder API, so swapping the binary is a one-line manifest change.

*Costs of A:* one binary component is not built by our recipes, so it is an exception to "recipes only" in CLAUDE.md rule 1. It is built with Google's toolchain, not our LLVM (D-007). It is a BSD-3 binary we cannot patch.

*Prerequisite for A and B alike:* the engine is dynamically linked, so the image needs a glibc, and that glibc must come from our own recipe, not from the Debian build host (D-001, D-014). The Phase 1 sysroot comes first; then Mesa (EGL/GBM), libdrm and libinput, which the engine and the DRM embedder use.

Option C was chosen by the owner on 2026-10-25. It is in place: the pinned artifacts are in `third_party/manifest.toml`, `build/recipes/flutter-engine.toml` stages them, and the shell runs on them in QEMU. The sysroot's glibc is built from `build/recipes/glibc.toml`. `halo-splash` (a PNG blitted to the framebuffer) remains only as a fallback.
