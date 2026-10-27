import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
import '../shell_nav.dart';
import '../status_bar.dart';

/// Switchboard: quick controls that look like controls. Two ring dials, a
/// toggle row per radio, the media strip and the battery cells.
class SwitchboardScreen extends StatelessWidget {
  const SwitchboardScreen({super.key, required this.backend});

  final HaloBackend backend;

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: backend,
      builder: (context, b) {
        final q = b.quick;
        final status = b.status;
        final media = q.media;
        return ColoredBox(
          color: context.halo.ground,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ShellStatusBar(backend: b),
              ),
              Positioned(
                top: 54,
                left: HaloSpace.gutter,
                child: Text(
                  'Switchboard',
                  style: HaloType.screenTitle.copyWith(
                    color: context.halo.text,
                  ),
                ),
              ),
              // Top right, inside every phone's frame (it is shorter than 844 on
              // a phone with a cutout and a nav bar, so nothing sits below the
              // battery cells).
              const Positioned(
                top: 62,
                right: HaloSpace.gutter,
                child: _SystemButton(),
              ),
              Positioned(
                top: 116,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Row(
                  children: [
                    Expanded(
                      child: HaloDial(
                        caption: 'Light',
                        value: q.brightness,
                        active: q.brightnessAuto,
                        footer: !q.brightnessWritable
                            ? 'Tap to allow'
                            : q.brightnessAuto
                            ? 'Auto · on'
                            : 'Manual',
                        // Without Android's Write settings grant the dial only
                        // reads; the footer opens the screen that gives it.
                        onChanged: q.brightnessWritable
                            ? b.setBrightness
                            : null,
                        onFooterTap: () =>
                            b.setBrightnessAuto(!q.brightnessAuto),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HaloDial(
                        caption: 'Sound',
                        value: q.volume,
                        footer: q.volumeFooter,
                        onChanged: b.setVolume,
                      ),
                    ),
                  ],
                ),
              ),
              // A fixed band between the dials and the media strip; with the
              // theme row there are six rows, so the list scrolls.
              Positioned(
                top: 336,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                height: 296,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: q.toggles.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: HaloSpace.g6),
                  itemBuilder: (context, i) {
                    if (i == q.toggles.length) {
                      return _ThemeRow(backend: b);
                    }
                    final t = q.toggles[i];
                    return HaloToggleRow(
                      title: t.title,
                      subtitle: t.detail,
                      value: t.on,
                      onChanged: (on) => b.setToggle(t.id, on),
                    );
                  },
                ),
              ),
              if (media != null)
                Positioned(
                  top: 644,
                  left: HaloSpace.gutter,
                  right: HaloSpace.gutter,
                  child: HaloMediaStrip(
                    title: media.title,
                    artist: media.artist,
                    progress: media.progress,
                    playing: media.playing,
                    onPlayPause: () => b.setPlaying(!media.playing),
                    onNext: () => b.skipMedia(next: true),
                    onPrevious: () => b.skipMedia(next: false),
                  ),
                ),
              Positioned(
                top: 730,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          HaloType.upper('Battery ${status.batteryPercent}%'),
                          style: HaloType.footer.copyWith(
                            color: context.halo.muted,
                          ),
                        ),
                        if (status.fullBy != null)
                          Text(
                            HaloType.upper('Full by ${status.fullBy}'),
                            style: HaloType.footer.copyWith(
                              color: context.halo.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    HaloBatteryCells(fraction: status.battery),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dark or light, as a row under Focus. On means dark, whatever Auto resolves
/// to now; flipping it sets that appearance by hand (System has Auto).
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.backend});

  final HaloBackend backend;

  @override
  Widget build(BuildContext context) {
    final dark = !context.halo.isLight;
    return HaloToggleRow(
      title: 'Theme',
      subtitle: dark ? 'Dark' : 'Light',
      value: dark,
      onChanged: (on) =>
          backend.setAppearance(on ? Appearance.dark : Appearance.light),
    );
  }
}

/// The way into System, Halo's settings.
class _SystemButton extends StatelessWidget {
  const _SystemButton();

  @override
  Widget build(BuildContext context) {
    final open = ShellNav.maybeOf(context)?.open;
    return HaloButton(
      label: 'System',
      size: HaloButtonSize.small,
      variant: HaloButtonVariant.secondary,
      trailing: HaloIcon(HaloIcons.chevronRight, size: 14),
      onPressed: open == null ? null : () => open('system'),
    );
  }
}
