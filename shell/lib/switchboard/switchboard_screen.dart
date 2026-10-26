import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
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
                        footer: q.brightnessAuto ? 'Auto · on' : 'Manual',
                        onChanged: b.setBrightness,
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
              Positioned(
                top: 336,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Column(
                  children: [
                    for (final t in q.toggles) ...[
                      HaloToggleRow(
                        title: t.title,
                        subtitle: t.detail,
                        value: t.on,
                        onChanged: (on) => b.setToggle(t.id, on),
                      ),
                      if (t != q.toggles.last)
                        const SizedBox(height: HaloSpace.g6),
                    ],
                  ],
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
