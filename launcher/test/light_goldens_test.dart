import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/lock/lock_screen.dart';
import 'package:halo_launcher/recents/recents_screen.dart';
import 'package:halo_launcher/stream/stream_screen.dart';
import 'package:halo_launcher/switchboard/switchboard_screen.dart';
import 'package:halo_launcher/system/system_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

/// Light appearance (D-013), one golden per screen, compared by eye with
/// design/screens/*_light.png.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  final screens = <String, Widget Function(MockBackend)>{
    'lock': (b) => LockScreen(backend: b, onUnlock: () {}),
    'home': (b) => HomeScreen(backend: b, onLaunch: (_) {}),
    'switchboard': (b) => SwitchboardScreen(backend: b),
    'recents': (b) => RecentsScreen(backend: b),
    'stream': (b) => StreamScreen(backend: b),
    'system': (b) => SystemScreen(backend: b, initiallyOpen: 'display'),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    testWidgets('$name matches the light golden', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final backend = MockBackend()..setAppearance(Appearance.light);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HaloTheme.light(),
          home: Scaffold(body: build(backend)),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/${name}_light.png'),
      );
    }, tags: 'golden');
  }
}
