import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/apps/apps_screen.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/main.dart';
import 'package:halo_sdk/halo_sdk.dart';

import 'support/fonts.dart';

/// Two apps on the arc, so both plus slots are in view.
MockBackend shortArc() {
  final b = MockBackend();
  for (final a in b.arcApps.skip(2).toList()) {
    b.unpinFromArc(a.id);
  }
  return b;
}

/// More apps than the arc holds, with [onArc] of them on it.
MockBackend crowded(int onArc) {
  final b = _Crowded();
  for (final a in b.apps) {
    if (b.arcApps.length >= onArc) break;
    b.pinToArc(a.id);
  }
  return b;
}

class _Crowded extends MockBackend {
  @override
  List<HaloAppInfo> get apps => [
    ...super.apps,
    for (var i = 0; i < 6; i++) HaloAppInfo(id: 'x$i', label: 'Extra $i'),
  ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  Future<void> pumpLauncher(WidgetTester tester, HaloBackend backend) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(HaloLauncher(backend: backend, start: 'home'));
  }

  /// Tap the plus slot until it is the focused one, then once more to add.
  Future<void> openPicker(WidgetTester tester, String key) async {
    final plus = find.byKey(ValueKey(key));
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
  }

  testWidgets('the arc has a plus slot at each end', (tester) async {
    await pumpLauncher(tester, shortArc());
    expect(find.byKey(const ValueKey('arc-add-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('arc-add-end')), findsOneWidget);
  });

  testWidgets('the end plus opens a list of apps not on the arc', (
    tester,
  ) async {
    final b = shortArc();
    await pumpLauncher(tester, b);
    await openPicker(tester, 'arc-add-end');
    expect(find.byType(AppsScreen), findsOneWidget);
    expect(find.text('Add app'), findsOneWidget);
    final onArc = {for (final a in b.arcApps) a.id};
    for (final a in b.apps) {
      expect(
        find.byKey(ValueKey('row-${a.id}')),
        onArc.contains(a.id) ? findsNothing : findsOneWidget,
        reason: a.id,
      );
    }
  });

  testWidgets('picking adds the app at the end and focuses it', (tester) async {
    final b = shortArc();
    await pumpLauncher(tester, b);
    await openPicker(tester, 'arc-add-end');
    await tester.tap(find.byKey(const ValueKey('row-web')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(b.arcApps.last.id, 'web');
    expect(find.text('WEB'), findsOneWidget);
  });

  testWidgets('the start plus adds the app first', (tester) async {
    final b = shortArc();
    await pumpLauncher(tester, b);
    await openPicker(tester, 'arc-add-start');
    await tester.tap(find.byKey(const ValueKey('row-web')));
    await tester.pumpAndSettle();
    expect(b.arcApps.first.id, 'web');
    expect(find.text('WEB'), findsOneWidget);
  });

  testWidgets('search narrows the list, and Go adds the best match', (
    tester,
  ) async {
    final b = shortArc();
    await pumpLauncher(tester, b);
    await openPicker(tester, 'arc-add-end');
    await tester.enterText(find.byType(EditableText), 'we');
    await tester.pump();
    expect(find.byKey(const ValueKey('row-web')), findsOneWidget);
    // Settings and contacts don't belong in this list.
    expect(find.text('CONTACTS'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(b.arcApps.last.id, 'web');
  });

  testWidgets('back from the picker returns Home and adds nothing', (
    tester,
  ) async {
    final b = shortArc();
    await pumpLauncher(tester, b);
    final before = b.arcApps.length;
    await openPicker(tester, 'arc-add-end');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(b.arcApps, hasLength(before));
    // The usual Apps list is unaffected afterwards.
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Apps'), findsOneWidget);
  });

  testWidgets('with no apps on the arc there is a single plus', (tester) async {
    final b = MockBackend();
    for (final a in b.arcApps.toList()) {
      b.unpinFromArc(a.id);
    }
    await pumpLauncher(tester, b);
    expect(find.byKey(const ValueKey('arc-add-start')), findsNothing);
    expect(find.byKey(const ValueKey('arc-add-end')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arc-add-end')));
    await tester.pumpAndSettle();
    expect(find.byType(AppsScreen), findsOneWidget);
  });

  group('a full arc (D-034)', () {
    testWidgets('has no plus slots', (tester) async {
      final b = crowded(maxArcApps);
      expect(b.arcApps, hasLength(maxArcApps));
      await pumpLauncher(tester, b);
      expect(find.byKey(const ValueKey('arc-add-start')), findsNothing);
      expect(find.byKey(const ValueKey('arc-add-end')), findsNothing);
    });

    testWidgets('one short of full still has them', (tester) async {
      await pumpLauncher(tester, crowded(maxArcApps - 1));
      // The focus starts mid-arc: rotate to the end to see its slot.
      await tester.drag(
        find.byKey(const ValueKey('arc-notes')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('arc-add-end')), findsOneWidget);
    });

    testWidgets('adding the last one takes the plus slots away', (
      tester,
    ) async {
      final b = crowded(maxArcApps - 1);
      await pumpLauncher(tester, b);
      await tester.drag(
        find.byKey(const ValueKey('arc-notes')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('arc-add-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('row-x5')));
      await tester.pumpAndSettle();
      expect(b.arcApps, hasLength(maxArcApps));
      expect(find.byKey(const ValueKey('arc-add-end')), findsNothing);
    });

    testWidgets('the menu says so instead of offering to add', (tester) async {
      final b = crowded(maxArcApps);
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HaloLauncher(backend: b, start: 'apps'));
      await tester.longPress(find.byKey(const ValueKey('row-x5')));
      await tester.pumpAndSettle();
      expect(find.text('Arc is full'), findsOneWidget);
      expect(find.text('Add to arc'), findsNothing);
    });

    testWidgets('the menu offers to add while there is room', (tester) async {
      final b = crowded(maxArcApps - 1);
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HaloLauncher(backend: b, start: 'apps'));
      await tester.longPress(find.byKey(const ValueKey('row-x5')));
      await tester.pumpAndSettle();
      expect(find.text('Add to arc'), findsOneWidget);
    });
  });

  group('reordering the arc by dragging', () {
    Offset at(WidgetTester tester, String id) =>
        tester.getCenter(find.byKey(ValueKey('arc-$id')));

    testWidgets('dropping an app on another place saves the new order', (
      tester,
    ) async {
      final b = MockBackend();
      expect(b.arcApps.map((a) => a.id), [
        'notes',
        'maps',
        'music',
        'messages',
        'camera',
        'web',
        'phone',
      ]);
      await pumpLauncher(tester, b);
      final g = await tester.startGesture(at(tester, 'music'));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(at(tester, 'camera'));
      await tester.pumpAndSettle();
      await g.up();
      await tester.pumpAndSettle();
      expect(b.arcApps.map((a) => a.id), [
        'notes',
        'maps',
        'messages',
        'camera',
        'music',
        'web',
        'phone',
      ]);
      // The dropped app is the focused one.
      expect(find.text('MUSIC'), findsOneWidget);
    });

    testWidgets('holding without moving still opens the menu', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b);
      await tester.longPress(find.byKey(const ValueKey('arc-music')));
      await tester.pumpAndSettle();
      expect(find.text('Remove from arc'), findsOneWidget);
      expect(b.arcApps.map((a) => a.id).toList().indexOf('music'), 2);
    });
  });
}
