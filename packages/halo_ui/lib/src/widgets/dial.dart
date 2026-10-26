import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// Ring dial on a `surface` plate (200 high). A tick ring surrounds a track
/// and a value arc; the value sits in the middle with a mono caption, and a
/// mono footer is below. Drag around the ring to set the value.
///
/// [active] means the value is automatic: the arc is Volt. A manual level is
/// bone. See docs/DESIGN_SYSTEM.md §6.
class HaloDial extends StatelessWidget {
  const HaloDial({
    super.key,
    required this.caption,
    required this.value,
    required this.footer,
    required this.onChanged,
    this.active = false,
  });

  /// Mono caption under the value (`Light`, `Sound`).
  final String caption;

  /// 0 to 1.
  final double value;
  final String footer;
  final bool active;
  final ValueChanged<double>? onChanged;

  static const double dialSize = 132;

  /// Maps a touch to a value: 0 at 12 o'clock, growing clockwise. Crossing
  /// the top never jumps from one end to the other.
  static double valueAt(Offset local, double previous) {
    final c = const Offset(dialSize / 2, dialSize / 2);
    final d = local - c;
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    final v = a / (2 * math.pi);
    if (previous > 0.75 && v < 0.25) return 1;
    if (previous < 0.25 && v > 0.75) return 0;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final percent = (v * 100).round();
    final halo = context.halo;
    return Semantics(
      slider: true,
      label: caption,
      value: '$percent%',
      increasedValue: '${(percent + 5).clamp(0, 100)}%',
      decreasedValue: '${(percent - 5).clamp(0, 100)}%',
      enabled: onChanged != null,
      onIncrease: onChanged == null
          ? null
          : () => onChanged!((v + 0.05).clamp(0.0, 1.0)),
      onDecrease: onChanged == null
          ? null
          : () => onChanged!((v - 0.05).clamp(0.0, 1.0)),
      child: ExcludeSemantics(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: halo.surface,
            shape: NotchBorder(
              radius: HaloRadii.notchXL,
              side: BorderSide(color: halo.border),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: onChanged == null
                    ? null
                    : (d) => onChanged!(valueAt(d.localPosition, v)),
                onPanUpdate: onChanged == null
                    ? null
                    : (d) => onChanged!(valueAt(d.localPosition, v)),
                child: SizedBox(
                  width: dialSize,
                  height: dialSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(dialSize),
                        painter: _DialPainter(
                          v,
                          active ? halo.dialAuto : halo.dialManual,
                          halo.ticks,
                          halo.track,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$percent',
                            style: HaloType.dialValue.copyWith(
                              color: halo.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            HaloType.upper(caption),
                            style: HaloType.dialCaption.copyWith(
                              color: halo.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                HaloType.upper(footer),
                style: HaloType.footer.copyWith(color: halo.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.value, this.arc, this.tickColor, this.track);

  final double value;
  final Color arc;
  final Color tickColor;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // 42 ticks on r=62: 1.5 px along the ring, 4 px deep (the SVG dash array
    // "1.5 7.776" on a 4 px stroke), starting at 3 o'clock.
    const ticks = 42;
    final tick = Paint()..color = tickColor;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (var k = 0; k < ticks; k++) {
      canvas.drawRect(const Rect.fromLTWH(60, 0, 4, 1.5), tick);
      canvas.rotate(2 * math.pi / ticks);
    }
    canvas.restore();

    final ring = Rect.fromCircle(center: c, radius: 50);
    canvas.drawCircle(
      c,
      50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = track,
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      value * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = arc,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.arc != arc ||
      old.tickColor != tickColor ||
      old.track != track;
}
