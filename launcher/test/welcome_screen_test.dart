import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/welcome/welcome_screen.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

/// The first run: not welcomed and not the home app yet. The mock's accesses
/// are a mix of granted and not.
MockBackend firstRun() => MockBackend(welcomed: false)..isDefaultHome = false;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  Future<void> pump(
    WidgetTester tester,
    MockBackend b, {
    VoidCallback? onDone,
    bool light = false,
  }) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? HaloTheme.light() : HaloTheme.dark(),
        home: Scaffold(
          body: WelcomeScreen(backend: b, onDone: onDone ?? () {}),
        ),
      ),
    );
  }

  testWidgets('asks to make Halo the home app, then lists each access', (
    tester,
  ) async {
    final b = firstRun();
    await pump(tester, b);
    expect(find.text('Make Halo\nyour home'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-home')), findsOneWidget);
    for (final g in b.accessGrants) {
      expect(find.byKey(ValueKey('welcome-${g.id}')), findsOneWidget);
    }
  });

  testWidgets('the home row asks, and the headline follows', (tester) async {
    final b = firstRun();
    await pump(tester, b);
    await tester.tap(find.byKey(const ValueKey('welcome-home')));
    await tester.pump();
    expect(b.defaultHomeRequests, 1);
    expect(find.text('Halo is\nyour home'), findsOneWidget);
  });

  testWidgets('an access row opens its grant', (tester) async {
    final b = firstRun();
    await pump(tester, b);
    final id = b.accessGrants.firstWhere((g) => !g.granted).id;
    await tester.tap(find.byKey(ValueKey('welcome-$id')));
    await tester.pump();
    expect(b.accessGrants.firstWhere((g) => g.id == id).granted, isTrue);
  });

  testWidgets('Continue is always there, whatever is granted', (tester) async {
    var done = 0;
    await pump(tester, firstRun(), onDone: () => done++);
    await tester.tap(find.byKey(const ValueKey('welcome-continue')));
    expect(done, 1);
  });

  testWidgets('matches the golden', (tester) async {
    await pump(tester, firstRun());
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/welcome.png'),
    );
  }, tags: 'golden');

  testWidgets('matches the light golden', (tester) async {
    await pump(tester, firstRun(), light: true);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/welcome_light.png'),
    );
  }, tags: 'golden');
}
