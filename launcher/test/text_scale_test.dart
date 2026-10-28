import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/main.dart';
import 'package:halo_launcher/text_scale.dart';
import 'package:halo_sdk/halo_sdk.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  group('HaloTextScaler', () {
    test('body text follows the factor, display type stays put', () {
      const s = HaloTextScaler(1.3);
      expect(s.scale(12), closeTo(15.6, 0.001));
      expect(s.scale(20), closeTo(26, 0.001));
      expect(s.scale(36), 36);
      expect(s.scale(196), 196);
    });

    test('in between, the bigger the type the less it grows', () {
      const s = HaloTextScaler(1.3);
      final growth = [
        for (final f in [20.0, 24.0, 28.0, 32.0]) s.scale(f) / f,
      ];
      expect(
        growth,
        orderedEquals([...growth]..sort((a, b) => b.compareTo(a))),
      );
      expect(growth.last, lessThan(growth.first));
      expect(growth.last, greaterThan(1));
    });

    test('is a plain value', () {
      expect(const HaloTextScaler(1.2), const HaloTextScaler(1.2));
      expect(
        const HaloTextScaler(1.2).clamp(maxScaleFactor: 1.1).scale(10),
        11,
      );
    });
  });

  group('the scale a screen gets', () {
    double scaleFor(double textSize, {double system = 1, double max = 1.5}) =>
        effectiveTextScale(
          backend: MockBackend()..setTextSize(textSize),
          system: system,
          max: max,
        );

    test('16 px is as designed', () {
      expect(scaleFor(0.5), closeTo(1, 0.001));
    });

    test('System text size and Android font size multiply', () {
      expect(scaleFor(1, system: 1.1), closeTo(1.25 * 1.1, 0.001));
    });

    test('a screen holds only so much, and nothing is below 0.75', () {
      expect(scaleFor(1, system: 2, max: 1.15), 1.15);
      expect(scaleFor(0, system: 0.5), 0.75);
    });

    test('every screen has a cap, and the fixed ones are lower', () {
      for (final name in [
        'home',
        'lock',
        'switchboard',
        'recents',
        'apps',
        'stream',
        'system',
        'welcome',
      ]) {
        expect(haloTextScaleCaps[name], isNotNull, reason: name);
      }
      expect(
        haloTextScaleCaps['home']!,
        lessThan(haloTextScaleCaps['stream']!),
      );
    });
  });

  testWidgets('the System text size really changes the text', (tester) async {
    final b = MockBackend()..setTextSize(0.5);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HaloLauncher(backend: b, start: 'home'));
    double bodyScale() =>
        MediaQuery.textScalerOf(tester.element(find.byType(HomeScreen)))
            .scale(16);
    expect(bodyScale(), closeTo(16, 0.01));
    b.setTextSize(1);
    await tester.pump();
    // 20 px is 1.25, and Home holds 1.15.
    expect(bodyScale(), closeTo(16 * haloTextScaleCaps['home']!, 0.01));
    b.setTextSize(0);
    await tester.pump();
    expect(bodyScale(), closeTo(12, 0.01));
  });
}
