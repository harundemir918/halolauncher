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
}
