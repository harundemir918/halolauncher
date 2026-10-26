# Halo Launcher

An Android home-screen launcher built with Flutter, based on the Halo design language.

> No grid · No glass · No dock.

Halo puts what matters now at the top of the screen and your apps on an arc within thumb reach. Notifications become one stream that Halo summarizes. Controls look like controls.

| Lock | Home | Recents | Switchboard | Stream | System |
|---|---|---|---|---|---|
| ![](design/screens/lock.png) | ![](design/screens/home.png) | ![](design/screens/recents.png) | ![](design/screens/switchboard.png) | ![](design/screens/stream.png) | ![](design/screens/system.png) |

Every screen also has a light version (`design/screens/*_light.png`).

## Status

Pre-alpha. The Halo OS project is being turned into an Android launcher. The design system (`packages/halo_ui`), the service interface with its mock backend (`packages/halo_sdk`) and all six screens running on macOS with mock data carry over. Android integration comes next. See [ROADMAP.md](ROADMAP.md).

## What it does on Android

| Screen | On Android |
|---|---|
| **Home Arc** | The launcher's home screen (`CATEGORY_HOME`). Installed apps sit on the arc, with "now", today's agenda and the top message above it. |
| **Stream** | Notifications from every app, read through a notification listener and summarized by Halo. |
| **Switchboard** | Quick controls: brightness, volume, media, battery, and connection toggles where Android allows it. |
| **Recents** | Recently used apps, from usage stats. |
| **System** | The launcher's own settings (appearance, text size, arc apps), plus shortcuts into Android Settings. |
| **Lock** | Android doesn't let a launcher replace the lock screen. The Lock design becomes an at-a-glance screen inside the launcher (see the open questions in the roadmap). |

## Layout

```
design/      design exports (PNG) and sources (.dc.html). The visual reference
docs/        design system and project docs
packages/    halo_ui (tokens, fonts, widgets), halo_sdk (service API, mock and Android backends)
shell/       the launcher app (Flutter). To be moved to launcher/ when the Android target is added
```

## Run it

```sh
# On macOS, 390 × 844 window, mock data
cd shell && flutter run -d macos --dart-define=HALO_BACKEND=mock

# Token and widget gallery
cd packages/halo_ui/example && flutter run -d macos
```

Running on an Android device comes with Phase 1 of the roadmap.

## Documentation

- [ROADMAP.md](ROADMAP.md): phases and exit criteria
- [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md): tokens, components, screens
- [CLAUDE.md](CLAUDE.md): working guide for AI agents and contributors
