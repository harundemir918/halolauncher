import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/app_menu.dart';
import 'package:halo_launcher/apps/apps_screen.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/main.dart';
import 'package:halo_launcher/recents/recents_screen.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

/// The mock with a phone's worth of apps: the design's seven, a work app,
/// one without a letter, Turkish names and enough filler to scroll.
class ManyApps extends MockBackend {
  final shortcutsStarted = <(String, String)>[];

  @override
  List<HaloAppInfo> get apps => [
    ...super.apps,
    const HaloAppInfo(id: 'slack', label: 'Slack', work: true),
    const HaloAppInfo(id: '9gag', label: '9GAG'),
    const HaloAppInfo(id: 'sikayet', label: 'Şikayetvar'),
    const HaloAppInfo(id: 'ozel', label: 'Özel Not'),
    const HaloAppInfo(id: 'settings', label: 'Settings', canUninstall: false),
    for (var i = 0; i < 30; i++)
      HaloAppInfo(id: 'zz$i', label: 'Zeta ${i.toString().padLeft(2, '0')}'),
  ];

  @override
  Future<bool> startShortcut(String appId, String shortcutId) async {
    shortcutsStarted.add((appId, shortcutId));
    return true;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  Future<void> pumpLauncher(
    WidgetTester tester,
    HaloBackend backend, {
    String start = 'home',
  }) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(HaloLauncher(backend: backend, start: start));
  }

  group('reaching Apps', () {
    testWidgets('an up swipe on the arc opens Apps', (tester) async {
      await pumpLauncher(tester, MockBackend());
      await tester.dragFrom(const Offset(195, 700), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.byType(AppsScreen), findsOneWidget);
    });

    testWidgets('the bottom edge still goes to Recents', (tester) async {
      await pumpLauncher(tester, MockBackend());
      await tester.dragFrom(const Offset(195, 834), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.byType(RecentsScreen), findsOneWidget);
    });

    testWidgets('an up swipe higher on Home does nothing', (tester) async {
      await pumpLauncher(tester, MockBackend());
      await tester.dragFrom(const Offset(195, 400), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('back from Apps returns Home', (tester) async {
      await pumpLauncher(tester, MockBackend(), start: 'apps');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('title, count, A to Z with headings, # last', (tester) async {
      final b = ManyApps();
      await pumpLauncher(tester, b, start: 'apps');
      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('${b.apps.length}'), findsOneWidget);
      final headings = tester
          .widgetList<HaloKicker>(find.byType(HaloKicker))
          .map((k) => k.label)
          .toList();
      expect(headings.first, 'C');
      expect(headings, containsAllInOrder(['C', 'M', 'N', 'O', 'P', 'S']));
      // Turkish names sort and group by their folded letter.
      expect(
        AppsScreen.letterOf(b.apps.firstWhere((a) => a.id == 'ozel')),
        'O',
      );
      expect(
        AppsScreen.letterOf(b.apps.firstWhere((a) => a.id == '9gag')),
        '#',
      );
    });

    testWidgets('arc apps say ON ARC, work apps say WORK', (tester) async {
      await pumpLauncher(tester, ManyApps(), start: 'apps');
      Finder tag(String row, String text) => find.descendant(
        of: find.byKey(ValueKey('row-$row')),
        matching: find.text(text),
      );
      expect(tag('maps', 'ON ARC'), findsOneWidget);
      expect(tag('ozel', 'ON ARC'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('index-S')));
      await tester.pumpAndSettle();
      expect(tag('slack', 'WORK'), findsOneWidget);
      expect(tag('slack', 'ON ARC'), findsNothing);
    });

    testWidgets('the letter index jumps to a section', (tester) async {
      await pumpLauncher(tester, ManyApps(), start: 'apps');
      expect(find.text('Zeta 29'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('index-Z')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('heading-Z')), findsOneWidget);
      final z = tester.widget<Text>(find.byKey(const ValueKey('index-Z')));
      expect(z.style!.color, HaloColors.volt);
    });

    testWidgets('tapping a row launches it', (tester) async {
      await pumpLauncher(tester, MockBackend(), start: 'apps');
      await tester.tap(find.byKey(const ValueKey('row-maps')));
      await tester.pumpAndSettle();
      // The mock can't start apps, so the stand-in shows.
      expect(find.text('MAPS'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters as you type and hides the index', (tester) async {
      await pumpLauncher(tester, ManyApps(), start: 'apps');
      await tester.enterText(find.byType(EditableText), 'sik');
      await tester.pump();
      expect(find.byKey(const ValueKey('row-sikayet')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-maps')), findsNothing);
      expect(find.byType(HaloLetterIndex), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpLauncher(tester, ManyApps(), start: 'apps');
      await tester.enterText(find.byType(EditableText), 'qqq');
      await tester.pump();
      expect(find.text('NO APPS MATCH'), findsOneWidget);
    });

    testWidgets('Go launches the best match', (tester) async {
      await pumpLauncher(tester, ManyApps(), start: 'apps');
      await tester.enterText(find.byType(EditableText), 'mus');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(find.byType(AppsScreen), findsNothing);
      expect(find.text('MUSIC'), findsOneWidget);
    });
  });

  group('long-press menu', () {
    Future<void> openOnArc(
      WidgetTester tester,
      HaloBackend b,
      String id,
    ) async {
      await pumpLauncher(tester, b);
      await tester.longPress(find.byKey(ValueKey('arc-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuLayer), findsOneWidget);
    }

    testWidgets('shows shortcuts and starts one', (tester) async {
      final b = ManyApps();
      await openOnArc(tester, b, 'messages');
      expect(find.text('SHORTCUTS'), findsOneWidget);
      await tester.tap(find.text('New message'));
      await tester.pumpAndSettle();
      expect(b.shortcutsStarted, [('messages', 'new')]);
      expect(find.byType(AppMenuLayer), findsNothing);
    });

    testWidgets('moves an app on the arc', (tester) async {
      final b = MockBackend();
      await openOnArc(tester, b, 'maps');
      await tester.tap(find.text('Move left'));
      await tester.pumpAndSettle();
      expect(b.arcApps.first.id, 'maps');
    });

    testWidgets('Move left is disabled for the first app', (tester) async {
      final b = MockBackend();
      await openOnArc(tester, b, 'notes');
      await tester.tap(find.text('Move left'));
      await tester.pumpAndSettle();
      expect(b.arcApps.first.id, 'notes');
      expect(find.byType(AppMenuLayer), findsOneWidget);
    });

    testWidgets('Remove from arc', (tester) async {
      final b = ManyApps();
      await openOnArc(tester, b, 'camera');
      await tester.tap(find.text('Remove from arc'));
      await tester.pumpAndSettle();
      expect(b.arcApps.any((a) => a.id == 'camera'), isFalse);
      expect(find.byKey(const ValueKey('arc-camera')), findsNothing);
    });

    testWidgets('Add to arc from the list', (tester) async {
      final b = ManyApps()..unpinFromArc('camera');
      await pumpLauncher(tester, b, start: 'apps');
      await tester.longPress(find.byKey(const ValueKey('row-camera')));
      await tester.pumpAndSettle();
      expect(find.text('Move left'), findsNothing);
      await tester.tap(find.text('Add to arc'));
      await tester.pumpAndSettle();
      expect(b.arcApps.last.id, 'camera');
    });

    testWidgets('App info and Uninstall go to the backend', (tester) async {
      final b = ManyApps();
      await openOnArc(tester, b, 'web');
      await tester.tap(find.text('App info'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('arc-web')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uninstall'));
      await tester.pumpAndSettle();
      expect(b.appInfoRequests, ['web']);
      expect(b.uninstallRequests, ['web']);
    });

    testWidgets('no Uninstall for system apps', (tester) async {
      await pumpLauncher(tester, ManyApps(), start: 'apps');
      await tester.enterText(find.byType(EditableText), 'settings');
      await tester.pump();
      await tester.longPress(find.byKey(const ValueKey('row-settings')));
      await tester.pumpAndSettle();
      expect(find.text('App info'), findsOneWidget);
      expect(find.text('Uninstall'), findsNothing);
    });

    testWidgets('a tap outside or back closes it', (tester) async {
      await openOnArc(tester, MockBackend(), 'maps');
      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuLayer), findsNothing);

      await tester.longPress(find.byKey(const ValueKey('arc-maps')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuLayer), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  for (final light in [false, true]) {
    final suffix = light ? '_light' : '';
    testWidgets('Apps matches its golden$suffix', (tester) async {
      final b = ManyApps();
      if (light) b.setAppearance(Appearance.light);
      await pumpLauncher(tester, b, start: 'apps');
      await expectLater(
        find.byType(HaloLauncher),
        matchesGoldenFile('goldens/apps$suffix.png'),
      );
    }, tags: 'golden');

    testWidgets('the app menu matches its golden$suffix', (tester) async {
      final b = ManyApps();
      if (light) b.setAppearance(Appearance.light);
      await pumpLauncher(tester, b);
      await tester.longPress(find.byKey(const ValueKey('arc-messages')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(HaloLauncher),
        matchesGoldenFile('goldens/app_menu$suffix.png'),
      );
    }, tags: 'golden');
  }
}
