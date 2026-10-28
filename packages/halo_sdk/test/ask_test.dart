import 'package:halo_sdk/halo_sdk.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 10, 26, 10);
  HaloNotification n(String id, String sender, {bool canReply = true}) =>
      HaloNotification(
        id: id,
        app: 'messages',
        sender: sender,
        body: 'hi',
        receivedAt: at,
        unread: true,
        canReply: canReply,
      );

  final inbox = [
    n('1', 'Elif'),
    n('2', 'Mira Okafor'),
    n('3', 'Bot', canReply: false),
  ];

  test('one-word commands match from the third letter', () {
    expect(parseAsk('next'), isA<AskNext>());
    expect(parseAsk('nex'), isA<AskNext>());
    expect(parseAsk('next event'), isA<AskNext>());
    expect(parseAsk('ne'), isNull);
    expect(parseAsk('Battery'), isA<AskBattery>());
    expect(parseAsk('bat'), isA<AskBattery>());
    expect((parseAsk('dark') as AskAppearance).appearance, Appearance.dark);
    expect((parseAsk('lig') as AskAppearance).appearance, Appearance.light);
  });

  test('focus toggles, or is set on or off', () {
    expect((parseAsk('focus') as AskFocus).on, isNull);
    expect((parseAsk('focus on') as AskFocus).on, isTrue);
    expect((parseAsk('focus off') as AskFocus).on, isFalse);
    expect(parseAsk('focus maybe'), isNull);
  });

  test('ordinary searches are not commands', () {
    expect(parseAsk(''), isNull);
    expect(parseAsk('maps'), isNull);
    expect(parseAsk('next door neighbours'), isNull);
    expect(parseAsk('dark mode settings'), isNull);
  });

  test('reply finds the sender and keeps the text as typed', () {
    final r =
        parseAsk('reply Elif On my way', notifications: inbox) as AskReply;
    expect(r.to.id, '1');
    expect(r.text, 'On my way');
  });

  test('reply matches a first name or a full name', () {
    final first =
        parseAsk('reply mira running late', notifications: inbox) as AskReply;
    expect(first.to.id, '2');
    expect(first.text, 'running late');
    final full =
        parseAsk('reply Mira Okafor ok', notifications: inbox) as AskReply;
    expect(full.to.id, '2');
    expect(full.text, 'ok');
  });

  test('reply points at the sender while the name is still being typed', () {
    final r = parseAsk('reply el', notifications: inbox) as AskReply;
    expect(r.to.id, '1');
    expect(r.text, isEmpty);
  });

  test('reply needs someone to reply to', () {
    expect(parseAsk('reply', notifications: inbox), isNull);
    expect(parseAsk('reply bot hello', notifications: inbox), isNull);
    expect(parseAsk('reply zed hello', notifications: inbox), isNull);
  });
}
