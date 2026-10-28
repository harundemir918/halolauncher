import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/main.dart';
import 'package:halo_launcher/stream/stream_screen.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

/// The mock with switches for the phone's grants, and optionally a real
/// message (no designed Yes/No question) on top.
class Grants extends MockBackend {
  Grants({
    this.calendar = true,
    this.notificationAccess = true,
    this.realMessage = false,
    this.phoneEvents = false,
  });

  /// Today's events as the phone gives them: with ids, one all day.
  final bool phoneEvents;

  final bool calendar;
  final bool notificationAccess;
  final bool realMessage;

  @override
  bool get canReadCalendar => calendar;

  @override
  List<CalendarEvent> get agenda {
    if (!calendar) return const [];
    if (!phoneEvents) return super.agenda;
    final day = DateTime(now.year, now.month, now.day);
    return [
      CalendarEvent(
        start: day,
        title: 'Republic Day',
        location: '',
        allDay: true,
        id: '1',
      ),
      CalendarEvent(
        start: now.add(const Duration(minutes: 30)),
        title: 'Dentist',
        location: 'Kadıköy',
        id: '2',
      ),
    ];
  }

  @override
  CalendarEvent? get nextEvent => nextEventIn(agenda, now);

  @override
  bool get canReadNotifications => notificationAccess;

  @override
  List<HaloNotification> get notifications {
    if (!notificationAccess) return const [];
    if (!realMessage) return super.notifications;
    return [
      HaloNotification(
        id: 'sms-1',
        app: 'messages',
        sender: 'Deniz',
        source: 'Messages · Deniz',
        body: 'Running 10 min late',
        receivedAt: now,
        unread: true,
        mark: StreamMark.current,
        canReply: true,
        fromPerson: true,
        actions: const [
          NotificationAction(id: '1', label: 'Mark as read'),
          NotificationAction(id: '2', label: 'Archive'),
          NotificationAction(id: '3', label: 'Block'),
        ],
      ),
    ];
  }

  @override
  Future<bool> replyToNotification(String id, String text) async {
    replies.add((id, text));
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

  group('Stream', () {
    testWidgets('a tap opens the notification', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b, start: 'stream');
      await tester.tap(
        find.text('Are we still on for 7? I booked the corner table.'),
      );
      expect(b.openedNotifications, ['elif-1']);
    });

    testWidgets('a sideways swipe clears it from the phone', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b, start: 'stream');
      final before = b.notifications.length;
      await tester.drag(
        find.byKey(const ValueKey('stream-elif-1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(b.notifications, hasLength(before - 1));
      expect(b.notifications.any((n) => n.id == 'elif-1'), isFalse);
    });

    testWidgets('REPLY opens a field under the item and sends', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b, start: 'stream');
      await tester.tap(find.text('REPLY'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-elif-1')), findsOneWidget);
      expect(find.text('reply to Elif'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Yes, see you at 7');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(b.replies, [('elif-1', 'Yes, see you at 7')]);
      expect(find.byKey(const ValueKey('reply-elif-1')), findsNothing);
    });

    testWidgets('LATER puts it away for an hour', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b, start: 'stream');
      await tester.tap(find.text('LATER'));
      await tester.pumpAndSettle();
      expect(b.snoozed, ['elif-1']);
    });

    testWidgets('without access it explains and asks', (tester) async {
      final b = Grants(notificationAccess: false);
      await pumpLauncher(tester, b, start: 'stream');
      expect(find.byType(HaloSummaryCard), findsNothing);
      expect(find.textContaining('NOTHING LEAVES THIS PHONE'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('notification-access')));
      expect(b.notificationAccessRequests, 1);
    });

    testWidgets('leaving Stream marks it seen', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b, start: 'stream');
      expect(b.seenMarks, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(b.seenMarks, 1);
    });
  });

  group('Home', () {
    testWidgets('without calendar access, TODAY asks for it', (tester) async {
      final b = Grants(calendar: false);
      await pumpLauncher(tester, b);
      expect(find.text('TODAY'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-allow')));
      expect(b.calendarRequests, 1);
    });

    testWidgets("the designs' card answers Yes, and Later snoozes", (
      tester,
    ) async {
      final b = MockBackend();
      await pumpLauncher(tester, b);
      await tester.tap(find.text('Yes'));
      expect(b.replies, [('elif-1', 'Yes')]);
      await tester.tap(find.text('Later'));
      expect(b.snoozed, ['elif-1']);
    });

    testWidgets('a real message offers Reply, which opens it in Stream', (
      tester,
    ) async {
      final b = Grants(realMessage: true);
      await pumpLauncher(tester, b);
      expect(find.text('Running 10 min late'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.byType(StreamScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-sms-1')), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'No problem');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(b.replies, [('sms-1', 'No problem')]);
    });
  });

  group('NOW and TODAY', () {
    testWidgets('Navigate opens the maps app at the place', (tester) async {
      final b = MockBackend();
      await pumpLauncher(tester, b);
      await tester.tap(find.text('Navigate'));
      expect(b.mapsOpened, [b.nextEvent!.location]);
      // The designs' fixture has no phone id: it keeps "Open notes".
      expect(find.text('Open notes'), findsOneWidget);
    });

    testWidgets('a phone event offers Open event; all-day reads ALL DAY', (
      tester,
    ) async {
      final b = Grants(phoneEvents: true);
      await pumpLauncher(tester, b);
      expect(find.text('Dentist\nin 30 min'), findsOneWidget);
      await tester.tap(find.text('Open event'));
      expect(b.eventsOpened, ['2']);
      expect(find.text('ALL DAY'), findsOneWidget);
      expect(find.text('Republic Day'), findsOneWidget);
    });
  });

  testWidgets("Stream shows two of the app's own actions and runs them", (
    tester,
  ) async {
    final b = Grants(realMessage: true);
    await pumpLauncher(tester, b, start: 'stream');
    expect(find.text('MARK AS READ'), findsOneWidget);
    expect(find.text('ARCHIVE'), findsOneWidget);
    expect(find.text('BLOCK'), findsNothing);
    await tester.tap(find.text('MARK AS READ'));
    expect(b.actionsRun, [('sms-1', '1')]);
  });
}
