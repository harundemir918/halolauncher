import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/design_frame.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/main.dart';
import 'package:halo_launcher/switchboard/switchboard_screen.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

/// The mock, with the platform behavior an Android phone has.
class PhoneBackend extends MockBackend {
  PhoneBackend({this.defaultHome = true, this.empty = false});

  final bool defaultHome;

  /// Serve nothing but apps, as the Android backend does in Phase 1.
  final bool empty;

  final home = StreamController<void>.broadcast();
  final launched = <String>[];
  var defaultRequests = 0;

  @override
  Stream<void> get homePressed => home.stream;

  @override
  Future<bool> launch(String id) async {
    launched.add(id);
    return true;
  }

  @override
  bool get isDefaultHome => defaultHome;

  @override
  Future<void> requestDefaultHome() async => defaultRequests++;

  @override
  List<CalendarEvent> get agenda => empty ? const [] : super.agenda;

  @override
  CalendarEvent? get nextEvent => empty ? null : super.nextEvent;

  @override
  List<HaloNotification> get notifications =>
      empty ? const [] : super.notifications;

  @override
  List<HaloNotification> get lockPreviews =>
      empty ? const [] : super.lockPreviews;

  @override
  List<HaloAppInfo> get recents => empty ? const [] : super.recents;

  @override
  QuickSettings get quick => empty
      ? const QuickSettings(
          brightness: 0.5,
          brightnessAuto: true,
          volume: 0.5,
          volumeFooter: 'Media',
          toggles: [],
        )
      : super.quick;

  @override
  StreamSummary get streamSummary => empty
      ? const StreamSummary(newCount: 0, read: 0, needYou: [])
      : super.streamSummary;

  @override
  DeviceStatus get status =>
      empty ? const DeviceStatus(battery: 0.5, network: '') : super.status;
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
    Size size = const Size(390, 844),
    double dpr = 2,
  }) {
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(HaloLauncher(backend: backend, start: start));
  }

  group('DesignFrame', () {
    testWidgets('lays out 390 wide inside the safe area on a real phone', (
      tester,
    ) async {
      // A 1080 × 2400 phone at 2.625: 411 × 914 logical, status bar and
      // gesture bar insets.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.view.padding = const FakeViewPadding(top: 63, bottom: 63);
      addTearDown(tester.view.reset);
      late Size seen;
      late EdgeInsets padding;
      await tester.pumpWidget(
        DesignFrame(
          child: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              padding = MediaQuery.paddingOf(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      expect(seen.width, 390);
      // (914.3 - 48) logical at a scale of 411.4 / 390.
      expect(seen.height, closeTo(821.2, 0.5));
      expect(padding, EdgeInsets.zero);
    });

    testWidgets('the keyboard shortens the frame, never shrinks it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.view.padding = const FakeViewPadding(top: 63, bottom: 63);
      // A keyboard about 330 logical high.
      tester.view.viewInsets = const FakeViewPadding(bottom: 866);
      addTearDown(tester.view.reset);
      late Size seen;
      await tester.pumpWidget(
        DesignFrame(
          child: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      expect(seen.width, 390);
      // (914.3 - 24 - 329.9) logical at a scale of 411.4 / 390.
      expect(seen.height, closeTo(531.2, 0.5));
      // Same scale as without the keyboard: full width on screen.
      expect(
        tester.getRect(find.byType(SizedBox).last).width,
        closeTo(411.4, 0.5),
      );
    });

    testWidgets('the launcher does not resize for the keyboard', (
      tester,
    ) async {
      await pumpLauncher(tester, PhoneBackend(), start: 'apps');
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isFalse);
    });

    testWidgets('changes nothing at 390 × 844 without insets', (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const DesignFrame(child: SizedBox.expand()));
      expect(tester.getSize(find.byType(SizedBox).last), const Size(390, 844));
    });
  });

  testWidgets('Home press returns to Home from any screen', (tester) async {
    final b = PhoneBackend();
    await pumpLauncher(tester, b, start: 'switchboard');
    expect(find.byType(SwitchboardScreen), findsOneWidget);
    b.home.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('back returns to Home and never leaves the launcher', (
    tester,
  ) async {
    await pumpLauncher(tester, PhoneBackend(), start: 'switchboard');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a started app needs no stand-in', (tester) async {
    final b = PhoneBackend();
    await pumpLauncher(tester, b);
    await tester.tap(find.byKey(const ValueKey('arc-messages')));
    await tester.pumpAndSettle();
    expect(b.launched, ['messages']);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  group('default home card', () {
    testWidgets('asks to become the home screen', (tester) async {
      final b = PhoneBackend(defaultHome: false);
      await pumpLauncher(tester, b);
      expect(find.text('Set Halo as home?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      expect(b.defaultRequests, 1);
    });

    testWidgets('Later puts it away', (tester) async {
      await pumpLauncher(tester, PhoneBackend(defaultHome: false));
      await tester.tap(find.text('Later'));
      await tester.pump();
      expect(find.text('Set Halo as home?'), findsNothing);
    });

    testWidgets('is not shown once Halo is the default', (tester) async {
      await pumpLauncher(tester, PhoneBackend());
      expect(find.text('Set Halo as home?'), findsNothing);
    });
  });

  testWidgets('every screen renders with nothing but apps', (tester) async {
    for (final start in const [
      'lock',
      'home',
      'switchboard',
      'recents',
      'stream',
      'system',
    ]) {
      await pumpLauncher(tester, PhoneBackend(empty: true), start: start);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: start);
      expect(find.byType(DesignFrame), findsOneWidget, reason: start);
    }
  });

  testWidgets('the status row drops an empty network label', (tester) async {
    await pumpLauncher(tester, PhoneBackend(empty: true));
    expect(find.textContaining('· 50%'), findsNothing);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.byType(HaloStatusRow), findsOneWidget);
  });

  testWidgets('Home picks its start focus once the arc has apps', (
    tester,
  ) async {
    final b = LateArc();
    await pumpLauncher(tester, b);
    expect(find.byType(HaloArc), findsOneWidget);
    b.fill();
    await tester.pumpAndSettle();
    // Seven apps: the middle one, Messages, not the first.
    expect(find.text('MESSAGES'), findsOneWidget);
  });

  testWidgets('Home has no TODAY heading without events', (tester) async {
    await pumpLauncher(tester, PhoneBackend(empty: true));
    expect(find.text('Clear for\nthe day'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('Home keeps TODAY when there are events', (tester) async {
    await pumpLauncher(tester, PhoneBackend());
    expect(find.text('TODAY'), findsOneWidget);
  });
}

/// An arc that is empty at first, as right after an install.
class LateArc extends PhoneBackend {
  bool _filled = false;
  final _changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changed.stream;

  @override
  List<HaloAppInfo> get arcApps => _filled ? super.arcApps : const [];

  void fill() {
    _filled = true;
    _changed.add(null);
  }
}
