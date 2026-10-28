import 'package:flutter/widgets.dart';

import '../notch_border.dart';
import '../palette.dart';
import '../type.dart';
import 'icons.dart';

/// One app in the Apps list: a 40 px app circle, the name, and mono tags on
/// the right (`WORK`, `PRIVATE`, a Volt `ON ARC` for apps on the user's arc). 60 high
/// with a hairline below. A list, never a grid (DESIGN_SYSTEM §1).
class HaloAppRow extends StatelessWidget {
  const HaloAppRow({
    super.key,
    required this.label,
    required this.icon,
    this.image,
    this.work = false,
    this.privateSpace = false,
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
  final bool privateSpace;
  final bool onArc;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final tags = [
      if (work) 'Work',
      if (privateSpace) 'Private',
      if (onArc) 'On arc',
    ].join(', ');
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
                if (privateSpace) ...[
                  const SizedBox(width: 10),
                  Text(
                    HaloType.upper('Private'),
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
    // A scrubber for a thumb: a screen reader has the list itself, in order,
    // and search, so this strip of letters would only be noise to it.
    return ExcludeSemantics(child: _scrubber(halo));
  }

  Widget _scrubber(HaloPalette halo) {
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

/// A search result that isn't an app: a contact (initials in a notch, since
/// circles are for apps only), a settings page, or an ask such as "Search
/// your contacts too". 60 high with a hairline below, like [HaloAppRow].
/// [captionSignal] makes the caption Volt, for the one primary action.
class HaloResultRow extends StatelessWidget {
  const HaloResultRow({
    super.key,
    required this.title,
    this.initials,
    this.caption,
    this.captionSignal = false,
    this.onTap,
  });

  final String title;

  /// Shown in a 40 px notch on the left; none when null.
  final String? initials;
  final String? caption;
  final bool captionSignal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      button: true,
      label: caption == null ? title : '$title, $caption',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: HaloAppRow.height,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: halo.divider)),
            ),
            child: Row(
              children: [
                if (initials != null) ...[
                  Container(
                    width: HaloAppRow.circle,
                    height: HaloAppRow.circle,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: halo.surface,
                      shape: NotchBorder(
                        radius: HaloRadii.notchM,
                        side: BorderSide(color: halo.border),
                      ),
                    ),
                    child: Text(
                      initials!,
                      style: HaloType.avatar.copyWith(color: halo.text),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.rowTitle.copyWith(color: halo.text),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    HaloType.upper(caption!),
                    style: HaloType.caption.copyWith(
                      color: captionSignal ? halo.signalText : halo.muted,
                    ),
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
