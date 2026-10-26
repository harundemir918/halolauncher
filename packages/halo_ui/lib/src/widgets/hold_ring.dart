import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';

/// The "hold to open" ring on Lock: a `line16` track, a Volt arc that follows
/// [progress] (0 to 1, from 12 o'clock) and a Volt center dot, with a mono
/// caption below. 104 wide.
class HaloHoldRing extends StatelessWidget {
  const HaloHoldRing({
    super.key,
    required this.progress,
    this.label = 'Hold to open',
  });

  /// The design's resting arc: 84 of the 276 px circumference.
  static const double resting = 84 / 276;

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      label: 'Press and hold to open',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: const Size.square(104),
                painter: _RingPainter(
                  progress.clamp(0.0, 1.0),
                  halo.holdTrack,
                  halo.signalLine,
                  halo.holdDot,
                ),
              ),
              // The caption hangs 4 px below the ring box, like the design.
              Positioned(
                left: 0,
                right: 0,
                bottom: -4,
                child: Center(
                  child: Text(
                    HaloType.upper(label),
                    style: HaloType.labelSmall.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: halo.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.track, this.arc, this.dot);

  final double progress;
  final Color track;
  final Color arc;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: 44);
    canvas.drawCircle(
      c,
      44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = track,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = arc,
    );
    canvas.drawCircle(c, 7, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.arc != arc ||
      old.dot != dot;
}
