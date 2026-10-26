import 'package:flutter/widgets.dart';

import '../notch_border.dart';
import '../palette.dart';
import '../type.dart';
import 'kicker.dart';

/// One choice in a [HaloMenu].
class HaloMenuItem {
  const HaloMenuItem(this.label, {required this.onPressed});

  final String label;
  final VoidCallback? onPressed;
}

/// A group of [HaloMenuItem]s under an ash mono label (`SHORTCUTS`).
class HaloMenuSection {
  const HaloMenuSection({required this.label, required this.items});

  final String label;
  final List<HaloMenuItem> items;
}

/// The long-press card for an app: a solid `surface` notch (`notchXL`, `line08`
/// border) with the app's name, an optional mono tag, and sections of rows
/// separated by hairlines. Solid, never blurred or translucent.
class HaloMenu extends StatelessWidget {
  const HaloMenu({
    super.key,
    required this.title,
    required this.sections,
    this.tag,
  });

  static const double rowHeight = 48;

  final String title;
  final String? tag;
  final List<HaloMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: ShapeDecoration(
        color: halo.surface,
        shape: NotchBorder(
          radius: HaloRadii.notchXL,
          side: BorderSide(color: halo.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.title.copyWith(color: halo.text),
                ),
              ),
              if (tag != null)
                Text(
                  HaloType.upper(tag!),
                  style: HaloType.caption.copyWith(color: halo.muted),
                ),
            ],
          ),
          for (final s in sections)
            if (s.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              HaloKicker(s.label, color: halo.muted, square: false),
              const SizedBox(height: 4),
              for (var i = 0; i < s.items.length; i++)
                _Row(item: s.items[i], last: i == s.items.length - 1),
            ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.last});

  final HaloMenuItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final enabled = item.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: item.label,
      onTap: item.onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: item.onPressed,
          child: Container(
            height: HaloMenu.rowHeight,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: last
                  ? null
                  : Border(bottom: BorderSide(color: halo.divider)),
            ),
            child: Text(
              item.label,
              style: HaloType.rowTitle.copyWith(
                color: enabled ? halo.text : halo.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
