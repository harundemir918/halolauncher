import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/system/system_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

Widget app(HaloBackend backend, {String? open = 'display'}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: HaloTheme.dark(),
  home: Scaffold(
    body: SystemScreen(backend: backend, initiallyOpen: open),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  late MockBackend backend;

  Future<void> pumpSystem(WidgetTester tester, {String? open = 'display'}) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    backend = MockBackend();
    return tester.pumpWidget(app(backend, open: open));
  }

  testWidgets('shows the design copy', (tester) async {
    await pumpSystem(tester);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('AS'), findsOneWidget);
    expect(find.text('find a setting'), findsOneWidget);
    for (final t in [
      'Connections',
      'Display',
      'Sound',
      'Focus',
      'Privacy',
      'Battery',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final n in ['01', '02', '03', '04', '05', '06']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(find.text('HOME-5G'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('RING 42'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('2 ALERTS'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('DARK'), findsOneWidget);
    expect(find.text('LIGHT'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('TEXT SIZE'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
  });

  testWidgets('the open section is marked in Volt', (tester) async {
    await pumpSystem(tester);
    Color? colorOf(String t) => tester.widget<Text>(find.text(t)).style?.color;
    expect(colorOf('02'), HaloColors.volt);
    expect(colorOf('OPEN'), HaloColors.volt);
    expect(colorOf('01'), HaloColors.ash);
    expect(colorOf('HOME-5G'), HaloColors.ash);
  });

  testWidgets('tapping another section opens it and closes Display', (
    tester,
  ) async {
    await pumpSystem(tester);
    await tester.tap(find.text('Sound'));
    await tester.pump();
    expect(find.text('APPEARANCE'), findsNothing);
    expect(find.text('NOT DESIGNED YET'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    // Display is closed again and shows its appearance as the status.
    expect(find.text('DARK'), findsOneWidget);
  });

  testWidgets('tapping the open section closes it', (tester) async {
    await pumpSystem(tester);
    await tester.tap(find.text('Display'));
    await tester.pump();
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('APPEARANCE'), findsNothing);
  });

  testWidgets('choosing an appearance updates the backend', (tester) async {
    await pumpSystem(tester);
    await tester.tap(find.text('AUTO'));
    await tester.pump();
    expect(backend.system.appearance, Appearance.auto);
  });

  testWidgets('dragging the slider changes the text size label', (
    tester,
  ) async {
    await pumpSystem(tester);
    final slider = find.byType(HaloSlider);
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.left + box.width * 1.0 - 1, box.center.dy));
    await tester.pump();
    expect(backend.system.textSizePx, 20);
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('all sections can be closed', (tester) async {
    await pumpSystem(tester, open: null);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('APPEARANCE'), findsNothing);
  });

  testWidgets('layout follows the design y positions', (tester) async {
    await pumpSystem(tester);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(find.byType(HaloCommandField)), closeTo(118, 1));
    expect(top(find.byType(HaloAccordionRow).first), closeTo(190, 1));
    expect(tester.getSize(find.byType(HaloAvatar)), const Size(44, 44));
  });

  testWidgets('matches the golden', (tester) async {
    await pumpSystem(tester);
    await expectLater(
      find.byType(SystemScreen),
      matchesGoldenFile('goldens/system.png'),
    );
  }, tags: 'golden');
}
