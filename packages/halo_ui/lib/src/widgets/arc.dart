import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';
import 'icons.dart';

/// One app on the arc.
class HaloArcApp {
  const HaloArcApp({
    required this.id,
    required this.label,
    required this.icon,
    this.image,
    this.monoImage,
    this.unread = false,
  });

  final String id;
  final String label;

  /// The Halo glyph, drawn when there is no [image].
  final HaloIcons icon;

  /// The app's own icon. Drawn masked to a circle, with a Volt ring when
  /// focused (docs/DECISIONS.md D-025).
  final ImageProvider? image;

  /// The app's monochrome icon (an alpha mask). With it the app is drawn like
  /// the design's glyphs: bone, or Volt fill with the icon in the on-signal
  /// color when focused. It wins over [image].
  final ImageProvider? monoImage;
  final bool unread;
}

/// Apps on an arc at the bottom of Home, in thumb reach. Never a grid.
///
/// The arc is a circle of radius 190 whose center sits 56 px below the bottom
/// of this widget (195, 900 on the 390 × 844 frame). The focused app sits at the
/// top of the circle, 68 px and Volt; its neighbors are 52 px, 20 degrees
/// apart. Dragging sideways rotates the arc; tapping an app focuses it, and
/// tapping the focused one launches it. With more than 7 apps the ones past
/// three steps away are off the arc (see the open question in ROADMAP). The
/// list may grow or shrink while shown (apps installed or removed).
class HaloArc extends StatefulWidget {
  const HaloArc({
    super.key,
    required this.apps,
    required this.focusedIndex,
    required this.onFocus,
    required this.onLaunch,
    this.onLongPress,
  });

  final List<HaloArcApp> apps;
  final int focusedIndex;
  final ValueChanged<int> onFocus;
  final ValueChanged<HaloArcApp> onLaunch;

  /// A long press on any app on the arc (its menu).
  final ValueChanged<HaloArcApp>? onLongPress;

  static const double radius = 190;
  static const double stepDegrees = 20;
  static const double centerBelow = 56;
  static const double focusedSize = 68;
  static const double size = 52;

  /// Height of the bottom zone where a sideways drag rotates the arc.
  static const double dragZone = 260;

  /// Arc length between neighbors, used to turn a drag into a rotation.
  static const double _pxPerStep = radius * stepDegrees * math.pi / 180;

  @override
  State<HaloArc> createState() => _HaloArcState();
}

class _HaloArcState extends State<HaloArc> with SingleTickerProviderStateMixin {
  // Unbounded so the range can follow the app list; [_clamp] keeps it on it.
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.focusedIndex.toDouble(),
  );

  double get _last => math.max(0, widget.apps.length - 1).toDouble();

  double _clamp(double v) => v.clamp(0.0, _last);

  @override
  void didUpdateWidget(HaloArc old) {
    super.didUpdateWidget(old);
    if (_pos.value != _clamp(_pos.value)) _pos.value = _clamp(_pos.value);
    if (old.focusedIndex != widget.focusedIndex) {
      _pos.animateTo(
        widget.focusedIndex.toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  bool _dragging = false;

  void _dragEnd(DragEndDetails d) {
    // Flick a little further with velocity, then snap to a whole app.
    final target = _clamp(_pos.value - d.primaryVelocity! / 4000).round();
    if (target == widget.focusedIndex) {
      _pos.animateTo(
        target.toDouble(),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFocus(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return LayoutBuilder(
      builder: (context, box) {
        final c = Offset(box.maxWidth / 2, box.maxHeight + HaloArc.centerBelow);
        return AnimatedBuilder(
          animation: _pos,
          builder: (context, _) {
            final apps = widget.apps;
            final nearest = _clamp(_pos.value).round();
            final stack = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _ArcPainter(c, halo)),
                  ),
                ),
                if (apps.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: c.dy - HaloArc.radius - HaloArc.focusedSize / 2 - 30,
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: halo.signalLine,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            HaloType.upper(apps[nearest].label),
                            style: HaloType.kicker.copyWith(color: halo.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < apps.length; i++)
                  if ((i - _pos.value).abs() <= 3.5) _app(i, c, halo),
              ],
            );
            // Drag anywhere in the lower part, including on an app, to rotate.
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (d) => _dragging =
                  d.localPosition.dy > box.maxHeight - HaloArc.dragZone,
              onHorizontalDragUpdate: (d) {
                if (_dragging) {
                  _pos.value = _clamp(
                    _pos.value - d.delta.dx / HaloArc._pxPerStep,
                  );
                }
              },
              onHorizontalDragEnd: (d) {
                if (_dragging) _dragEnd(d);
                _dragging = false;
              },
              child: stack,
            );
          },
        );
      },
    );
  }

  Widget _app(int i, Offset c, HaloPalette halo) {
    final app = widget.apps[i];
    final off = i - _pos.value;
    final t = off.abs().clamp(0.0, 1.0);
    final theta = off * HaloArc.stepDegrees * math.pi / 180;
    final center =
        c + Offset(math.sin(theta), -math.cos(theta)) * HaloArc.radius;
    final size = lerpDouble(HaloArc.focusedSize, HaloArc.size, t);
    final focused = off.abs() < 0.5;

    return Positioned(
      key: ValueKey('arc-${app.id}'),
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: app.unread ? '${app.label}, unread' : app.label,
        onTap: () => focused ? widget.onLaunch(app) : widget.onFocus(i),
        onLongPress: widget.onLongPress == null
            ? null
            : () => widget.onLongPress!(app),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => focused ? widget.onLaunch(app) : widget.onFocus(i),
            onLongPress: widget.onLongPress == null
                ? null
                : () => widget.onLongPress!(app),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (app.monoImage case final mono?)
                  _ThemedIcon(mono: mono, t: t, halo: halo)
                else if (app.image case final image?)
                  Container(
                    padding: EdgeInsets.all(lerpDouble(4, 0, t)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: halo.surface,
                      border: Border.all(
                        color: Color.lerp(halo.signalLine, halo.appBorder, t)!,
                        width: lerpDouble(2.5, 1, t),
                      ),
                    ),
                    child: ClipOval(
                      child: Image(
                        image: image,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ),
                  )
                else
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(halo.signalFill, halo.surface, t),
                      border: Border.all(
                        color: Color.lerp(
                          halo.fillEdge ?? halo.appBorder.withValues(alpha: 0),
                          halo.appBorder,
                          t,
                        )!,
                      ),
                    ),
                    child: HaloIcon(
                      app.icon,
                      size: lerpDouble(30, 22, t),
                      strokeWidth: lerpDouble(2, 1.8, t),
                      color: Color.lerp(halo.onSignal, halo.text, t)!,
                    ),
                  ),
                if (app.unread && t < 0.5)
                  Positioned(
                    right: -1,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: halo.flare,
                        shape: BoxShape.circle,
                        border: Border.all(color: halo.ground, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An app drawn from its monochrome icon, like the design's glyphs: bone on
/// `surface`, and focused (t = 0) the Volt circle with the icon in the
/// on-signal color. The mask is padded to a glyph's share of the circle.
class _ThemedIcon extends StatelessWidget {
  const _ThemedIcon({required this.mono, required this.t, required this.halo});

  final ImageProvider mono;
  final double t;
  final HaloPalette halo;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Container(
      padding: EdgeInsets.all(box.maxWidth * 0.14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(halo.signalFill, halo.surface, t),
        border: Border.all(
          color: Color.lerp(
            halo.fillEdge ?? halo.appBorder.withValues(alpha: 0),
            halo.appBorder,
            t,
          )!,
        ),
      ),
      child: Image(
        key: const ValueKey('mono'),
        image: mono,
        fit: BoxFit.contain,
        color: Color.lerp(halo.onSignal, halo.text, t),
        colorBlendMode: BlendMode.srcIn,
        // Not medium: its mipmaps drew faint lines around some masks on
        // Android. The mask is only slightly larger than drawn.
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    ),
  );
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.c, this.halo);

  final Offset c;
  final HaloPalette halo;

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = halo.ringsHome;
    for (final r in const [250.0, 310.0, 370.0, 430.0]) {
      canvas.drawCircle(c, r, faint);
    }
    canvas.drawCircle(
      c,
      HaloArc.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = halo.guide,
    );
    // The Volt segment under the focused app: 12 degrees either side of the top.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: HaloArc.radius),
      -math.pi / 2 - 12 * math.pi / 180,
      24 * math.pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = halo.signalLine,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.c != c || old.halo != halo;
}
