import 'package:halo_sdk/halo_sdk.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10);

  HaloNotification n(
    String id, {
    bool unread = false,
    bool canReply = false,
    String sender = 'Someone',
    NotificationKind kind = NotificationKind.other,
    bool fromPerson = false,
    bool starred = false,
  }) => HaloNotification(
    id: id,
    app: 'app',
    sender: sender,
    body: 'body',
    receivedAt: now,
    unread: unread,
    canReply: canReply,
    kind: kind,
    fromPerson: fromPerson,
    starred: starred,
  );

  CalendarEvent event(String title, int hour, [int minute = 0]) =>
      CalendarEvent(
        start: DateTime(2026, 10, 26, hour, minute),
        title: title,
        location: '',
      );

  test('the next event is the first one not yet started', () {
    final agenda = [
      CalendarEvent(start: DateTime(2026, 10, 26, 9), title: 'A', location: ''),
      CalendarEvent(
        start: DateTime(2026, 10, 26, 10),
        title: 'B',
        location: '',
      ),
      CalendarEvent(
        start: DateTime(2026, 10, 26, 13),
        title: 'C',
        location: '',
      ),
    ];
    expect(nextEventIn(agenda, now)?.title, 'B');
    expect(nextEventIn(agenda, DateTime(2026, 10, 26, 14)), isNull);
    expect(nextEventIn(const [], now), isNull);
  });

  test('an all-day event is never next', () {
    final agenda = [
      CalendarEvent(
        start: DateTime(2026, 10, 26),
        title: 'Holiday',
        location: '',
        allDay: true,
      ),
      CalendarEvent(
        start: DateTime(2026, 10, 26, 11),
        title: 'B',
        location: '',
      ),
    ];
    expect(nextEventIn(agenda, DateTime(2026, 10, 26)), same(agenda[1]));
  });

  test('summary: new, read, and unread messages to reply to', () {
    final s = summaryOf([
      n('1', unread: true, canReply: true, sender: 'Elif'),
      n('2', unread: true),
      n('3'),
      n('4', canReply: true, sender: 'Deniz'),
    ]);
    expect(s.newCount, 2);
    expect(s.read, 2);
    expect(s.needYou, ['Reply to Elif']);
  });

  test('previews prefer unread, at most two', () {
    expect(
      previewsOf([n('1'), n('2', unread: true), n('3')]).map((p) => p.id),
      ['2'],
    );
    expect(previewsOf([n('1'), n('2'), n('3')]).map((p) => p.id), ['1', '2']);
  });

  test('the top message is the newest unread one with a reply action', () {
    expect(
      topMessageOf([
        n('1', unread: true),
        n('2', unread: true, canReply: true),
        n('3', unread: true, canReply: true),
      ])?.id,
      '2',
    );
    expect(topMessageOf([n('1', canReply: true)]), isNull);
  });

  test('priority: starred people, people, apps; Focus holds apps back', () {
    expect(
      priorityOf(n('1', starred: true, fromPerson: true)),
      Priority.starred,
    );
    expect(priorityOf(n('1', fromPerson: true)), Priority.person);
    expect(
      priorityOf(n('1', kind: NotificationKind.missedCall)),
      Priority.person,
    );
    expect(priorityOf(n('1')), Priority.app);
    expect(priorityOf(n('1'), focus: true), Priority.held);
    expect(priorityOf(n('1', fromPerson: true), focus: true), Priority.person);
  });

  test('summary adds missed calls and an event about to start', () {
    final s = summaryOf(
      [
        n('1', unread: true, canReply: true, sender: 'Bot'),
        n('2', unread: true, kind: NotificationKind.missedCall, sender: 'Anne'),
        n(
          '3',
          unread: true,
          canReply: true,
          fromPerson: true,
          starred: true,
          sender: 'Elif',
        ),
      ],
      agenda: [event('Design review', 10, 19)],
      now: now,
    );
    expect(s.needYou, [
      'Reply to Elif',
      'Design review in 19 min',
      'Call back Anne',
      'Reply to Bot',
    ]);
  });

  test('an event more than an hour away is not on the summary', () {
    final s = summaryOf(const [], agenda: [event('Lunch', 12)], now: now);
    expect(s.needYou, isEmpty);
  });

  test('Focus keeps apps out of what needs you', () {
    final list = [
      n('1', unread: true, canReply: true, sender: 'Bot'),
      n('2', unread: true, canReply: true, fromPerson: true, sender: 'Elif'),
    ];
    expect(summaryOf(list, focus: true).needYou, ['Reply to Elif']);
    expect(summaryOf(list).needYou, ['Reply to Elif', 'Reply to Bot']);
  });

  test('the top message prefers a person over a newer app message', () {
    final list = [
      n('1', unread: true, canReply: true),
      n('2', unread: true, canReply: true, fromPerson: true),
      n('3', unread: true, canReply: true, fromPerson: true, starred: true),
    ];
    expect(topMessageOf(list)?.id, '3');
    expect(topMessageOf(list.sublist(0, 2))?.id, '2');
    expect(topMessageOf([list.first], focus: true), isNull);
  });

  test('NOW: the next event, else the top message, else clear', () {
    final msg = n('1', unread: true, canReply: true, sender: 'Elif');
    final withEvent = nowPickOf(
      agenda: [event('Design review', 11)],
      notifications: [msg],
      now: now,
    );
    expect((withEvent as NowEvent).event.title, 'Design review');
    final withMessage = nowPickOf(
      agenda: const [],
      notifications: [msg],
      now: now,
    );
    expect((withMessage as NowMessage).message.id, '1');
    expect(
      nowPickOf(agenda: const [], notifications: const [], now: now),
      isA<NowClear>(),
    );
  });

  group('a message nobody can reply to from here', () {
    test('a person\'s unread message is the top message, to be opened', () {
      final list = [
        n('1', unread: true, sender: 'Elif', fromPerson: true),
        n('2', unread: true, sender: 'Bot'),
      ];
      expect(topMessageOf(list)?.id, '1');
    });

    test('an app\'s message without a reply or a person is not one', () {
      expect(topMessageOf([n('1', unread: true)]), isNull);
    });

    test('a missed call is not a message', () {
      expect(
        topMessageOf([
          n(
            '1',
            unread: true,
            kind: NotificationKind.missedCall,
            fromPerson: true,
          ),
        ]),
        isNull,
      );
    });

    test('it ranks like any other: a starred reply beats it', () {
      final list = [
        n('1', unread: true, fromPerson: true),
        n('2', unread: true, canReply: true, fromPerson: true, starred: true),
      ];
      expect(topMessageOf(list)?.id, '2');
      // Equal rank: the newer (first) one.
      expect(
        topMessageOf([
          n('3', unread: true, fromPerson: true),
          n('4', unread: true, canReply: true, fromPerson: true),
        ])?.id,
        '3',
      );
    });

    test('Focus holds back apps, not people', () {
      expect(
        topMessageOf([n('1', unread: true, fromPerson: true)], focus: true)?.id,
        '1',
      );
    });

    test('the summary says to read it', () {
      final s = summaryOf([
        n('1', unread: true, sender: 'Elif', fromPerson: true),
        n('2', unread: true, sender: 'Deniz', canReply: true, fromPerson: true),
        n('3', unread: true, sender: 'Bot'),
      ]);
      // Both people, in the order of the list (the same rank).
      expect(s.needYou, ['Read Elif', 'Reply to Deniz']);
      expect(s.needYou, isNot(contains('Read Bot')));
    });

    test('NOW shows it when there is no event', () {
      final pick = nowPickOf(
        agenda: const [],
        notifications: [n('1', unread: true, sender: 'Elif', fromPerson: true)],
        now: now,
      );
      expect((pick as NowMessage).message.id, '1');
    });
  });
}
