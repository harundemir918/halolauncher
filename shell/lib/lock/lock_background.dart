import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:halo_ui/halo_ui.dart';

/// Concentric hairline rings around a point at the bottom right, one Volt arc
/// segment, and a Flare dot while something is unread. The center is 30 px in
/// from the right and 144 px up from the bottom (390 × 844 reference).
class LockBackground extends StatelessWidget {
  const LockBackground({super.key, required this.hasUnread});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.infinite,
      painter: _RingsPainter(hasUnread: hasUnread, halo: context.halo),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.hasUnread, required this.halo});

  final bool hasUnread;
  final HaloPalette halo;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width - 30, size.height - 144);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = halo.ringsLock;
    for (var r = 70.0; r <= 490; r += 70) {
      canvas.drawCircle(c, r, ring);
    }

    // Volt segment on the r=280 ring: 220 of 1760 px of circumference,
    // starting at -110 degrees.
    const radius = 280.0;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -110 * math.pi / 180,
      220 / (2 * math.pi * radius) * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = halo.arcStroke
        ..strokeCap = StrokeCap.round
        ..color = halo.signalLine,
    );

    if (hasUnread) {
      canvas.drawCircle(
        c + const Offset(-48, -132),
        5,
        Paint()..color = halo.flare,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.hasUnread != hasUnread || old.halo != halo;
}
