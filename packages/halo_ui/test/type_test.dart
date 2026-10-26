import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final voice = {
    'clockHero': HaloType.clockHero,
    'display': HaloType.display,
    'screenTitle': HaloType.screenTitle,
    'headline': HaloType.headline,
    'dialValue': HaloType.dialValue,
    'sectionTitle': HaloType.sectionTitle,
    'title': HaloType.title,
  };
  final mono = {
    'label': HaloType.label,
    'labelSmall': HaloType.labelSmall,
    'monoValue': HaloType.monoValue,
  };

  test('voice styles use Bricolage with negative tracking', () {
    voice.forEach((name, s) {
      expect(s.fontFamily, contains('Bricolage Grotesque'), reason: name);
      expect(s.letterSpacing, lessThan(0), reason: name);
    });
    // Body copy and button labels carry no tracking.
    expect(HaloType.body.letterSpacing, 0);
    expect(HaloType.button.letterSpacing, 0);
  });

  test('mono styles use DM Mono with positive tracking', () {
    mono.forEach((name, s) {
      expect(s.fontFamily, contains('DM Mono'), reason: name);
      expect(s.letterSpacing, greaterThan(0), reason: name);
    });
  });

  test('tracking is documented em times size', () {
    expect(HaloType.clockHero.letterSpacing, closeTo(-9.8, 1e-9));
    expect(HaloType.display.letterSpacing, closeTo(-4.14, 1e-9));
    expect(HaloType.clockHero.height, 0.8);
  });

  test('line heights come from design/source', () {
    for (final s in [
      HaloType.display,
      HaloType.screenTitle,
      HaloType.headline,
      HaloType.dialValue,
    ]) {
      expect(s.height, 1);
    }
    expect(HaloType.body.height, 1.3);
  });

  test('variable weight axis matches the declared weight', () {
    expect(HaloType.display.fontWeight, FontWeight.w800);
    expect(
      HaloType.display.fontVariations,
      contains(FontVariation.weight(800)),
    );
    expect(
      HaloType.sectionTitle.fontVariations,
      contains(FontVariation.weight(700)),
    );
  });

  test('upper() uppercases labels', () {
    expect(HaloType.upper('Room 3'), 'ROOM 3');
  });

  test('bundled font assets are present', () async {
    for (final f in [
      'BricolageGrotesque-Variable.ttf',
      'DMMono-Regular.ttf',
      'DMMono-Medium.ttf',
    ]) {
      final data = await rootBundle.load('assets/fonts/$f');
      expect(data.lengthInBytes, greaterThan(10000), reason: f);
    }
  });
}
