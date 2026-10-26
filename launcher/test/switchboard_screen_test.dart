import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/switchboard/switchboard_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

Widget app(HaloBackend backend) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: HaloTheme.dark(),
  home: Scaffold(body: SwitchboardScreen(backend: backend)),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  late MockBackend backend;

  Future<void> pumpBoard(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    backend = MockBackend();
    return tester.pumpWidget(app(backend));
  }

  testWidgets('shows the design copy', (tester) async {
    await pumpBoard(tester);
    expect(find.text('Switchboard'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('LIGHT'), findsOneWidget);
    expect(find.text('AUTO · ON'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('MEDIA · RING'), findsOneWidget);
    for (final t in ['Wi-Fi', 'Bluetooth', 'Cellular', 'Airplane', 'Focus']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('HOME-5G'), findsOneWidget);
    expect(find.text('2 DEVICES'), findsOneWidget);
    expect(find.text('WORK · UNTIL 11:00'), findsOneWidget);
    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('MIRA OKAFOR'), findsOneWidget);
    expect(find.text('BATTERY 82%'), findsOneWidget);
    expect(find.text('FULL BY 10:20'), findsOneWidget);
  });

  testWidgets('light dial is Volt (auto), sound dial is bone (manual)', (
    tester,
  ) async {
    await pumpBoard(tester);
    final dials = tester.widgetList<HaloDial>(find.byType(HaloDial)).toList();
    expect(dials.map((d) => d.active), [true, false]);
  });

  testWidgets('dragging the light dial sets a manual level', (tester) async {
    await pumpBoard(tester);
    // Dial center is at (105.5, 196); start at 12 o'clock, end at 3 o'clock.
    final g = await tester.startGesture(const Offset(105.5, 150));
    await g.moveTo(const Offset(150, 196));
    await g.up();
    await tester.pump();
    expect(backend.quick.brightness, closeTo(0.25, 0.05));
    expect(backend.quick.brightnessAuto, isFalse);
    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('AUTO · ON'), findsNothing);
  });

  testWidgets('dial value never jumps across the top', (tester) async {
    expect(HaloDial.valueAt(const Offset(60, 10), 0.9), closeTo(0.98, 0.03));
    expect(HaloDial.valueAt(const Offset(72, 10), 0.9), 1.0);
    expect(HaloDial.valueAt(const Offset(60, 10), 0.1), 0.0);
    expect(HaloDial.valueAt(const Offset(72, 10), 0.1), closeTo(0.017, 0.005));
    expect(HaloDial.valueAt(const Offset(122, 66), 0.2), closeTo(0.25, 0.01));
  });

  testWidgets('tapping a toggle row switches it', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.text('Bluetooth'));
    await tester.pump();
    final bt = backend.quick.toggles.firstWhere((t) => t.id == 'bluetooth');
    expect(bt.on, isFalse);
  });

  testWidgets('airplane mode turns the radios off on screen', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.text('Airplane'));
    await tester.pump();
    final rows = tester.widgetList<HaloToggleRow>(find.byType(HaloToggleRow));
    expect(rows.map((r) => r.value), [false, false, false, true, true]);
    expect(find.text('ON'), findsOneWidget);
  });

  testWidgets('play/pause button toggles playback', (tester) async {
    await pumpBoard(tester);
    expect(backend.quick.media!.playing, isTrue);
    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(backend.quick.media!.playing, isFalse);
  });

  testWidgets('layout follows the design y positions', (tester) async {
    await pumpBoard(tester);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(find.byType(HaloDial).first), closeTo(116, 1));
    expect(top(find.byType(HaloToggleRow).first), closeTo(336, 1));
    expect(top(find.byType(HaloMediaStrip)), closeTo(644, 1));
    expect(top(find.byType(HaloBatteryCells)), closeTo(730 + 13 + 10, 4));
  });

  testWidgets('matches the golden', (tester) async {
    await pumpBoard(tester);
    await expectLater(
      find.byType(SwitchboardScreen),
      matchesGoldenFile('goldens/switchboard.png'),
    );
  }, tags: 'golden');
}
