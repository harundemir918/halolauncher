import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

void main() {
  test('spacing matches the design system', () {
    expect(HaloSpace.gutter, 24);
    expect(HaloSpace.batteryLine, 3);
    expect(HaloSpace.touchTarget, 44);
    expect(HaloSpace.frameWidth, 390);
    expect(HaloSpace.frameHeight, 844);
  });

  test('dark theme is carbon ground with volt primary', () {
    final t = HaloTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, HaloColors.carbon);
    expect(t.colorScheme.primary, HaloColors.volt);
    expect(t.colorScheme.onPrimary, HaloColors.carbon);
    expect(t.colorScheme.error, HaloColors.flare);
    expect(t.colorScheme.onSurface, HaloColors.bone);
    expect(t.textTheme.headlineLarge?.letterSpacing, lessThan(0));
    expect(t.textTheme.labelMedium?.letterSpacing, greaterThan(0));
  });

  testWidgets('HaloTokens is reachable from context', (tester) async {
    late HaloTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: HaloTheme.dark(),
        home: Builder(
          builder: (context) {
            tokens = HaloTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tokens.ash, HaloColors.ash);
    expect(tokens.flare, HaloColors.flare);
  });

  test('HaloTokens lerp and copyWith', () {
    const a = HaloTokens();
    final b = a.copyWith(ash: const Color(0xFF000000));
    expect(b.ash, const Color(0xFF000000));
    expect(b.flare, a.flare);
    expect(a.lerp(b, 1).ash, b.ash);
    expect(a.lerp(null, 0.5), a);
  });
}
