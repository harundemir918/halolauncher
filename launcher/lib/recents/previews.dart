import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../app_icons.dart';

/// What a focused slat shows for an app. Android gives a launcher no way to
/// read another app's last frame, so a real app shows its icon on a wash of
/// the icon's own color; the mock's Maps has a drawn surface.
Widget previewFor(HaloAppInfo app) {
  if (app.id == 'maps' && app.icon == null) return const MapsPreview();
  if (app.icon != null) return IconPreview(app: app);
  return _NoPreview(label: app.label);
}

/// Header shared by app previews: a Volt square and the app name.
class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 8,
        height: 8,
        child: ColoredBox(color: context.halo.signalLine),
      ),
      const SizedBox(width: 8),
      Text(
        HaloType.upper(label),
        style: HaloType.slatLabel.copyWith(color: context.halo.text),
      ),
    ],
  );
}

/// The app's icon, large, on its own color: opaque, one flat wash (no glass).
class IconPreview extends StatelessWidget {
  const IconPreview({super.key, required this.app});

  final HaloAppInfo app;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final accent = app.accent;
    final wash = accent == null
        ? halo.well
        : Color.alphaBlend(Color(accent).withValues(alpha: 0.22), halo.well);
    return ColoredBox(
      color: wash,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(app.label),
            const Spacer(),
            Center(
              child: Image(
                image: imageFor(app)!,
                width: 72,
                height: 72,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const Spacer(),
            Text(
              HaloType.upper('Tap to open'),
              style: HaloType.kicker.copyWith(color: halo.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(label),
        const Spacer(),
        Text(
          HaloType.upper('No preview yet'),
          style: HaloType.kicker.copyWith(color: context.halo.muted),
        ),
      ],
    ),
  );
}

/// Mock of the Maps app's surface: a route over a faint street map and a
/// trip card. Coordinates are from design/source/Switcher.dc.html (190 × 620).
class MapsPreview extends StatelessWidget {
  const MapsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapPainter(halo))),
        const Positioned(top: 14, left: 14, right: 14, child: _Header('Maps')),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              // The trip card is ground in dark and surface in light.
              color: halo.isLight ? halo.surface : halo.ground,
              shape: NotchBorder(
                radius: HaloRadii.notchAvatar,
                side: BorderSide(color: halo.soft),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  HaloType.upper('Karaköy'),
                  style: HaloType.footer.copyWith(color: halo.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '12 min',
                  style: HaloType.dialValue.copyWith(color: halo.text),
                ),
                const SizedBox(height: 4),
                Text(
                  '3.4 km via Galata',
                  style: HaloType.note.copyWith(color: halo.muted),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: halo.signalFill,
                    shape: NotchBorder(
                      radius: HaloRadii.notchS,
                      side: halo.fillSide,
                    ),
                  ),
                  child: Text(
                    'Start',
                    style: HaloType.button.copyWith(
                      color: halo.onSignal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.halo);

  final HaloPalette halo;

  @override
  void paint(Canvas canvas, Size size) {
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    final rings = stroke(halo.mapRings, 1);
    for (final (rx, ry) in const [
      (40.0, 30.0),
      (72.0, 54.0),
      (104.0, 80.0),
      (136.0, 106.0),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(150, 120),
          width: rx * 2,
          height: ry * 2,
        ),
        rings,
      );
    }

    final major = stroke(halo.mapMajor, 5);
    for (final (a, b) in const [
      (Offset(-10, 330), Offset(200, 310)),
      (Offset(60, 80), Offset(74, 640)),
      (Offset(-10, 480), Offset(200, 470)),
    ]) {
      canvas.drawLine(a, b, major);
    }
    final minor = stroke(halo.mapMinor, 2);
    for (final (a, b) in const [
      (Offset(-10, 220), Offset(200, 214)),
      (Offset(130, 60), Offset(140, 640)),
      (Offset(-10, 400), Offset(200, 392)),
    ]) {
      canvas.drawLine(a, b, minor);
    }

    final route = Path()
      ..moveTo(30, 470)
      ..lineTo(34, 400)
      ..lineTo(92, 392)
      ..lineTo(96, 300)
      ..lineTo(150, 288)
      ..lineTo(152, 190);
    canvas.drawPath(route, stroke(halo.signalLine, halo.routeStroke));
    canvas.drawCircle(const Offset(30, 470), 6, Paint()..color = halo.text);
    canvas.drawCircle(const Offset(152, 190), 9, Paint()..color = halo.flare);
    canvas.drawCircle(const Offset(152, 190), 3, Paint()..color = halo.ground);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.halo != halo;
}
