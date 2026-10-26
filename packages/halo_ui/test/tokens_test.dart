import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

void main() {
  test('volt and flare match the design system', () {
    expect(HaloColors.volt, const Color(0xFFD6FF3F));
    expect(HaloColors.flare, const Color(0xFFFF5B2E));
  });

  test('voltLine is volt at 55% alpha', () {
    expect(HaloColors.voltLine.a, closeTo(0.55, 0.01));
    expect(HaloColors.voltLine.withValues(alpha: 1), HaloColors.volt);
  });

  test('hairline steps are white at the documented alpha', () {
    final steps = {
      HaloColors.line05: 0.05,
      HaloColors.line07: 0.07,
      HaloColors.line08: 0.08,
      HaloColors.line10: 0.10,
      HaloColors.line12: 0.12,
      HaloColors.line14: 0.14,
      HaloColors.line16: 0.16,
      HaloColors.line18: 0.18,
      HaloColors.line22: 0.22,
      HaloColors.line35: 0.35,
    };
    steps.forEach((color, alpha) {
      expect(color.withValues(alpha: 1), const Color(0xFFFFFFFF));
      expect(color.a, closeTo(alpha, 0.005));
    });
  });

  test('notch radii have one big top-left corner and three small', () {
    for (final r in [
      HaloRadii.notchXS,
      HaloRadii.notchS,
      HaloRadii.notchM,
      HaloRadii.notchML,
      HaloRadii.notchL,
      HaloRadii.notchXL,
      HaloRadii.notchXXL,
    ]) {
      expect(r.topLeft.x, greaterThan(r.topRight.x));
      expect(r.topRight, r.bottomRight);
      expect(r.topRight, r.bottomLeft);
    }
    expect(HaloRadii.notchXL.topLeft, const Radius.circular(28));
  });

  test('NotchBorder uses the given radius and outline', () {
    const border = NotchBorder(
      radius: HaloRadii.notchXL,
      side: BorderSide(color: HaloColors.line08),
    );
    expect(border.borderRadius, HaloRadii.notchXL);
    expect(border.side.color, HaloColors.line08);
  });
}
