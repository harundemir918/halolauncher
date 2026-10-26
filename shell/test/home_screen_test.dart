import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_shell/home/home_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

Widget app(HomeScreen home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: HaloTheme.dark(),
  home: Scaffold(body: home),
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

  Future<void> pumpHome(WidgetTester tester, {ValueChanged<String>? onLaunch}) {
    useReferenceFrame(tester);
    return tester.pumpWidget(
      app(HomeScreen(backend: MockBackend(), onLaunch: onLaunch ?? (_) {})),
    );
  }

  testWidgets('shows the design copy', (tester) async {
    await pumpHome(tester);
    expect(find.textContaining('09:41', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('FRI 23.10', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('Design review\nin 19 min'), findsOneWidget);
    expect(find.text('ROOM 3 · 2 MIN WALK · 4 PEOPLE'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Open notes'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Lunch with Elif'), findsOneWidget);
    expect(find.text('KARAKÖY'), findsOneWidget);
    expect(find.text('UNCONFIRMED'), findsOneWidget);
    expect(find.text('ELIF · 2M'), findsOneWidget);
    expect(find.text('Still on for 7?'), findsOneWidget);
    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('Ask Halo'), findsOneWidget);
  });

  testWidgets('only the next event is marked current (Volt time)', (
    tester,
  ) async {
    await pumpHome(tester);
    Color? colorOf(String t) => tester.widget<Text>(find.text(t)).style?.color;
    expect(colorOf('10:00'), HaloColors.volt);
    expect(colorOf('13:30'), HaloColors.ash);
    expect(colorOf('19:00'), HaloColors.ash);
  });

  testWidgets('apps sit on the arc at the design coordinates', (tester) async {
    await pumpHome(tester);
    const expected = {
      'notes': Offset(30, 805),
      'maps': Offset(73, 754),
      'music': Offset(130, 721),
      'messages': Offset(195, 710),
      'camera': Offset(260, 721),
      'web': Offset(317, 754),
      'phone': Offset(360, 805),
    };
    expected.forEach((id, p) {
      final c = tester.getCenter(find.byKey(ValueKey('arc-$id')));
      expect(c.dx, closeTo(p.dx, 1.5), reason: id);
      expect(c.dy, closeTo(p.dy, 1.5), reason: id);
    });
  });

  testWidgets('focused app is 68 and Volt, the rest 52', (tester) async {
    await pumpHome(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('arc-messages'))),
      const Size(68, 68),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('arc-music'))),
      const Size(52, 52),
    );
    Color? fill(String id) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey('arc-$id')),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).color;
    }

    expect(fill('messages'), HaloColors.volt);
    expect(fill('music'), HaloColors.surface);
  });

  testWidgets('Messages shows the Flare unread badge', (tester) async {
    await pumpHome(tester);
    final badges = find.descendant(
      of: find.byKey(const ValueKey('arc-messages')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == HaloColors.flare,
      ),
    );
    expect(badges, findsOneWidget);
  });

  testWidgets('tapping a neighbor focuses it and updates the label', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('arc-music')));
    await tester.pumpAndSettle();
    expect(find.text('MUSIC'), findsOneWidget);
    expect(find.text('MESSAGES'), findsNothing);
    final c = tester.getCenter(find.byKey(const ValueKey('arc-music')));
    expect(c.dx, closeTo(195, 1.5));
    expect(c.dy, closeTo(710, 1.5));
  });

  testWidgets('tapping the focused app launches it', (tester) async {
    String? launched;
    await pumpHome(tester, onLaunch: (id) => launched = id);
    await tester.tap(find.byKey(const ValueKey('arc-messages')));
    expect(launched, 'messages');
  });

  testWidgets('dragging along the arc rotates focus', (tester) async {
    await pumpHome(tester);
    // Start on an app: dragging from an icon must still rotate the arc.
    await tester.dragFrom(const Offset(195, 710), const Offset(-70, 0));
    await tester.pumpAndSettle();
    expect(find.text('CAMERA'), findsOneWidget);
  });

  testWidgets('without a next event Home says so and hides the actions', (
    tester,
  ) async {
    useReferenceFrame(tester);
    await tester.pumpWidget(
      app(
        HomeScreen(
          backend: MockBackend(now: DateTime(2026, 10, 23, 23)),
          onLaunch: (_) {},
        ),
      ),
    );
    expect(find.text('Clear for\nthe day'), findsOneWidget);
    expect(find.text('Navigate'), findsNothing);
  });

  testWidgets('matches the golden', (tester) async {
    await pumpHome(tester);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
  }, tags: 'golden');
}
