import 'package:halo_sdk/halo_sdk.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10);

  HaloNotification n(
    String id, {
    bool unread = false,
    bool canReply = false,
    String sender = 'Someone',
  }) => HaloNotification(
    id: id,
    app: 'app',
    sender: sender,
    body: 'body',
    receivedAt: now,
    unread: unread,
    canReply: canReply,
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
}
