import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String sender,
    String body = 'Are we still on for 7?',
    double textScale = 1,
  }) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: HaloTheme.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: HaloNotificationPreview(
                  sender: sender,
                  body: body,
                  age: '2M',
                  unread: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect row(WidgetTester tester) =>
      tester.getRect(find.byType(HaloNotificationPreview));

  testWidgets('a short sender is whole, and the text follows it', (
    tester,
  ) async {
    await pump(tester, sender: 'Elif');
    expect(tester.takeException(), isNull);
    final sender = tester.widget<Text>(find.text('ELIF'));
    expect(sender.overflow, TextOverflow.ellipsis);
    expect(find.text('Are we still on for 7?'), findsOneWidget);
    expect(find.text('2M'), findsOneWidget);
  });

  testWidgets('a long sender is cut short and the age stays in view', (
    tester,
  ) async {
    const track = 'Weapon of Choice (feat. Dirty Dike ve King Kenzo) — Remix';
    await pump(tester, sender: track);
    expect(tester.takeException(), isNull, reason: 'no overflow');
    final r = row(tester);
    // The age ends at the row's right edge; nothing runs off the screen.
    expect(tester.getRect(find.text('2M')).right, lessThanOrEqualTo(r.right));
    expect(tester.getRect(find.text('2M')).left, greaterThan(r.left));
    // The sender takes at most 40% of the row.
    final label = find.text(track.toUpperCase());
    expect(tester.getSize(label).width, lessThanOrEqualTo(r.width * 0.4 + 0.5));
    // And the text still has room.
    expect(
      tester.getSize(find.text('Are we still on for 7?')).width,
      greaterThan(40),
    );
  });

  testWidgets('a long sender and a long text both end in an ellipsis', (
    tester,
  ) async {
    await pump(
      tester,
      sender: 'A group called something far too long to fit',
      body:
          'A message that goes on and on and on, well past the end of the row',
    );
    expect(tester.takeException(), isNull);
    final r = row(tester);
    for (final f in [
      find.textContaining('A GROUP'),
      find.textContaining('A message'),
      find.text('2M'),
    ]) {
      expect(tester.getRect(f).right, lessThanOrEqualTo(r.right + 0.5));
    }
  });

  testWidgets('at the largest text size it still fits', (tester) async {
    await pump(
      tester,
      sender: 'A very long sender name indeed',
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('2M')).right,
      lessThanOrEqualTo(row(tester).right),
    );
  });
}
