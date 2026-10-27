import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// Ring dial on a `surface` plate (200 high). A tick ring surrounds a track
/// and a value arc; the value sits in the middle with a mono caption, and a
/// mono footer is below. Touch or drag around the ring to set the value.
///
/// The dial takes a finger the moment it lands and follows it in any
/// direction, and a tap sets the value too. (A pan lost vertical moves to an
/// ancestor's vertical drag, the launcher's edge swipes, which wins after a
/// shorter slop.)
///
/// [active] means the value is automatic: the arc is Volt. A manual level is
/// bone. See docs/DESIGN_SYSTEM.md §6.
class HaloDial extends StatefulWidget {
  const HaloDial({
    super.key,
    required this.caption,
    required this.value,
    required this.footer,
    required this.onChanged,
    this.active = false,
    this.onFooterTap,
  });

  /// Mono caption under the value (`Light`, `Sound`).
  final String caption;

  /// 0 to 1.
  final double value;
  final String footer;
  final bool active;
  final ValueChanged<double>? onChanged;

  /// Makes the footer a button (Light's `Auto · on`). The tap area reaches
  /// 28 px up from the plate's bottom padding; the text stays where it is.
  final VoidCallback? onFooterTap;

  static const double dialSize = 132;

  /// Touches this close to the center are ignored: the angle there is noise.
  static const double deadZone = 16;

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
  State<HaloDial> createState() => _HaloDialState();
}

class _HaloDialState extends State<HaloDial> {
  // The ring, to turn a finger's global position into a local one.
  final _ringKey = GlobalKey(debugLabel: 'HaloDial ring');

  // The last value each finger set, so crossing 12 o'clock never jumps
  // between the ends.
  final _fingers = <int, double>{};

  void _touch(int pointer, Offset global) {
    final box = _ringKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(global);
    const center = Offset(HaloDial.dialSize / 2, HaloDial.dialSize / 2);
    if ((local - center).distance < HaloDial.deadZone) return;
    final previous = _fingers[pointer] ?? widget.value.clamp(0.0, 1.0);
    final v = HaloDial.valueAt(local, previous);
    _fingers[pointer] = v;
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final v = widget.value.clamp(0.0, 1.0);
    final percent = (v * 100).round();
    final halo = context.halo;
    final ring = SizedBox(
      key: _ringKey,
      width: HaloDial.dialSize,
      height: HaloDial.dialSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(HaloDial.dialSize),
            painter: _DialPainter(
              v,
              widget.active ? halo.dialAuto : halo.dialManual,
              halo.ticks,
              halo.track,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent',
                style: HaloType.dialValue.copyWith(color: halo.text),
              ),
              const SizedBox(height: 2),
              Text(
                HaloType.upper(widget.caption),
                style: HaloType.dialCaption.copyWith(color: halo.muted),
              ),
            ],
          ),
        ],
      ),
    );
    final footer = Text(
      HaloType.upper(widget.footer),
      style: HaloType.footer.copyWith(color: halo.muted),
    );
    return Semantics(
      slider: true,
      label: widget.caption,
      value: '$percent%',
      increasedValue: '${(percent + 5).clamp(0, 100)}%',
      decreasedValue: '${(percent - 5).clamp(0, 100)}%',
      enabled: onChanged != null,
      onIncrease: onChanged == null
          ? null
          : () => onChanged((v + 0.05).clamp(0.0, 1.0)),
      onDecrease: onChanged == null
          ? null
          : () => onChanged((v - 0.05).clamp(0.0, 1.0)),
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
              if (onChanged == null)
                ring
              else
                // The eager recognizer claims a finger the moment it lands, so
                // an ancestor's drag can't take it; the listener follows it.
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _touch(e.pointer, e.position),
                  onPointerMove: (e) => _touch(e.pointer, e.position),
                  onPointerUp: (e) => _fingers.remove(e.pointer),
                  onPointerCancel: (e) => _fingers.remove(e.pointer),
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      EagerGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            EagerGestureRecognizer
                          >(EagerGestureRecognizer.new, (_) {}),
                    },
                    child: ring,
                  ),
                ),
              if (widget.onFooterTap == null)
                footer
              else
                Semantics(
                  button: true,
                  label: widget.footer,
                  onTap: widget.onFooterTap,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onFooterTap,
                      child: SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: footer,
                        ),
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
