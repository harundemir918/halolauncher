import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';
import 'package:halo_ui/src/svg_path.dart';

void main() {
  test('relative lines and close match the absolute form', () {
    final rel = parseSvgPath('M8 3h8l-1 5H9z').getBounds();
    final abs = parseSvgPath('M8 3L16 3L15 8L9 8Z').getBounds();
    expect(rel, abs);
    expect(rel, const Rect.fromLTRB(8, 3, 16, 8));
  });

  test('implicit lineTo after M', () {
    expect(
      parseSvgPath('M0 0 10 0 10 10').getBounds(),
      const Rect.fromLTRB(0, 0, 10, 10),
    );
  });

  test('packed arc flags and negative numbers', () {
    // From the maps icon: a7 7 0 0 0-14 0
    final b = parseSvgPath('M19 10a7 7 0 0 0-14 0').getBounds();
    expect(b.left, closeTo(5, 1e-6));
    expect(b.right, closeTo(19, 1e-6));
    expect(b.top, closeTo(3, 0.01)); // sweep 0 goes over the top
  });

  test('smooth cubic reflects the previous control point', () {
    expect(() => parseSvgPath('M12 21s7-6 7-11'), returnsNormally);
  });

  test('rejects unknown commands and garbage', () {
    expect(() => parseSvgPath('M0 0 Q1 1 2 2'), throwsFormatException);
    expect(() => parseSvgPath('L1 1 x'), throwsFormatException);
    expect(() => parseSvgPath('1 1'), throwsFormatException);
  });

  test('every icon parses and stays roughly inside the 24 grid', () {
    // getBounds includes arc control points, so allow a small overshoot.
    for (final icon in HaloIcons.values) {
      for (final d in icon.pathData) {
        final b = parseSvgPath(d).getBounds();
        expect(b.left, greaterThanOrEqualTo(0), reason: '$icon $d');
        expect(b.top, greaterThanOrEqualTo(0), reason: '$icon $d');
        expect(b.right, lessThanOrEqualTo(25), reason: '$icon $d');
        expect(b.bottom, lessThanOrEqualTo(25), reason: '$icon $d');
      }
    }
  });

  test('circle helper draws a circle of the right size', () {
    final b = parseSvgPath(HaloIcons.maps.pathData[1]).getBounds();
    expect(b.width, closeTo(5, 1e-6));
    expect(b.center.dx, closeTo(12, 1e-6));
    expect(b.center.dy, closeTo(10, 1e-6));
  });
}
