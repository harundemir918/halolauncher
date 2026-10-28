import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../notch_border.dart';
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
///
/// With [onAddStart] or [onAddEnd] the arc has a plus slot before the first
/// app or after the last: one more place to rotate to, drawn in the notch
/// shape since circles are for apps only. [focusedIndex] and [onFocus] then
/// range from -1 (the start slot) to the app count (the end slot). With no
/// apps there is only the end slot.
class HaloArc extends StatefulWidget {
  const HaloArc({
    super.key,
    required this.apps,
    required this.focusedIndex,
    required this.onFocus,
    required this.onLaunch,
    this.onLongPress,
    this.onAddStart,
    this.onAddEnd,
  });

  final List<HaloArcApp> apps;
  final int focusedIndex;
  final ValueChanged<int> onFocus;
  final ValueChanged<HaloArcApp> onLaunch;

  /// A long press on any app on the arc (its menu).
  final ValueChanged<HaloArcApp>? onLongPress;

  /// Tapping the focused plus slot at the start or the end of the arc.
  final VoidCallback? onAddStart;
  final VoidCallback? onAddEnd;

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

  bool get _hasStart => widget.onAddStart != null && widget.apps.isNotEmpty;
  bool get _hasEnd => widget.onAddEnd != null;

  /// The range the arc rotates over: the apps, and the plus slots around them.
  double get _first => _hasStart ? -1 : 0;
  double get _last =>
      math.max(_first, (widget.apps.length - 1 + (_hasEnd ? 1 : 0)).toDouble());

  double _clamp(double v) => v.clamp(_first, _last);

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
                if (apps.isNotEmpty || _hasEnd)
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
                            HaloType.upper(
                              nearest < 0
                                  ? 'Add to start'
                                  : nearest >= apps.length
                                  ? 'Add to end'
                                  : apps[nearest].label,
                            ),
                            style: HaloType.kicker.copyWith(color: halo.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (var i = _first.toInt(); i <= _last.toInt(); i++)
                  if ((i - _pos.value).abs() <= 3.5)
                    i >= 0 && i < apps.length
                        ? _app(i, c, halo)
                        : _add(i, c, halo),
              ],
            );
            // Drag anywhere in the lower part, including on an app, to rotate.
            // The detector covers only that part, so a sideways drag higher up
            // reaches whatever is behind the arc (Home's glance swipe).
            return Stack(
              children: [
                stack,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: HaloArc.dragZone,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) => _pos.value = _clamp(
                      _pos.value - d.delta.dx / HaloArc._pxPerStep,
                    ),
                    onHorizontalDragEnd: _dragEnd,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The plus slot before the first app ([i] below 0) or after the last.
  Widget _add(int i, Offset c, HaloPalette halo) {
    final start = i < 0;
    final off = i - _pos.value;
    final t = off.abs().clamp(0.0, 1.0);
    final theta = off * HaloArc.stepDegrees * math.pi / 180;
    final center =
        c + Offset(math.sin(theta), -math.cos(theta)) * HaloArc.radius;
    final size = lerpDouble(HaloArc.focusedSize, HaloArc.size, t);
    final focused = off.abs() < 0.5;
    final onAdd = start ? widget.onAddStart : widget.onAddEnd;
    void tap() => focused ? onAdd?.call() : widget.onFocus(i);

    return Positioned(
      key: ValueKey(start ? 'arc-add-start' : 'arc-add-end'),
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: start ? 'Add an app to the start' : 'Add an app to the end',
        onTap: tap,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tap,
            child: Container(
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: halo.surface,
                shape: NotchBorder(
                  radius: HaloRadii.notchML,
                  side: BorderSide(
                    color: Color.lerp(halo.signalLine, halo.appBorder, t)!,
                    width: lerpDouble(2, 1, t),
                  ),
                ),
              ),
              child: HaloIcon(
                HaloIcons.plus,
                size: lerpDouble(28, 22, t),
                strokeWidth: lerpDouble(2, 1.8, t),
                color: Color.lerp(halo.signalLine, halo.text, t)!,
              ),
            ),
          ),
        ),
      ),
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
