import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';
import 'tap_target.dart';

/// Which dot a timeline item gets.
enum HaloMark {
  /// Volt: the one in play.
  current,

  /// Flare: an alert.
  alert,

  /// A hollow ash ring: dealt with.
  read,
}

/// One timeline with time as the spine: a 1 px `line16` line down the left
/// and items and section labels beside it. Never stacked or grouped cards
/// (docs/DESIGN_SYSTEM.md §1).
class HaloTimeline extends StatelessWidget {
  const HaloTimeline({super.key, required this.children});

  /// [HaloTimelineSection]s and [HaloTimelineItem]s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 4,
          top: 8,
          bottom: 0,
          width: 1,
          child: ColoredBox(color: context.halo.guide),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// A mono label that splits the timeline (`NOW`, `EARLIER`).
class HaloTimelineSection extends StatelessWidget {
  const HaloTimelineSection(this.label, {super.key, this.gapBefore = 0});

  final String label;

  /// Extra space above the label.
  final double gapBefore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: gapBefore),
      child: SizedBox(
        height: 20,
        child: Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            HaloType.upper(label),
            style: HaloType.kicker.copyWith(color: context.halo.muted),
          ),
        ),
      ),
    );
  }
}

/// A text action under an item, underlined by a 1 px bar (`REPLY`, `LATER`).
class HaloTextAction extends StatelessWidget {
  const HaloTextAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.color,
    this.underline,
    this.style,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Defaults to the palette's muted color.
  final Color? color;

  /// Color of the bar. Defaults to [color].
  final Color? underline;

  /// Text style. Defaults to [HaloType.textAction].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.halo.muted;
    // The text stays as drawn; its touch target is 48.
    return HaloTapTarget(
      properties: SemanticsProperties(
        button: true,
        label: label,
        onTap: onPressed,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: underline ?? color)),
          ),
          child: Text(
            HaloType.upper(label),
            style: (style ?? HaloType.textAction).copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

/// One entry: a dot on the spine, a mono header with the time on the right,
/// the text, and optional actions.
class HaloTimelineItem extends StatelessWidget {
  const HaloTimelineItem({
    super.key,
    required this.mark,
    required this.source,
    required this.time,
    required this.body,
    this.actions = const [],
    this.gapBefore = 20,
  });

  final HaloMark mark;

  /// Mono header (`Messages · Elif`, `Calendar`).
  final String source;

  /// Mono time on the right (`9:39`, `Yest`).
  final String time;
  final String body;
  final List<Widget> actions;

  /// Space above the item. 4 after a section label, 20 between items.
  final double gapBefore;

  @override
  Widget build(BuildContext context) {
    final read = mark == HaloMark.read;
    final halo = context.halo;
    // The text is one labelled node (it merges into a tap or a swipe around
    // the item); each action is a node of its own, so a screen reader can
    // reach them.
    return Padding(
      padding: EdgeInsets.only(top: gapBefore),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: ExcludeSemantics(child: _Dot(mark)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: '$source, $time. $body',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A long source (an app and a long title) ellipsizes; the
                      // time always shows.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              HaloType.upper(source),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.status.copyWith(color: halo.text),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            HaloType.upper(time),
                            style: HaloType.status.copyWith(color: halo.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: HaloType.body.copyWith(
                          color: read ? halo.textDim : halo.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 18),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 9 px node. A solid ring of the ground color around it hides the spine.
class _Dot extends StatelessWidget {
  const _Dot(this.mark);

  final HaloMark mark;

  @override
  Widget build(BuildContext context) {
    final read = mark == HaloMark.read;
    final halo = context.halo;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (mark) {
          HaloMark.current => halo.signalLine,
          HaloMark.alert => halo.flare,
          HaloMark.read => halo.ground,
        },
        border: read ? Border.all(color: halo.muted, width: 1.5) : null,
        boxShadow: [BoxShadow(color: halo.ground, spreadRadius: read ? 3 : 4)],
      ),
    );
  }
}
