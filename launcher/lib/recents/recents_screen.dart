import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../app_icons.dart';
import '../backend_builder.dart';
import '../format.dart';
import '../status_bar.dart';
import 'previews.dart';

/// Recents: slats in a row. Collapsed slats on the sides, the focused one in
/// the middle showing its app. Flick a slat up to close it.
class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key, required this.backend, this.onLaunch});

  final HaloBackend backend;

  /// Tapping the focused slat switches to its app.
  final ValueChanged<String>? onLaunch;

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  /// As many as the design shows: more would squeeze the focused slat. A
  /// closed one is replaced by the next recent app.
  static const maxSlats = 5;

  late int _focused = widget.backend.recents.length.clamp(0, maxSlats) ~/ 2;

  void _close(HaloSlatData slat) {
    final before = widget.backend.recents.take(maxSlats).toList();
    final closed = before.indexWhere((a) => a.id == slat.id);
    if (closed < 0) return;
    widget.backend.closeRecent(slat.id);
    final n = widget.backend.recents.length.clamp(0, maxSlats);
    setState(() {
      // Keep the same app focused; if the focused one closed, the next one
      // slides into its place (or the last, if it was last).
      if (closed < _focused) _focused--;
      _focused = n == 0 ? 0 : _focused.clamp(0, n - 1);
    });
  }

  /// The app's own icon on a collapsed slat: a design glyph for a role app
  /// (null here), else the icon's monochrome mask tinted like the arc's.
  Widget? _slatIcon(BuildContext context, HaloAppInfo a) {
    if (a.glyph != null) return null;
    final mono = monoImageFor(a);
    if (mono != null) {
      return Image(
        image: mono,
        width: 20,
        height: 20,
        color: context.halo.text,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
      );
    }
    final icon = imageFor(a);
    return icon == null ? null : Image(image: icon, width: 22, height: 22);
  }

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: widget.backend,
      builder: (context, b) {
        final recents = b.recents.take(maxSlats).toList();
        final slats = [
          for (final a in recents)
            HaloSlatData(
              id: a.id,
              label: a.label,
              icon: iconFor(a),
              preview: previewFor(a),
              iconWidget: _slatIcon(context, a),
            ),
        ];
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
                top: 56,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Recent',
                          style: HaloType.screenTitle.copyWith(
                            color: context.halo.text,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          HaloFormat.two(recents.length),
                          style: HaloType.count.copyWith(
                            color: context.halo.signalText,
                          ),
                        ),
                      ],
                    ),
                    if (recents.isNotEmpty)
                      HaloTextAction(
                        'Clear all',
                        color: context.halo.text,
                        underline: context.halo.muted,
                        style: HaloType.segment,
                        onPressed: b.clearRecents,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 120,
                left: 16,
                right: 16,
                height: 620,
                child: slats.isEmpty
                    ? (b.canReadUsage
                          ? Center(
                              child: Text(
                                HaloType.upper('No recent apps'),
                                style: HaloType.kicker.copyWith(
                                  color: context.halo.muted,
                                ),
                              ),
                            )
                          : _UsageAsk(onAllow: b.requestUsageAccess))
                    : HaloSlats(
                        slats: slats,
                        focusedIndex: _focused.clamp(0, slats.length - 1),
                        onFocus: (i) => setState(() => _focused = i),
                        onClose: _close,
                        onOpen: (s) => widget.onLaunch?.call(s.id),
                      ),
              ),
              if (slats.isNotEmpty)
                Positioned(
                  top: 764,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      HaloIcon(
                        HaloIcons.chevronUp,
                        size: 16,
                        color: context.halo.muted,
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        HaloType.upper('Flick a slat up to close'),
                        style: HaloType.kicker.copyWith(
                          color: context.halo.muted,
                        ),
                      ),
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

/// Without usage access: what Recents does, that it stays on the phone, and
/// the one way to allow it (CLAUDE.md rules 5 and 6).
class _UsageAsk extends StatelessWidget {
  const _UsageAsk({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The apps you used\nlast, in a row.',
              style: HaloType.headline.copyWith(color: halo.text),
            ),
            const SizedBox(height: 14),
            Text(
              HaloType.upper(
                'Halo needs usage access to see which apps you used. '
                'Nothing leaves this phone.',
              ),
              style: HaloType.context.copyWith(color: halo.muted),
            ),
            const SizedBox(height: 18),
            HaloButton(
              key: const ValueKey('usage-access'),
              label: 'Allow access',
              onPressed: onAllow,
            ),
          ],
        ),
      ),
    );
  }
}
