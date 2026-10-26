# Halo OS architecture

Status: **proposed**. Nothing here is implemented yet. Decisions marked *proposed* are recorded in [DECISIONS.md](DECISIONS.md) and can be revisited until the phase that depends on them starts.

## 1. Goals and constraints

- A complete mobile OS on the **Linux kernel**, with **no distribution** underneath: no Ubuntu, Debian, Alpine, postmarketOS or Android userspace. We own PID 1 and everything above it.
- **Flutter** renders all UI, both the system shell and the apps.
- Upstream components (Mesa, libinput, and so on) are fine where writing our own would be unreasonable. We build them from source with pinned versions and our own recipes. "No distribution" means we don't inherit someone else's package set, init system or policy. It doesn't mean rewriting libdrm.
- Read-only, verified system image with atomic A/B updates.
- Every app is a separate, sandboxed process.

## 2. Layer diagram

```
┌──────────────────────────────────────────────────────────────────┐
│  Apps (Flutter)          messages · music · maps · notes · web · │
│                          camera · phone · system(settings) · 3rd │
│      └─ halo_sdk (Dart) ─ halo_ui (Dart) ─ halo-embedder (C++)   │
├──────────────────────────────────────────────────────────────────┤
│  Shell (Flutter, runs inside the compositor)                     │
│      lock · home arc · recents · switchboard · stream · OSDs     │
├──────────────────────────────────────────────────────────────────┤
│  halo-compositor (Rust, Smithay)                                 │
│      DRM/KMS · GBM/EGL · libinput · Wayland server · app surfaces│
│      → external textures in the shell's Flutter scene            │
├──────────────────────────────────────────────────────────────────┤
│  System services (Rust)  over halo-bus (Unix sockets)            │
│   halo-power  halo-net  halo-audio  halo-display  halo-notify    │
│   halo-apps   halo-settings  halo-time  halo-modem  halo-bt      │
│   halo-location  halo-intel  halo-update  halo-keystore          │
├──────────────────────────────────────────────────────────────────┤
│  haloinit (PID 1, Rust)  ·  halo-devd (uevents/hotplug)          │
├──────────────────────────────────────────────────────────────────┤
│  Base libraries: glibc · libstdc++/libc++ · Mesa · libdrm ·      │
│  libinput · libevdev · xkbcommon · fontconfig · freetype ·       │
│  PipeWire · wpa_supplicant · (BlueZ, ModemManager: open)         │
├──────────────────────────────────────────────────────────────────┤
│  Linux kernel (mainline LTS + minimal device patches)            │
├──────────────────────────────────────────────────────────────────┤
│  Bootloader (U-Boot / UEFI) · A/B slots · verified boot          │
└──────────────────────────────────────────────────────────────────┘
```

## 3. Boot chain

1. **Firmware → bootloader.** U-Boot on ARM boards and phones, UEFI (systemd-boot-like stub or GRUB-free EFI stub) on x86_64 and QEMU. The bootloader picks the active A/B slot and falls back after N failed boots.
2. **Kernel + initramfs.** The initramfs is tiny: a static `halo-initramfs` binary (Rust, `system/halo-initramfs`; mounting and switching root work today, verity and `/data` do not yet) that
   - mounts `proc`, `sys`, `devtmpfs` and `run`,
   - sets up dm-verity on `system_<slot>`, mounts it read-only (EROFS) at `/`,
   - unlocks and mounts `/data` (fscrypt/dm-crypt, see §9),
   - calls `switch_root` and execs `/sbin/haloinit`.
3. **haloinit (PID 1)** reads declarative unit files from `/system/etc/init/*.toml`, starts services in dependency order, supervises and restarts them, reaps zombies, and handles shutdown and reboot. It is deliberately smaller than systemd: no journald, no logind, no D-Bus. Logs go to `halo-logd` (a ring buffer plus a persisted file on `/data`).
4. **halo-devd** listens to kernel uevents (netlink), creates device permissions and symlinks, loads firmware, and tells services about hotplug. It replaces udev. libinput's dependency on libudev is met with `libudev-zero` or a small shim.
5. **halo-compositor** starts once DRM and input are ready, brings up the shell, and shows Lock.

Target: under 3 s from kernel start to Lock on QEMU and under 5 s on hardware.

## 4. Filesystem layout

```
/                     read-only system image (EROFS + dm-verity), per A/B slot
├── sbin/haloinit
├── system/
│   ├── bin/          services, compositor, tools
│   ├── lib/          shared libraries
│   ├── etc/init/     haloinit unit files
│   ├── shell/        shell Flutter bundle (AOT libapp.so + flutter_assets)
│   ├── apps/<id>/    preinstalled app bundles
│   └── fonts/        Bricolage Grotesque, DM Mono, fallback fonts
├── data/             writable, encrypted
│   ├── apps/<id>/    installed third-party bundles
│   ├── user/<uid>/<app-id>/   per-app private storage
│   ├── settings/     halo-settings store
│   └── log/
├── run/              tmpfs: sockets (/run/halo/*.sock), pid files
└── tmp/              tmpfs
```

There is no `/usr` merge debate and no FHS compatibility layer. Paths are ours.

## 5. Graphics and windowing

**Decision (proposed): the compositor hosts the shell, and apps are Wayland clients.**

- `halo-compositor` is written in Rust on **Smithay**. It owns DRM/KMS (atomic modesetting), GBM buffers, EGL/GLES (later Vulkan), and libinput.
- It **embeds the Flutter engine** through the Flutter Embedder API (`FlutterEngineRun`, `FlutterOpenGLRendererConfig`) to render the shell UI.
- Apps are separate processes. Each one uses **halo-embedder**, a small C++ embedder built on the Embedder API that renders into a Wayland surface (`wl_surface` + `zwp_linux_dmabuf_v1`). It does **not** use GTK or the stock Flutter Linux desktop embedder.
- The compositor imports app buffers (dmabuf) and gives them to the shell's Flutter engine as **external textures**. That way the shell can draw live app content anywhere: full screen, inside a Recents slat, or during transitions. It also keeps the shell in control of every pixel, which the design needs.
- Private Wayland protocol `halo_shell_v1` covers app lifecycle hints, the safe-area and status-row insets, the thumbnail and "live preview" quality level, and keyboard focus.
- Software keyboard (IME): rendered by the shell, delivered with `zwp_text_input_v3` / `zwp_input_method_v2`.
- Frame pacing: vsync comes from DRM page-flip events and is forwarded to each engine's `FlutterEngineOnVsync`.

Why not run everything in one Flutter engine? It gives no isolation, one bad app freezes the phone, and memory accounting and permissions break down. Why not use the GTK embedder? It is heavy and desktop-oriented, and it would pull GTK, GLib and D-Bus into the image.

## 6. Input

- libinput in the compositor: touch, pointer (dev), keyboard and switches (lid, volume and power keys).
- Shell gestures (edge swipes, hold-to-open, the arc) are recognized in the shell's Flutter layer. The compositor only routes events and enforces system-reserved edges.
- Hardware keys (power, volume) are handled in the compositor and forwarded to services (power → `halo-power` for suspend, volume → `halo-audio` + shell OSD).

## 7. IPC: halo-bus

**Decision (proposed):** no D-Bus in the core. Each service listens on `/run/halo/<service>.sock` and speaks length-prefixed **protobuf** messages. Request/response, server-streamed events and file-descriptor passing (`SCM_RIGHTS`) are all supported.

- Schemas live in `system/proto/*.proto`. Code is generated for Rust (`prost`) and Dart (`protobuf`).
- Authentication uses `SO_PEERCRED`. The calling uid maps to an app id, and permissions are checked in the service against `halo-apps`' grants.
- `halo_sdk` (Dart) wraps the generated stubs in idiomatic APIs. Apps never touch sockets directly.
- Upstream daemons that need D-Bus (BlueZ, possibly ModemManager) are isolated behind a private `dbus-broker` instance that only the corresponding Halo service talks to. This is still an open question.

## 8. System services

| Service | Responsibility | Upstream it wraps |
|---|---|---|
| `halo-power` | Battery, charging, "full by" estimate, suspend/resume, wakelocks, thermal | kernel power_supply, sysfs |
| `halo-display` | Brightness (auto via ambient light sensor), panel on/off, night light | backlight sysfs, IIO |
| `halo-net` | Wi-Fi, connectivity checks, DNS, routing, airplane mode | wpa_supplicant (control socket), netlink |
| `halo-modem` | Cellular data, SMS, calls, SIM | ModemManager or our own QMI/AT layer (open) |
| `halo-bt` | Bluetooth pairing and audio profiles | BlueZ (open) |
| `halo-audio` | Volume streams (media, ring), routing, ducking | PipeWire + WirePlumber |
| `halo-notify` | Notification store, the Stream timeline, actions (Reply/Later), unread state | — |
| `halo-intel` | Summaries ("3 need you"), the Home "NOW" pick, Ask Halo | on-device model, optional cloud (opt-in) |
| `halo-apps` | Install, launch, lifecycle (foreground, background, frozen), permissions, recents list | cgroups v2, namespaces |
| `halo-settings` | Typed key/value settings with change subscriptions | — |
| `halo-time` | RTC, NTP, timezone, alarms that wake from suspend | RTC, `timerfd` |
| `halo-location` | GNSS and network location | gpsd or modem NMEA (open) |
| `halo-focus` | Focus modes (WORK · UNTIL 11:00) and notification filtering | — |
| `halo-update` | A/B OTA download, verify, apply, mark-good | — |
| `halo-keystore` | Keys and credentials, TPM/TEE when available | kernel keyrings |
| `halo-logd` | Log collection | — |

All services are Rust, async (tokio), single binary per service, supervised by haloinit, each with its own uid.

## 9. Security model

- **Per-app uid.** Each installed app gets its own uid, like Android.
- **Sandbox.** Apps launch through `halo-apps` into mount, pid, ipc and net namespaces (net only when the app has no network permission), with seccomp-bpf filters, Landlock, and cgroup v2 limits for CPU and memory, plus freezer for background apps.
- **Permissions.** Declared in the app manifest and granted at runtime through a shell prompt. Enforced in the services, not in the app.
- **Verified boot.** Signed boot image, dm-verity root hash in the signed boot params, rollback index.
- **Encryption.** `/data` is encrypted. The key is derived from the user's credential plus a hardware-backed key when one exists.
- **Updates.** Full-image A/B with signature verification. The bootloader rolls back automatically if the new slot never reaches "mark-good".

## 10. App model

- An app is a bundle: `manifest.toml` (id, version, permissions, entry, icon glyph), an AOT `libapp.so`, and `flutter_assets/`.
- All apps share one system copy of `libflutter_engine.so` (a pinned engine version per OS release). This is an ABI promise per OS major version.
- Lifecycle: `launching → foreground → background → frozen → killed`. The Recents slats show the frozen app's last buffer.
- Apps are written in Dart/Flutter with `halo_sdk` (services) and `halo_ui` (the design system). Third-party apps may use other Flutter widgets, but the system apps use only `halo_ui`.

## 11. Development hosts

- **Shell and apps on macOS or Linux desktop.** `shell/` and `apps/*` run as normal Flutter desktop apps against a **mock** `halo_sdk` backend (`HALO_BACKEND=mock`), sized 390 × 844. This is the main UI iteration loop.
- **Full OS in QEMU.** `aarch64` `virt` machine with virtio-gpu (virgl), virtio-input and virtio-net. Built inside a Linux build container (Docker/OrbStack/Lima on macOS).
- **Hardware.** See the target matrix in [BUILD.md](BUILD.md).
