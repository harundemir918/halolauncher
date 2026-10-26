import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/lock/lock_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

Widget app(LockScreen lock) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: HaloTheme.dark(),
  home: Scaffold(body: lock),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  void useReferenceFrame(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows the design copy from the mock backend', (tester) async {
    useReferenceFrame(tester);
    await tester.pumpWidget(
      app(LockScreen(backend: MockBackend(), onUnlock: () {})),
    );
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('09'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('FRIDAY — 23 OCTOBER'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('NEXT · IN 19 MIN'), findsOneWidget);
    expect(find.text('Design review · Room 3'), findsOneWidget);
    expect(find.text('ELIF'), findsOneWidget);
    expect(find.text('Are we still on for 7?'), findsOneWidget);
    expect(find.text('2M'), findsOneWidget);
    expect(find.text('PARCEL'), findsOneWidget);
    expect(find.text('1H'), findsOneWidget);
    expect(find.text('5G · WI-FI · 82%'), findsOneWidget);
    expect(find.text('HOLD TO OPEN'), findsOneWidget);
  });

  testWidgets('holding the ring for long enough unlocks', (tester) async {
    useReferenceFrame(tester);
    var unlocked = 0;
    await tester.pumpWidget(
      app(LockScreen(backend: MockBackend(), onUnlock: () => unlocked++)),
    );
    final ring = find.byType(HaloHoldRing);
    final gesture = await tester.startGesture(tester.getCenter(ring));
    await tester.pump(const Duration(milliseconds: 300));
    expect(unlocked, 0, reason: 'not yet');
    await tester.pump(const Duration(milliseconds: 800));
    expect(unlocked, 1);
    await gesture.up();
  });

  testWidgets('releasing early does not unlock', (tester) async {
    useReferenceFrame(tester);
    var unlocked = 0;
    await tester.pumpWidget(
      app(LockScreen(backend: MockBackend(), onUnlock: () => unlocked++)),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HaloHoldRing)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(unlocked, 0);
  });

  testWidgets('no event card without a next event', (tester) async {
    useReferenceFrame(tester);
    await tester.pumpWidget(
      app(LockScreen(backend: _NoEvent(), onUnlock: () {})),
    );
    expect(find.byType(HaloEventCard), findsNothing);
  });

  testWidgets('matches the golden', (tester) async {
    useReferenceFrame(tester);
    await tester.pumpWidget(
      app(LockScreen(backend: MockBackend(), onUnlock: () {})),
    );
    await expectLater(
      find.byType(LockScreen),
      matchesGoldenFile('goldens/lock.png'),
    );
  }, tags: 'golden');
}

class _NoEvent extends MockBackend {
  @override
  CalendarEvent? get nextEvent => null;
}
