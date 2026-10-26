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
  });

  final bool calendar;
  final bool notificationAccess;
  final bool realMessage;

  @override
  bool get canReadCalendar => calendar;

  @override
  List<CalendarEvent> get agenda => calendar ? super.agenda : const [];

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
}
