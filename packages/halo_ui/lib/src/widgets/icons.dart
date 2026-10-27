import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../svg_path.dart';

/// Outline icons on a 24 × 24 grid, round caps and joins. Path data is copied
/// from design/source (Home.dc.html, Main.dc.html). Circles are written as two
/// arcs (`M cx-r cy a r r 0 1 0 2r 0 a r r 0 1 0 -2r 0 z`).
enum HaloIcons {
  flashlight(['M8 3h8l-1 5H9z', 'M9 8l-1 4v9h8v-9l-1-4']),
  camera([
    'M4 8h3l2-3h6l2 3h3v11H4z',
    'M8.5 13a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0z',
  ]),
  notes(['M6 3h9l4 4v14H6z', 'M9 12h7M9 16h5']),
  maps([
    'M12 21s7-6 7-11a7 7 0 0 0-14 0c0 5 7 11 7 11z',
    'M9.5 10a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0z',
  ]),
  music([
    'M9 18V6l10-2v12',
    'M5 18a2 2 0 1 0 4 0a2 2 0 1 0-4 0z',
    'M15 16a2 2 0 1 0 4 0a2 2 0 1 0-4 0z',
  ]),
  messages(['M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z']),
  web([
    'M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0z',
    'M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18',
  ]),
  chevronUp(['M6 15l6-6 6 6']),
  chevronRight(['M9 6l6 6-6 6']),
  phone([
    'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z',
  ]);

  const HaloIcons(this.pathData);

  /// SVG path data on the 24 × 24 grid.
  final List<String> pathData;
}

class HaloIcon extends StatelessWidget {
  const HaloIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.8,
  });

  final HaloIcons icon;
  final double size;

  /// Defaults to the palette's text color.
  final Color? color;

  /// Stroke on the 24-unit grid (1.8 normally, 2 for the focused app).
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(icon, color ?? context.halo.text, strokeWidth),
    ),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.strokeWidth);

  final HaloIcons icon;
  final Color color;
  final double strokeWidth;

  static final Map<HaloIcons, List<Path>> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final paths = _cache.putIfAbsent(
      icon,
      () => [for (final d in icon.pathData) parseSvgPath(d)],
    );
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}
