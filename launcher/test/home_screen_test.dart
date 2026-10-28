import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/home/home_screen.dart';
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
    // Android's status bar shows the time and battery; Halo's row leads to
    // Stream and Switchboard instead (D-024).
    expect(find.text('STREAM'), findsOneWidget);
    expect(find.text('SWITCHBOARD'), findsOneWidget);
    expect(find.textContaining('09:41', findRichText: true), findsNothing);
    expect(find.text('NOW'), findsOneWidget);
    // The headline and the TODAY row both say it.
    expect(find.text('Design review'), findsNWidgets(2));
    expect(find.text('in 19 min'), findsOneWidget);
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

  testWidgets('without a next event NOW shows the top message', (tester) async {
    useReferenceFrame(tester);
    await tester.pumpWidget(
      app(
        HomeScreen(
          backend: MockBackend(now: DateTime(2026, 10, 23, 23)),
          onLaunch: (_) {},
        ),
      ),
    );
    expect(find.text('Elif'), findsOneWidget);
    expect(find.text('wrote you'), findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Navigate'), findsNothing);
    // The card below would only repeat it.
    expect(find.byType(HaloActionCard), findsNothing);
  });

  testWidgets('with no event and nothing waiting Home is clear', (
    tester,
  ) async {
    useReferenceFrame(tester);
    await tester.pumpWidget(
      app(
        HomeScreen(
          backend: _Quiet(now: DateTime(2026, 10, 23, 23)),
          onLaunch: (_) {},
        ),
      ),
    );
    expect(find.text('Clear for'), findsOneWidget);
    expect(find.text('the day'), findsOneWidget);
    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Reply'), findsNothing);
  });

  testWidgets('a message with no reply action is opened, not answered', (
    tester,
  ) async {
    useReferenceFrame(tester);
    final b = _NoReply(now: DateTime(2026, 10, 23, 23));
    await tester.pumpWidget(app(HomeScreen(backend: b, onLaunch: (_) {})));
    expect(find.text('Deniz'), findsOneWidget);
    expect(find.text('wrote you'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    await tester.tap(find.text('Open'));
    expect(b.openedNotifications, ['sms-9']);
  });

  testWidgets('the card below offers Open for such a message too', (
    tester,
  ) async {
    useReferenceFrame(tester);
    // With an event NOW shows the event, and the message gets the card.
    final b = _NoReply();
    await tester.pumpWidget(app(HomeScreen(backend: b, onLaunch: (_) {})));
    expect(find.byType(HaloActionCard), findsOneWidget);
    expect(find.text('Running late'), findsOneWidget);
    await tester.tap(find.text('Open'));
    expect(b.openedNotifications, ['sms-9']);
    expect(find.text('Reply'), findsNothing);
  });

  group('a long title in NOW', () {
    Future<_LongEvent> pumpLong(WidgetTester tester, String title) async {
      useReferenceFrame(tester);
      final b = _LongEvent(title);
      await tester.pumpWidget(app(HomeScreen(backend: b, onLaunch: (_) {})));
      return b;
    }

    double navigateTop(WidgetTester tester) =>
        tester.getTopLeft(find.text('Navigate')).dy;

    testWidgets('shrinks to fit its line, and nothing moves', (tester) async {
      await pumpHome(tester);
      final normal = navigateTop(tester);
      const title = 'Quarterly planning review';
      await pumpLong(tester, title);
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final line = find.text(title).first;
      final size = tester.widget<Text>(line).style!.fontSize!;
      expect(size, lessThan(42));
      expect(size, greaterThanOrEqualTo(42 * 0.6));
      expect(tester.getRect(line).right, lessThanOrEqualTo(24 + 342 + 0.5));
      // It is still two lines: what is under it is where it was.
      expect(navigateTop(tester), closeTo(normal, 0.5));
      expect(find.text('in 19 min'), findsOneWidget);
    });

    testWidgets('one far too long for that ends in an ellipsis', (
      tester,
    ) async {
      await pumpHome(tester);
      final normal = navigateTop(tester);
      const title =
          'Annual general meeting of the neighbourhood cooperative and picnic';
      await pumpLong(tester, title);
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(title).first);
      expect(text.style!.fontSize, closeTo(42 * 0.6, 0.01));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
      expect(navigateTop(tester), closeTo(normal, 0.5));
      // The whole title is still in the TODAY row.
      expect(find.text(title), findsNWidgets(2));
    });

    testWidgets('a short one stays at full size', (tester) async {
      await pumpLong(tester, 'Dentist');
      expect(
        tester.widget<Text>(find.text('Dentist').first).style!.fontSize,
        42,
      );
    });

    testWidgets('a long sender gets the same treatment', (tester) async {
      useReferenceFrame(tester);
      final b = _LongSender(now: DateTime(2026, 10, 23, 23));
      await tester.pumpWidget(app(HomeScreen(backend: b, onLaunch: (_) {})));
      expect(tester.takeException(), isNull);
      expect(find.text('wrote you'), findsOneWidget);
      expect(
        tester.getRect(find.textContaining('Weapon of Choice').first).right,
        lessThanOrEqualTo(24 + 342 + 0.5),
      );
    });
  });

  testWidgets('matches the golden', (tester) async {
    await pumpHome(tester);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
  }, tags: 'golden');
}

/// Nothing posted: no messages to pick from.
class _Quiet extends MockBackend {
  _Quiet({super.now});

  @override
  List<HaloNotification> get notifications => const [];
}

/// A person wrote, and their app offers no reply.
class _NoReply extends MockBackend {
  _NoReply({super.now});

  @override
  List<HaloNotification> get notifications => [
    HaloNotification(
      id: 'sms-9',
      app: 'messages',
      sender: 'Deniz',
      body: 'Running late',
      receivedAt: now.subtract(const Duration(minutes: 3)),
      unread: true,
      mark: StreamMark.current,
      fromPerson: true,
    ),
  ];
}

/// The next event has the given title.
class _LongEvent extends MockBackend {
  _LongEvent(this.title);

  final String title;

  @override
  List<CalendarEvent> get agenda => [
    CalendarEvent(
      start: now.add(const Duration(minutes: 19)),
      title: title,
      location: 'Room 3',
    ),
  ];
}

/// A person with a very long name wrote.
class _LongSender extends MockBackend {
  _LongSender({super.now});

  @override
  List<HaloNotification> get notifications => [
    HaloNotification(
      id: 'x',
      app: 'messages',
      sender: 'Weapon of Choice (feat. Dirty Dike ve King Kenzo) Remix',
      body: 'hi',
      receivedAt: now,
      unread: true,
      canReply: true,
      fromPerson: true,
    ),
  ];
}
