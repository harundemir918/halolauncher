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

    testWidgets('a long one rests, then goes round and round, never back', (
      tester,
    ) async {
      await pumpStrip(tester, title: long);
      Finder text() => find.text(long).first;
      final start = tester.getTopLeft(text()).dx;
      final width = tester.getSize(text()).width;
      // Over a few whole rounds (one is about 27 s with this test font).
      final xs = <double>[start];
      final copy = <double>[];
      for (var i = 0; i < 900; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        xs.add(tester.getTopLeft(text()).dx);
        copy.add(tester.getTopLeft(find.text(long).last).dx);
      }
      // It rests with its beginning in view first.
      expect(xs.take(10).every((x) => (x - start).abs() < 0.01), isTrue);
      final steps = [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]];
      // It only ever moves left, except when a round ends and it is back at
      // the start, which is a jump right to where it began.
      final wraps = [
        for (var i = 0; i < steps.length; i++)
          if (steps[i] > 1) i,
      ];
      expect(wraps.length, greaterThanOrEqualTo(2), reason: 'goes round again');
      for (final w in wraps) {
        expect(
          xs[w + 1],
          closeTo(start, 4),
          reason: 'a round ends at the start',
        );
      }
      expect(
        [
          for (var i = 0; i < steps.length; i++)
            if (!wraps.contains(i)) steps[i],
        ].every((d) => d <= 0.01),
        isTrue,
        reason: 'never slides back',
      );
      // At a steady 36 px a second, 3.6 px every 100 ms.
      final moving = [
        for (var i = 0; i < steps.length; i++)
          if (!wraps.contains(i) && steps[i] < -0.5) steps[i],
      ];
      expect(moving, isNotEmpty);
      // (A step where the rest ends or a round ends is only partly a step.)
      expect(moving.every((d) => d >= -4.1), isTrue, reason: 'never faster');
      expect(
        moving.where((d) => (d + 3.6).abs() < 0.2).length,
        greaterThan(moving.length * 0.9),
      );
      // The copy comes in from the right while the end of the text leaves.
      final r = card(tester);
      expect(
        copy.any((x) => x > r.left + 82 && x < r.right - 14),
        isTrue,
        reason: 'the beginning comes round into the card',
      );
      // One round brings the text its own width and the gap to the left.
      expect(width, greaterThan(card(tester).width));
    });

    testWidgets('it never draws outside the card', (tester) async {
      await pumpStrip(tester, title: long);
      await tester.pump(const Duration(seconds: 3));
      // The text is wider than the card but clipped to it.
      expect(find.byType(ClipRect), findsWidgets);
      expect(
        tester.getSize(find.text(long).first).width,
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
      expect(tester.getTopLeft(find.text(other).first).dx, closeTo(left, 1));
    });
  });
}
