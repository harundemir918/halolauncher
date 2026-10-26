# Building Halo OS

Status: **planned**. None of the commands below exist yet. This document describes the build system we are going to write. Update it when the real commands land.

## 1. Principles

- One command produces a bootable image from a clean checkout: `./halo build --target <target>`.
- Every upstream source is pinned by version and checksum in `third_party/manifest.toml`. Sources are downloaded into a cache and are never vendored into git.
- Builds are hermetic and reproducible. Everything runs inside the pinned build container, so macOS hosts work the same as Linux hosts.
- No distribution packages end up in the image. The container provides the *host* tools. The *target* is built entirely from our recipes.

### Build host

Kernel, rootfs and image builds need Linux. On macOS they run in a Lima VM defined in `build/lima/halo-builder.yaml` (Debian 13, host tools only, same package list as `build/container/Containerfile`):

```sh
limactl start --name halo-builder build/lima/halo-builder.yaml   # once
limactl shell halo-builder                                       # work inside
```

Lima mounts your home directory read-only at the same path, so the repo is visible in the VM. Build output goes to the VM's own disk. Copy artifacts out with `limactl copy`.

## 2. Toolchain

| Piece | Choice (proposed) | Why |
|---|---|---|
| Compiler | LLVM/Clang (pinned), cross for `aarch64-linux-gnu` and `x86_64-linux-gnu` | The Flutter engine builds with Clang. One compiler for everything. |
| libc | glibc (built from source into our sysroot) | The Flutter engine and Mesa are best supported on glibc. musl stays an option for static system binaries. |
| C++ runtime | libc++ | Matches the Flutter engine's build |
| Rust | Pinned stable via `rust-toolchain.toml`, targets `aarch64-unknown-linux-gnu`, `x86_64-unknown-linux-gnu` | System services, init, compositor |
| Flutter | Pinned SDK version (`.flutter-version`) plus a matching engine build from source (`third_party/flutter-engine`) | Embedder API, AOT `libapp.so`, `libflutter_engine.so` |
| Kernel | Mainline LTS, version pinned in `kernel/VERSION`, config fragments in `kernel/configs/` | |

## 3. Pipeline

```
fetch      → third_party sources into ~/.cache/halo/src (checksummed)
toolchain  → clang + glibc + libc++ sysroot per arch
kernel     → Image / bzImage + dtbs + modules
base       → recipes in build/recipes/*.toml (libdrm, mesa, libinput, ...)
engine     → libflutter_engine.so (release, embedder target)
system     → cargo build --release (haloinit, compositor, services)
embedder   → halo-embedder (C++)
dart       → flutter build bundle + gen_snapshot AOT for shell/ and apps/*
rootfs     → assemble staging tree → EROFS → dm-verity hash tree
image      → GPT: boot_a/b, system_a/b, data · sign
```

Recipes are small declarative TOML files (source, version, configure/build/install steps, deps) run by `halo`, our build driver (Rust, in `build/halo/`). We don't use Buildroot or Yocto. We want to own the build and keep it understandable. Buildroot can still serve as a reference for tricky packages.

## 4. Targets

| Target | Arch | Purpose | Phase |
|---|---|---|---|
| `qemu-arm64` | aarch64 | Primary development and CI target. `virt` + virtio-gpu (virgl), virtio-input, virtio-net | 1 |
| `qemu-x86_64` | x86_64 | Fast KVM on Linux hosts | 1 |
| `rpi5-dev` | aarch64 | First real hardware: Raspberry Pi 5 + official 7" touch display (or a DSI portrait panel). Good mainline support, cheap, no modem | 5 |
| `phone-1` | aarch64 | First real phone. Candidates with good mainline support: OnePlus 6/6T (sdm845), PinePhone Pro (rk3399s), Fairphone. **Open, decide before Phase 5 ends.** | 5–6 |

## 5. Planned commands

```sh
# UI iteration on the host (no OS build needed)
cd shell && flutter run -d macos --dart-define=HALO_BACKEND=mock

# Full OS
./halo doctor                       # checks host: container runtime, disk, KVM
./halo build --target qemu-arm64    # full image into out/qemu-arm64/
./halo run   --target qemu-arm64    # boots in QEMU with a 390x844 (x3 scale) window
./halo build kernel|system|shell    # rebuild one stage
./halo flash --target rpi5-dev --device /dev/sdX

# Tests
cargo test --workspace              # in system/
flutter test                        # in packages/* , shell/, apps/*
flutter test --update-goldens       # in shell/, refresh goldens (review the diff!)
./halo test boot --target qemu-arm64   # boots, waits for Lock, takes a screenshot
```

## 6. Output

```
out/<target>/
├── boot.img        kernel + initramfs + dtb (signed)
├── system.erofs    root image
├── system.verity   hash tree + root hash
├── halo.img        full disk image (GPT)
└── sdk/            sysroot + headers for building the embedder/apps out-of-tree
```

## 7. Booting Halo in QEMU today

Until the `halo` driver exists, `tools/dev-boot.sh` builds and boots the image inside the Lima VM (§1 "Build host"). The recipes in `build/recipes/` are run by `tools/recipe.py`.

```sh
# On the Mac: the shell as a Flutter bundle
(cd shell && flutter build bundle --debug --dart-define=HALO_BACKEND=mock)

# In the VM (limactl shell halo-builder), from the repo
tools/dev-boot.sh kernel     # Linux 6.18, our config fragment
tools/dev-boot.sh sysroot    # glibc 2.43 from source, the pinned Flutter engine
tools/dev-boot.sh initrd     # halo-initramfs
tools/dev-boot.sh rootfs     # haloinit, the embedder, glibc, engine and shell in an EROFS image
tools/dev-boot.sh test       # headless: expects to boot from the EROFS image
```

To use it, run it in a native window on the Mac (needs `brew install qemu`; uses Apple's hypervisor):

```sh
tools/run-on-mac.sh           # copies the image out of the VM, opens a window; click and drag as touch
tools/run-on-mac.sh --no-copy # run the copy from last time
```

The window is about 392 x 848 points: the guest display is 2x (784 x 1696) and the shell renders at pixel ratio 2 (the embedder derives the ratio from the display width). The width is a multiple of 8 and the virtio-gpu has `edid=off`: with EDID on, the Cocoa window tells the guest its size about a second after boot, the guest DRM driver reprobes and disables the CRTC, and because the software renderer only draws on change the window then stays on "Display output is not active". (Headless QEMU never sends that update, so tests without a window do not show it.) `HALO_SCALE=1` gives a smaller window for a small screen. `HALO_HZ=120` paces the shell's frames at 120 Hz; `HALO_TRACE=1` prints the frame rate and the per-frame present cost to the terminal. Frames reach the display through DRM/KMS (a dumb buffer flushed every frame): the fbdev emulation flushes at most every 50 ms, which would cap what you see at 20 fps. The kernel runs with `consoleblank=0`: with the default blank timeout the display powers down after ten minutes and QEMU shows "Display output is not active". A real power service will own that later (`halo-display`).

`tools/dev-boot.sh vnc` also works, but macOS Screen Sharing refuses to connect to the Mac it runs on (`localhost` counts), so it needs another VNC client.

What runs: the kernel starts `halo-initramfs`, which mounts the EROFS image and switches root. `haloinit` (PID 1) mounts `/tmp` and `/run` and starts `halo-fbdev-embedder`, which runs the shell on the engine's software renderer and draws into the virtio-gpu framebuffer. Touch comes from the virtio tablet through evdev. QEMU uses KVM when the VM has `/dev/kvm` (`nestedVirtualization` in `build/lima/halo-builder.yaml`, Apple M3 or later), else TCG.

Interim, all tracked in the ROADMAP: the build host's gcc builds glibc and the embedder (D-007 wants LLVM), and the engine is a prebuilt artifact (D-016).
