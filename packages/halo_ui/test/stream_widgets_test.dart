import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

Future<void> pumpIn(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: HaloTheme.dark(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 342, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('chip is an uppercase Volt notch with carbon text', (
    tester,
  ) async {
    await pumpIn(tester, const Row(children: [HaloChip('4 new')]));
    expect(find.text('4 NEW'), findsOneWidget);
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(HaloChip),
        matching: find.byType(Container),
      ),
    );
    final deco = box.decoration! as ShapeDecoration;
    expect(deco.color, HaloColors.volt);
    expect((deco.shape as NotchBorder).borderRadius, HaloRadii.notchXS);
    expect(
      tester.widget<Text>(find.text('4 NEW')).style?.color,
      HaloColors.carbon,
    );
  });

  testWidgets('summary card numbers its items and is Volt', (tester) async {
    await pumpIn(
      tester,
      const HaloSummaryCard(
        kicker: 'Halo read 11 things for you',
        headline: '3 need you.',
        items: ['One', 'Two', 'Three'],
      ),
    );
    expect(find.text('HALO READ 11 THINGS FOR YOU'), findsOneWidget);
    expect(find.text('3 need you.'), findsOneWidget);
    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsOneWidget);
    }
    final deco =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(HaloSummaryCard),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as ShapeDecoration;
    expect(deco.color, HaloColors.volt);
    expect((deco.shape as NotchBorder).borderRadius, HaloRadii.notchXXL);
  });

  testWidgets('timeline section label is 20 high and uppercase', (
    tester,
  ) async {
    await pumpIn(
      tester,
      const HaloTimeline(children: [HaloTimelineSection('Now')]),
    );
    expect(find.text('NOW'), findsOneWidget);
    expect(tester.getSize(find.byType(HaloTimelineSection)).height, 20);
  });

  testWidgets('text action underlines in its own color and taps', (
    tester,
  ) async {
    var taps = 0;
    await pumpIn(
      tester,
      Row(
        children: [
          HaloTextAction(
            'Reply',
            color: HaloColors.volt,
            onPressed: () => taps++,
          ),
        ],
      ),
    );
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(HaloTextAction),
        matching: find.byType(Container),
      ),
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.bottom.color, HaloColors.volt);
    expect(border.bottom.width, 1);
    await tester.tap(find.text('REPLY'));
    expect(taps, 1);
  });

  testWidgets('timeline item shows its header, time and body', (tester) async {
    await pumpIn(
      tester,
      const HaloTimeline(
        children: [
          HaloTimelineItem(
            mark: HaloMark.alert,
            source: 'Calendar',
            time: '9:40',
            body: 'Design review starts in 19 minutes.',
          ),
        ],
      ),
    );
    expect(find.text('CALENDAR'), findsOneWidget);
    expect(find.text('9:40'), findsOneWidget);
    expect(find.text('Design review starts in 19 minutes.'), findsOneWidget);
    // The alert dot is Flare.
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == HaloColors.flare,
        );
    expect(dots.length, 1);
  });

  testWidgets('media strip shows pause while playing, play when paused', (
    tester,
  ) async {
    await pumpIn(
      tester,
      HaloMediaStrip(
        title: 'Night Drive',
        artist: 'Mira Okafor',
        progress: 0.42,
        playing: true,
        onPlayPause: () {},
      ),
    );
    expect(tester.getSize(find.byType(HaloMediaStrip)).height, 64);
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    await pumpIn(
      tester,
      HaloMediaStrip(
        title: 'Night Drive',
        artist: 'Mira Okafor',
        progress: 0.42,
        playing: false,
        onPlayPause: () {},
      ),
    );
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('a long source ellipsizes and keeps the time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HaloTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 342,
            child: HaloTimelineItem(
              mark: HaloMark.read,
              source:
                  'Google Play services · Action required: Theft protection '
                  'is on, tap to finish setup',
              time: '22:38',
              body: 'Theft protection is on.',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('22:38'), findsOneWidget);
    final source = tester.widget<Text>(find.textContaining('GOOGLE PLAY'));
    expect(source.overflow, TextOverflow.ellipsis);
  });
}
