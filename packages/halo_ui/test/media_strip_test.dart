import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    String title = 'Night Drive',
    double progress = 0.4,
    ValueChanged<double>? onSeek,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    bool reduceMotion = false,
    double width = 342,
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
                .copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: width,
                    child: HaloMediaStrip(
                      title: title,
                      artist: 'Mira Okafor',
                      progress: progress,
                      playing: true,
                      onPlayPause: () {},
                      onNext: onNext,
                      onPrevious: onPrevious,
                      onSeek: onSeek,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect card(WidgetTester tester) => tester.getRect(find.byType(HaloMediaStrip));

  /// The card's progress bar spans its width less the 14 px side padding, and
  /// the play square (64 + 4) comes first.
  double barX(WidgetTester tester, double fraction) {
    final r = card(tester);
    final left = r.left + 68 + 14;
    final width = r.width - 68 - 28;
    return left + width * fraction;
  }

  double barY(WidgetTester tester) => card(tester).bottom - 12;

  group('seeking', () {
    testWidgets('dragging along the bar seeks where the finger lets go', (
      tester,
    ) async {
      final seeks = <double>[];
      await pumpStrip(tester, onSeek: seeks.add);
      final g = await tester.startGesture(
        Offset(barX(tester, 0.1), barY(tester)),
      );
      await g.moveTo(Offset(barX(tester, 0.5), barY(tester)));
      await g.moveTo(Offset(barX(tester, 0.8), barY(tester)));
      await tester.pump();
      expect(
        seeks,
        isEmpty,
        reason: 'nothing is sent until the finger lets go',
      );
      await g.up();
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single, closeTo(0.8, 0.03));
    });

    testWidgets('the bar follows the finger and grows while it is dragged', (
      tester,
    ) async {
      await pumpStrip(tester, progress: 0.2, onSeek: (_) {});
      double barHeight() =>
          tester.getSize(find.byType(FractionallySizedBox)).height;
      expect(barHeight(), 3);
      final before = tester.getSize(find.byType(FractionallySizedBox)).width;
      final g = await tester.startGesture(
        Offset(barX(tester, 0.2), barY(tester)),
      );
      await g.moveTo(Offset(barX(tester, 0.9), barY(tester)));
      await tester.pump();
      expect(barHeight(), 7);
      expect(
        tester.getSize(find.byType(FractionallySizedBox)).width,
        greaterThan(before * 3),
      );
      await g.up();
      await tester.pump();
      expect(barHeight(), 3);
    });

    testWidgets('a tap on the bar jumps there', (tester) async {
      final seeks = <double>[];
      await pumpStrip(tester, onSeek: seeks.add);
      await tester.tapAt(Offset(barX(tester, 0.25), barY(tester)));
      expect(seeks.single, closeTo(0.25, 0.03));
    });

    testWidgets('past the ends it stops at the ends', (tester) async {
      final seeks = <double>[];
      await pumpStrip(tester, onSeek: seeks.add);
      final g = await tester.startGesture(
        Offset(barX(tester, 0.5), barY(tester)),
      );
      await g.moveTo(Offset(card(tester).right + 100, barY(tester)));
      await g.up();
      expect(seeks.single, 1);
    });

    testWidgets('a flick across the title still skips, not seeks', (
      tester,
    ) async {
      final seeks = <double>[];
      var next = 0, previous = 0;
      await pumpStrip(
        tester,
        onSeek: seeks.add,
        onNext: () => next++,
        onPrevious: () => previous++,
      );
      final y = card(tester).top + 14;
      await tester.flingFrom(
        Offset(card(tester).right - 40, y),
        const Offset(-200, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(next, 1);
      await tester.flingFrom(
        Offset(card(tester).left + 90, y),
        const Offset(200, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(previous, 1);
      expect(seeks, isEmpty);
    });

    testWidgets('a player that can not seek has a bar that only shows', (
      tester,
    ) async {
      var next = 0;
      await pumpStrip(tester, onNext: () => next++);
      // A flick along the bar skips as before: nothing there takes it.
      await tester.flingFrom(
        Offset(card(tester).right - 40, barY(tester)),
        const Offset(-200, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(next, 1);
    });

    testWidgets('a screen reader gets a slider it can step', (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = <double>[];
      await pumpStrip(tester, progress: 0.4, onSeek: seeks.add);
      final node = find.semantics.byLabel('Track position');
      expect(node, findsOneWidget);
      expect(node.evaluate().single.value, '40%');
      tester.semantics.increase(node);
      tester.semantics.decrease(node);
      expect(seeks[0], closeTo(0.45, 0.001));
      expect(seeks[1], closeTo(0.35, 0.001));
      handle.dispose();
    });
  });

  group('the title', () {
    testWidgets('a short title sits still', (tester) async {
      await pumpStrip(tester, title: 'Night Drive');
      final at = tester.getTopLeft(find.text('Night Drive'));
      await tester.pump(const Duration(seconds: 4));
      expect(tester.getTopLeft(find.text('Night Drive')), at);
      expect(tester.hasRunningAnimations, isFalse);
    });

    const long = 'A Very Long Track Name That Cannot Possibly Fit In The Card';

    testWidgets('a long one waits, slides to its end, and comes back', (
      tester,
    ) async {
      await pumpStrip(tester, title: long);
      Finder text() => find.text(long);
      final start = tester.getTopLeft(text()).dx;
      // Over a few whole cycles (one is about 14 s here).
      final xs = <double>[start];
      for (var i = 0; i < 450; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        xs.add(tester.getTopLeft(text()).dx);
      }
      // It rests at the start first.
      expect(xs.take(10).every((x) => (x - start).abs() < 0.01), isTrue);
      // It slides left until the end of the text is in the card.
      final far = xs.reduce((a, b) => a < b ? a : b);
      final end = far + tester.getSize(text()).width;
      expect(end, closeTo(card(tester).right - 14, 1));
      // And, having been there, it comes back to the start.
      final atEnd = xs.indexWhere((x) => (x - far).abs() < 0.5);
      expect(atEnd, greaterThan(0));
      expect(
        xs.skip(atEnd).any((x) => (x - start).abs() < 0.5),
        isTrue,
        reason: 'it goes back to the start after reaching the end',
      );
      // Never to the right of where it began.
      expect(xs.every((x) => x <= start + 0.01), isTrue);
    });

    testWidgets('it never draws outside the card', (tester) async {
      await pumpStrip(tester, title: long);
      await tester.pump(const Duration(seconds: 3));
      // The text is wider than the card but clipped to it.
      expect(find.byType(ClipRect), findsWidgets);
      expect(
        tester.getSize(find.text(long)).width,
        greaterThan(card(tester).width),
      );
    });

    testWidgets('with animations removed it stays still, in an ellipsis', (
      tester,
    ) async {
      await pumpStrip(tester, title: long, reduceMotion: true);
      final at = tester.getTopLeft(find.text(long));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.getTopLeft(find.text(long)), at);
      expect(tester.hasRunningAnimations, isFalse);
      final text = tester.widget<Text>(find.text(long));
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a new title starts from its beginning', (tester) async {
      await pumpStrip(tester, title: long);
      await tester.pump(const Duration(seconds: 4));
      const other = 'Another Equally Long Name That Does Not Fit In The Card';
      await pumpStrip(tester, title: other);
      await tester.pump(const Duration(milliseconds: 100));
      final left = card(tester).left + 68 + 14;
      expect(tester.getTopLeft(find.text(other)).dx, closeTo(left, 1));
    });
  });
}
