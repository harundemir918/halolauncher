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
  const RecentsScreen({super.key, required this.backend});

  final HaloBackend backend;

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  late int _focused = widget.backend.recents.length ~/ 2;

  void _close(HaloSlatData slat) {
    final before = widget.backend.recents;
    final closed = before.indexWhere((a) => a.id == slat.id);
    if (closed < 0) return;
    widget.backend.closeRecent(slat.id);
    final n = before.length - 1;
    setState(() {
      // Keep the same app focused; if the focused one closed, the next one
      // slides into its place (or the last, if it was last).
      if (closed < _focused) _focused--;
      _focused = n == 0 ? 0 : _focused.clamp(0, n - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: widget.backend,
      builder: (context, b) {
        final recents = b.recents;
        final slats = [
          for (final a in recents)
            HaloSlatData(
              id: a.id,
              label: a.label,
              icon: iconFor(a),
              preview: previewFor(a.id, a.label),
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
                    ? Center(
                        child: Text(
                          HaloType.upper('No recent apps'),
                          style: HaloType.kicker.copyWith(
                            color: context.halo.muted,
                          ),
                        ),
                      )
                    : HaloSlats(
                        slats: slats,
                        focusedIndex: _focused.clamp(0, slats.length - 1),
                        onFocus: (i) => setState(() => _focused = i),
                        onClose: _close,
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
