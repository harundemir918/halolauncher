import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// Volt play/pause square next to a `surface` card with the track title, the
/// mono artist and a 3 px progress bar. 64 high.
class HaloMediaStrip extends StatelessWidget {
  const HaloMediaStrip({
    super.key,
    required this.title,
    required this.artist,
    required this.progress,
    required this.playing,
    required this.onPlayPause,
  });

  final String title;
  final String artist;

  /// 0 to 1.
  final double progress;
  final bool playing;
  final VoidCallback? onPlayPause;

  static const _buttonRadius = BorderRadius.only(
    topLeft: Radius.circular(26),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(4),
    bottomLeft: Radius.circular(4),
  );

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? 'Pause' : 'Play',
            onTap: onPlayPause,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPlayPause,
                child: Container(
                  width: 64,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: halo.signalFill,
                    shape: NotchBorder(
                      radius: _buttonRadius,
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: ShapeDecoration(
                color: halo.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: HaloRadii.flat,
                  side: BorderSide(color: halo.border),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.mediaTitle.copyWith(color: halo.text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        HaloType.upper(artist),
                        style: HaloType.caption.copyWith(color: halo.muted),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 3,
                    child: ColoredBox(
                      color: halo.mediaTrack,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: SizedBox(
                            height: 3,
                            child: ColoredBox(color: halo.mediaFill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
