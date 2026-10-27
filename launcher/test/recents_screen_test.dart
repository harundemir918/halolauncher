import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/recents/previews.dart';
import 'package:halo_launcher/recents/recents_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

Widget app(HaloBackend backend, {ValueChanged<String>? onLaunch}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: HaloTheme.dark(),
      home: Scaffold(
        body: RecentsScreen(backend: backend, onLaunch: onLaunch),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  late MockBackend backend;

  Future<void> pumpRecents(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    backend = MockBackend();
    return tester.pumpWidget(app(backend));
  }

  Finder slat(String id) => find.byKey(ValueKey('slat-$id'));

  testWidgets('shows the design copy', (tester) async {
    await pumpRecents(tester);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('CLEAR ALL'), findsOneWidget);
    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('MUSIC'), findsOneWidget);
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('WEB'), findsOneWidget);
    expect(find.text('MAPS'), findsOneWidget);
    expect(find.text('KARAKÖY'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('3.4 km via Galata'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('FLICK A SLAT UP TO CLOSE'), findsOneWidget);
  });

  testWidgets('slat geometry follows the design', (tester) async {
    await pumpRecents(tester);
    // Row at top 120, left 16, height 620: 36 + 6 + 36 + 6 + 190 + 6 + 36 + 6 + 36.
    final expected = {
      'messages': const Rect.fromLTWH(16, 120, 36, 620),
      'music': const Rect.fromLTWH(58, 120, 36, 620),
      'maps': const Rect.fromLTWH(100, 120, 190, 620),
      'notes': const Rect.fromLTWH(296, 120, 36, 620),
      'web': const Rect.fromLTWH(338, 120, 36, 620),
    };
    expected.forEach((id, r) {
      final got = tester.getRect(slat(id));
      expect(got.left, closeTo(r.left, 0.5), reason: id);
      expect(got.top, closeTo(r.top, 0.5), reason: id);
      expect(got.width, closeTo(r.width, 0.5), reason: id);
      expect(got.height, closeTo(r.height, 0.5), reason: id);
    });
  });

  testWidgets('the focused slat has the Volt-line border and the well ground', (
    tester,
  ) async {
    await pumpRecents(tester);
    ShapeDecoration deco(String id) =>
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: slat(id),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as ShapeDecoration;
    final focused = deco('maps');
    expect(focused.color, HaloColors.well);
    expect((focused.shape as NotchBorder).side.color, HaloColors.voltLine);
    final collapsed = deco('music');
    expect(collapsed.color, HaloColors.surface);
    expect((collapsed.shape as NotchBorder).side.color, HaloColors.line08);
  });

  testWidgets('tapping a collapsed slat focuses it', (tester) async {
    await pumpRecents(tester);
    await tester.tap(slat('notes'));
    await tester.pumpAndSettle();
    expect(tester.getSize(slat('notes')).width, closeTo(190, 0.5));
    expect(tester.getSize(slat('maps')).width, closeTo(36, 0.5));
    expect(find.text('NO PREVIEW YET'), findsOneWidget);
    expect(find.text('KARAKÖY'), findsNothing);
  });

  testWidgets('flicking a slat up closes it', (tester) async {
    await pumpRecents(tester);
    await tester.fling(slat('music'), const Offset(0, -300), 1200);
    await tester.pumpAndSettle();
    expect(backend.recents.map((a) => a.id), [
      'messages',
      'maps',
      'notes',
      'web',
    ]);
    expect(find.text('04'), findsOneWidget);
    expect(slat('music'), findsNothing);
    // Maps is still the focused one and still wide.
    expect(tester.getSize(slat('maps')).width, greaterThan(150));
  });

  testWidgets('a short drag springs back and closes nothing', (tester) async {
    await pumpRecents(tester);
    await tester.drag(slat('music'), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(backend.recents, hasLength(5));
    expect(tester.getRect(slat('music')).top, closeTo(120, 0.5));
  });

  testWidgets('dragging down does nothing', (tester) async {
    await pumpRecents(tester);
    await tester.drag(slat('music'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(backend.recents, hasLength(5));
    expect(tester.getRect(slat('music')).top, closeTo(120, 0.5));
  });

  testWidgets('closing the focused slat focuses its neighbor', (tester) async {
    await pumpRecents(tester);
    await tester.fling(slat('maps'), const Offset(0, -300), 1200);
    await tester.pumpAndSettle();
    expect(backend.recents.map((a) => a.id), [
      'messages',
      'music',
      'notes',
      'web',
    ]);
    // Notes slid into the focused position.
    expect(tester.getSize(slat('notes')).width, greaterThan(150));
  });

  testWidgets('clear all empties Recents', (tester) async {
    await pumpRecents(tester);
    await tester.tap(find.text('CLEAR ALL'));
    await tester.pumpAndSettle();
    expect(backend.recents, isEmpty);
    expect(find.text('00'), findsOneWidget);
    expect(find.text('NO RECENT APPS'), findsOneWidget);
    expect(find.text('CLEAR ALL'), findsNothing);
    expect(find.text('FLICK A SLAT UP TO CLOSE'), findsNothing);
  });

  testWidgets('the hint chevron sits at y 764', (tester) async {
    await pumpRecents(tester);
    // The chevron is the last HaloIcon: the collapsed slats come before it.
    expect(tester.getTopLeft(find.byType(HaloIcon).last).dy, closeTo(764, 1));
  });

  testWidgets('matches the golden', (tester) async {
    await pumpRecents(tester);
    await expectLater(
      find.byType(RecentsScreen),
      matchesGoldenFile('goldens/recents.png'),
    );
  }, tags: 'golden');

  testWidgets('a tap on the focused slat switches to its app', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final launched = <String>[];
    await tester.pumpWidget(app(MockBackend(), onLaunch: launched.add));
    // The middle one (Maps) is focused first.
    await tester.tap(find.text('KARAKÖY'));
    expect(launched, ['maps']);
  });

  testWidgets('without usage access it asks, and says nothing leaves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final b = _NoUsage();
    await tester.pumpWidget(app(b));
    expect(find.text('CLEAR ALL'), findsNothing);
    expect(find.textContaining('NOTHING LEAVES THIS PHONE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('usage-access')));
    expect(b.asked, 1);
  });

  testWidgets('a real app shows its icon on its color, not a mock surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(_RealApps()));
    expect(find.text('TAP TO OPEN'), findsOneWidget);
    expect(find.text('KARAKÖY'), findsNothing);
    final wash = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(IconPreview),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    // The wash is opaque: the accent mixed into the slat's own color.
    expect(wash.color.a, 1);
    expect(wash.color, isNot(HaloColors.well));
  });
}

/// A phone before the user grants usage access.
class _NoUsage extends MockBackend {
  int asked = 0;

  @override
  bool get canReadUsage => false;

  @override
  List<HaloAppInfo> get recents => const [];

  @override
  Future<void> requestUsageAccess() async => asked++;
}

// A 1 x 1 transparent PNG, enough for an icon.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Recents of real apps: an icon and an accent, no design glyph.
class _RealApps extends MockBackend {
  @override
  List<HaloAppInfo> get recents => [
    HaloAppInfo(
      id: 'com.example/.Main',
      label: 'Example',
      icon: _png,
      accent: 0xFF3366CC,
    ),
  ];
}
