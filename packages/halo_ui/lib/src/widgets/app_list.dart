import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';
import 'icons.dart';

/// One app in the Apps list: a 40 px app circle, the name, and mono tags on
/// the right (`WORK`, a Volt `ON ARC` for apps on the user's arc). 60 high
/// with a hairline below. A list, never a grid (DESIGN_SYSTEM §1).
class HaloAppRow extends StatelessWidget {
  const HaloAppRow({
    super.key,
    required this.label,
    required this.icon,
    this.image,
    this.work = false,
    this.onArc = false,
    this.onTap,
    this.onLongPress,
  });

  static const double height = 60;
  static const double circle = 40;

  final String label;

  /// The Halo glyph, drawn when there is no [image].
  final HaloIcons icon;
  final ImageProvider? image;
  final bool work;
  final bool onArc;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final tags = [if (work) 'Work', if (onArc) 'On arc'].join(', ');
    return Semantics(
      button: true,
      label: tags.isEmpty ? label : '$label, $tags',
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: halo.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: circle,
                  height: circle,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: halo.surface,
                    border: Border.all(color: halo.appBorder),
                  ),
                  child: image == null
                      ? HaloIcon(icon, size: 18, color: halo.text)
                      : ClipOval(
                          child: Image(
                            image: image!,
                            width: circle,
                            height: circle,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                            excludeFromSemantics: true,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.rowTitle.copyWith(color: halo.text),
                  ),
                ),
                if (work) ...[
                  const SizedBox(width: 10),
                  Text(
                    HaloType.upper('Work'),
                    style: HaloType.caption.copyWith(color: halo.muted),
                  ),
                ],
                if (onArc) ...[
                  const SizedBox(width: 10),
                  Text(
                    HaloType.upper('On arc'),
                    style: HaloType.caption.copyWith(color: halo.signalText),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Letter index down the right edge of the Apps list. Tap or drag along it to
/// jump; the letter in view is Volt (current).
class HaloLetterIndex extends StatelessWidget {
  const HaloLetterIndex({
    super.key,
    required this.letters,
    required this.onLetter,
    this.current,
  });

  static const double width = 28;

  final List<String> letters;
  final String? current;
  final ValueChanged<String> onLetter;

  void _pick(double dy, double height) {
    if (letters.isEmpty || height <= 0) return;
    final i = (dy / height * letters.length).floor().clamp(
      0,
      letters.length - 1,
    );
    onLetter(letters[i]);
  }

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _pick(d.localPosition.dy, box.maxHeight),
        onVerticalDragUpdate: (d) => _pick(d.localPosition.dy, box.maxHeight),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final l in letters)
                Text(
                  l,
                  key: ValueKey('index-$l'),
                  style: HaloType.labelSmall.copyWith(
                    color: l == current ? halo.signalText : halo.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
