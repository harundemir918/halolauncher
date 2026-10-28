import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';
import 'marquee.dart';

/// Volt play/pause square next to a `surface` card with the track title, the
/// mono artist below it and a 3 px progress bar. 64 high.
///
/// A title too long for the card slides, so all of it can be read. With
/// [onSeek] the bottom of the card is a seek bar: drag along it, or tap, to
/// move the track; a flick across the title and artist still skips.
class HaloMediaStrip extends StatefulWidget {
  const HaloMediaStrip({
    super.key,
    required this.title,
    required this.artist,
    required this.progress,
    required this.playing,
    required this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onSeek,
  });

  final String title;
  final String artist;

  /// 0 to 1.
  final double progress;
  final bool playing;
  final VoidCallback? onPlayPause;

  /// A flick left across the card skips to the next track, a flick right to
  /// the previous one. The design has no skip buttons.
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  /// Called with where on the track (0 to 1) the bar was dragged or tapped to,
  /// when the finger lets go. Null when the player can't seek: the bar only
  /// shows then.
  final ValueChanged<double>? onSeek;

  /// A flick must be faster than this many logical pixels per second.
  static const _flick = 300.0;

  static const _buttonRadius = BorderRadius.only(
    topLeft: Radius.circular(26),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(4),
    bottomLeft: Radius.circular(4),
  );

  /// The side padding of the card, which the bar spans inside of.
  static const _pad = 14.0;

  /// How tall the seek zone at the bottom of the card is.
  static const seekZone = 28.0;

  @override
  State<HaloMediaStrip> createState() => _HaloMediaStripState();
}

class _HaloMediaStripState extends State<HaloMediaStrip> {
  /// Where the finger has the bar while it is dragged, else null.
  double? _scrub;

  double _at(double dx, double width) =>
      ((dx - HaloMediaStrip._pad) / (width - 2 * HaloMediaStrip._pad)).clamp(
        0.0,
        1.0,
      );

  Widget _seekZone(double progress) {
    return LayoutBuilder(
      builder: (context, box) => Semantics(
        container: true,
        slider: true,
        label: 'Track position',
        value: '${(progress * 100).round()}%',
        increasedValue: '${((progress + 0.05).clamp(0.0, 1.0) * 100).round()}%',
        decreasedValue: '${((progress - 0.05).clamp(0.0, 1.0) * 100).round()}%',
        onIncrease: () => widget.onSeek!((progress + 0.05).clamp(0.0, 1.0)),
        onDecrease: () => widget.onSeek!((progress - 0.05).clamp(0.0, 1.0)),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // From where the finger came down, not where the drag was sensed.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => widget.onSeek!(_at(d.localPosition.dx, box.maxWidth)),
          onHorizontalDragStart: (d) =>
              setState(() => _scrub = _at(d.localPosition.dx, box.maxWidth)),
          onHorizontalDragUpdate: (d) =>
              setState(() => _scrub = _at(d.localPosition.dx, box.maxWidth)),
          onHorizontalDragEnd: (_) {
            final to = _scrub;
            setState(() => _scrub = null);
            if (to != null) widget.onSeek!(to);
          },
          onHorizontalDragCancel: () => setState(() => _scrub = null),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final playing = widget.playing;
    final progress = (_scrub ?? widget.progress).clamp(0.0, 1.0);
    final seeking = _scrub != null;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? 'Pause' : 'Play',
            onTap: widget.onPlayPause,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPlayPause,
                child: Container(
                  width: 64,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: halo.signalFill,
                    shape: NotchBorder(
                      radius: HaloMediaStrip._buttonRadius,
                      side: halo.fillSide,
                    ),
                  ),
                  child: CustomPaint(
                    size: const Size.square(24),
                    painter: _GlyphPainter(
                      playing: playing,
                      color: halo.onSignal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -HaloMediaStrip._flick) widget.onNext?.call();
                if (v > HaloMediaStrip._flick) widget.onPrevious?.call();
              },
              child: Container(
                decoration: ShapeDecoration(
                  color: halo.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: HaloRadii.flat,
                    side: BorderSide(color: halo.border),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HaloMediaStrip._pad,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HaloMarquee(
                                widget.title,
                                style: HaloType.mediaTitle.copyWith(
                                  color: halo.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                HaloType.upper(widget.artist),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HaloType.caption.copyWith(
                                  color: halo.muted,
                                ),
                              ),
                            ],
                          ),
                          // Thicker while it is being dragged, so it is plain
                          // that the finger has it.
                          SizedBox(
                            height: seeking ? 7 : 3,
                            child: ColoredBox(
                              color: halo.mediaTrack,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progress,
                                  child: SizedBox(
                                    height: seeking ? 7 : 3,
                                    child: ColoredBox(color: halo.mediaFill),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSeek != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: HaloMediaStrip.seekZone,
                        child: _seekZone(progress),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pause (two bars) or play (a triangle), filled with [color], on a 24 grid.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (playing) {
      // Pause: rects at x 6 and x 14, 4 wide and 16 tall, radius 1.
      for (final x in const [6.0, 14.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 4, 4, 16),
            const Radius.circular(1),
          ),
          paint,
        );
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(8, 5)
          ..lineTo(19, 12)
          ..lineTo(8, 19)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.playing != playing || old.color != color;
}
