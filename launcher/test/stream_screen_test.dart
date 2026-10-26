import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_launcher/format.dart';
import 'package:halo_launcher/stream/stream_screen.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

Widget app(HaloBackend backend) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: HaloTheme.dark(),
  home: Scaffold(body: StreamScreen(backend: backend)),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  Future<void> pumpStream(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(app(MockBackend()));
  }

  testWidgets('shows the design copy', (tester) async {
    await pumpStream(tester);
    expect(find.text('Stream'), findsOneWidget);
    expect(find.text('4 NEW'), findsOneWidget);
    expect(find.text('HALO READ 11 THINGS FOR YOU'), findsOneWidget);
    expect(find.text('3 need you.'), findsOneWidget);
    expect(find.text('Reply to Elif about dinner'), findsOneWidget);
    expect(find.text('Design review moved to Room 3'), findsOneWidget);
    expect(find.text('Be home 14:00 to 16:00 for the parcel'), findsOneWidget);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('MESSAGES · ELIF'), findsOneWidget);
    expect(find.text('9:39'), findsOneWidget);
    expect(
      find.text('Are we still on for 7? I booked the corner table.'),
      findsOneWidget,
    );
    expect(find.text('CALENDAR'), findsOneWidget);
    expect(find.text('9:40'), findsOneWidget);
    expect(find.text('PARCEL'), findsOneWidget);
    expect(find.text('8:15'), findsOneWidget);
    expect(find.text('MESSAGES · DENIZ'), findsOneWidget);
    expect(find.text('YEST'), findsOneWidget);
    expect(find.text('REPLY'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
  });

  testWidgets('summary card is Volt with carbon text', (tester) async {
    await pumpStream(tester);
    final card = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HaloSummaryCard),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((card.decoration! as ShapeDecoration).color, HaloColors.volt);
    expect(
      tester.widget<Text>(find.text('3 need you.')).style?.color,
      HaloColors.carbon,
    );
  });

  testWidgets('dots: Volt, Flare, then two hollow rings', (tester) async {
    await pumpStream(tester);
    final items = tester
        .widgetList<HaloTimelineItem>(find.byType(HaloTimelineItem))
        .map((i) => i.mark)
        .toList();
    expect(items, [
      HaloMark.current,
      HaloMark.alert,
      HaloMark.read,
      HaloMark.read,
    ]);
  });

  testWidgets('only the Elif item has actions; REPLY is Volt, LATER ash', (
    tester,
  ) async {
    await pumpStream(tester);
    Color? colorOf(String t) => tester.widget<Text>(find.text(t)).style?.color;
    expect(colorOf('REPLY'), HaloColors.volt);
    expect(colorOf('LATER'), HaloColors.ash);
    expect(find.byType(HaloTextAction), findsNWidgets(2));
  });

  testWidgets('read items use the dimmer body color', (tester) async {
    await pumpStream(tester);
    Color? colorOf(String t) => tester.widget<Text>(find.text(t)).style?.color;
    expect(
      colorOf('Arrives today between 14:00 and 16:00.'),
      HaloColors.boneDim,
    );
    expect(
      colorOf('Design review starts in 19 minutes. Room 3.'),
      HaloColors.bone,
    );
  });

  testWidgets('layout follows the design y positions', (tester) async {
    await pumpStream(tester);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(find.byType(HaloSummaryCard)), closeTo(116, 1));
    expect(top(find.byType(HaloTimeline)), closeTo(338, 1));
    // Header text tops, measured from the design: 363 (NOW item), 468 (CALENDAR).
    expect(top(find.text('MESSAGES · ELIF')), closeTo(361, 5));
    expect(top(find.text('CALENDAR')), closeTo(468, 5));
  });

  test('stream time labels', () {
    final now = DateTime(2026, 10, 23, 9, 41);
    expect(HaloFormat.streamTime(DateTime(2026, 10, 23, 9, 39), now), '9:39');
    expect(HaloFormat.streamTime(DateTime(2026, 10, 23, 14, 5), now), '14:05');
    expect(HaloFormat.streamTime(DateTime(2026, 10, 22, 18, 5), now), 'YEST');
    expect(HaloFormat.streamTime(DateTime(2026, 10, 20, 18, 5), now), '20.10');
  });

  testWidgets('without new items there is no chip', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(_NothingNew()));
    expect(find.byType(HaloChip), findsNothing);
  });

  testWidgets('matches the golden', (tester) async {
    await pumpStream(tester);
    await expectLater(
      find.byType(StreamScreen),
      matchesGoldenFile('goldens/stream.png'),
    );
  }, tags: 'golden');
}

class _NothingNew extends MockBackend {
  @override
  StreamSummary get streamSummary =>
      const StreamSummary(newCount: 0, read: 11, needYou: ['One']);
}
