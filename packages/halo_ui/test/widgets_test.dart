import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

Future<void> pumpHalo(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: HaloTheme.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          // A switch is meant for a Row, so give it loose constraints.
          child: SizedBox(
            width: 342,
            child: child is HaloSwitch
                ? Align(alignment: Alignment.topLeft, child: child)
                : child,
          ),
        ),
      ),
    ),
  );
}

int voltBoxes(WidgetTester tester, Finder within) => tester
    .widgetList<ColoredBox>(
      find.descendant(of: within, matching: find.byType(ColoredBox)),
    )
    .where((b) => b.color == HaloColors.volt)
    .length;

void main() {
  group('HaloSwitch', () {
    testWidgets('has a 44x44 target around a 44x24 track', (tester) async {
      await pumpHalo(tester, HaloSwitch(value: true, onChanged: (_) {}));
      expect(tester.getSize(find.byType(HaloSwitch)), const Size(44, 44));
      final track = find.descendant(
        of: find.byType(HaloSwitch),
        matching: find.byType(Container),
      );
      expect(tester.getSize(track.first), const Size(44, 24));
    });

    testWidgets('tap reports the opposite value', (tester) async {
      bool? got;
      await pumpHalo(
        tester,
        HaloSwitch(value: true, onChanged: (v) => got = v),
      );
      await tester.tap(find.byType(HaloSwitch));
      expect(got, false);
    });

    testWidgets('knob is on the right when on, left when off', (tester) async {
      Future<double> knobX(bool on) async {
        await pumpHalo(tester, HaloSwitch(value: on, onChanged: (_) {}));
        final knob = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 16 &&
              w.constraints?.maxHeight == 16,
        );
        return tester.getTopLeft(knob).dx;
      }

      expect(await knobX(true), 24); // 44 - 4 - 16
      expect(await knobX(false), 4);
    });

    testWidgets('exposes toggle semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHalo(
        tester,
        HaloSwitch(value: true, onChanged: (_) {}, semanticLabel: 'Wi-Fi'),
      );
      final node = tester.getSemantics(find.byType(HaloSwitch));
      expect(node.label, 'Wi-Fi');
      expect(
        node,
        matchesSemantics(
          label: 'Wi-Fi',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled switch ignores taps', (tester) async {
      await pumpHalo(tester, const HaloSwitch(value: false, onChanged: null));
      await tester.tap(find.byType(HaloSwitch)); // must not throw
    });
  });

  group('HaloToggleRow', () {
    testWidgets('is 52 high and shows the volt bar only when on', (
      tester,
    ) async {
      await pumpHalo(
        tester,
        HaloToggleRow(
          title: 'Wi-Fi',
          subtitle: 'Home-5G',
          value: true,
          onChanged: (_) {},
        ),
      );
      expect(tester.getSize(find.byType(HaloToggleRow)).height, 52);
      Finder bar() => find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == HaloColors.volt,
      );
      expect(
        tester.getSize(bar().first),
        const Size(3, 52), // runs over the 1 px border, like border-left
        reason: 'on',
      );
      await pumpHalo(
        tester,
        HaloToggleRow(
          title: 'Airplane',
          subtitle: 'Off',
          value: false,
          onChanged: (_) {},
        ),
      );
      // The off switch has no volt fill either, so no volt ColoredBox at all.
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == HaloColors.volt,
        ),
        findsNothing,
      );
    });

    testWidgets('subtitle is uppercase mono; tapping the row toggles', (
      tester,
    ) async {
      bool? got;
      await pumpHalo(
        tester,
        HaloToggleRow(
          title: 'Focus',
          subtitle: 'Work · until 11:00',
          value: true,
          onChanged: (v) => got = v,
        ),
      );
      expect(find.text('WORK · UNTIL 11:00'), findsOneWidget);
      await tester.tap(find.text('Focus'));
      expect(got, false);
    });
  });

  group('HaloButton', () {
    testWidgets('hugs its label instead of filling the row', (tester) async {
      await pumpHalo(
        tester,
        Row(
          children: [HaloButton(label: 'Navigate', onPressed: () {})],
        ),
      );
      final w = tester.getSize(find.byType(HaloButton)).width;
      expect(w, lessThan(200));
      expect(w, greaterThan(40)); // 20 padding each side plus the label
    });

    testWidgets('regular is 44 high, small is 32 high', (tester) async {
      await pumpHalo(tester, HaloButton(label: 'Navigate', onPressed: () {}));
      expect(tester.getSize(find.byType(HaloButton)).height, 44);
      await pumpHalo(
        tester,
        HaloButton(
          label: 'Yes',
          onPressed: () {},
          variant: HaloButtonVariant.bone,
          size: HaloButtonSize.small,
        ),
      );
      expect(tester.getSize(find.byType(HaloButton)).height, 32);
    });

    testWidgets('primary is volt with carbon text', (tester) async {
      await pumpHalo(tester, HaloButton(label: 'Navigate', onPressed: () {}));
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(HaloButton),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as ShapeDecoration).color, HaloColors.volt);
      expect(
        tester.widget<Text>(find.text('Navigate')).style?.color,
        HaloColors.carbon,
      );
    });

    testWidgets('secondary has an outline and no fill', (tester) async {
      await pumpHalo(
        tester,
        HaloButton(
          label: 'Later',
          onPressed: () {},
          variant: HaloButtonVariant.secondary,
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(HaloButton),
          matching: find.byType(Container),
        ),
      );
      final deco = box.decoration! as ShapeDecoration;
      expect(deco.color, isNull);
      expect((deco.shape as NotchBorder).side.color, HaloColors.line22);
    });

    testWidgets('tap calls back; null disables', (tester) async {
      var taps = 0;
      await pumpHalo(tester, HaloButton(label: 'Go', onPressed: () => taps++));
      await tester.tap(find.text('Go'));
      expect(taps, 1);
      await pumpHalo(tester, const HaloButton(label: 'Go', onPressed: null));
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });
  });

  group('HaloSegmented', () {
    Widget seg(String value, ValueChanged<String> on) => HaloSegmented<String>(
      value: value,
      onChanged: on,
      options: const [
        HaloSegment('dark', 'Dark'),
        HaloSegment('light', 'Light'),
        HaloSegment('auto', 'Auto'),
      ],
    );

    testWidgets('is 40 high with uppercase labels', (tester) async {
      await pumpHalo(tester, seg('dark', (_) {}));
      expect(find.text('DARK'), findsOneWidget);
      expect(find.text('LIGHT'), findsOneWidget);
      final h = tester.getSize(
        find
            .ancestor(of: find.text('DARK'), matching: find.byType(Container))
            .first,
      );
      expect(h.height, 40);
    });

    testWidgets('tapping an option reports its value', (tester) async {
      String? got;
      await pumpHalo(tester, seg('dark', (v) => got = v));
      await tester.tap(find.text('LIGHT'));
      expect(got, 'light');
    });

    testWidgets('only the selected option is volt', (tester) async {
      await pumpHalo(tester, seg('auto', (_) {}));
      final fills = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration as ShapeDecoration?)?.color)
          .where((c) => c == HaloColors.volt);
      expect(fills.length, 1);
    });
  });

  group('HaloSlider', () {
    testWidgets('tap and drag set the value from position', (tester) async {
      double v = 0.46;
      await pumpHalo(
        tester,
        StatefulBuilder(
          builder: (context, set) =>
              HaloSlider(value: v, onChanged: (n) => set(() => v = n)),
        ),
      );
      final left = tester.getTopLeft(find.byType(HaloSlider)).dx;
      await tester.tapAt(Offset(left + 342 * 0.25, 12));
      expect(v, closeTo(0.25, 0.01));
      await tester.dragFrom(
        Offset(left + 342 * 0.25, 12),
        const Offset(171, 0),
      );
      expect(v, closeTo(0.75, 0.05));
    });

    testWidgets('value is clamped', (tester) async {
      double? got;
      await pumpHalo(tester, HaloSlider(value: 0.5, onChanged: (n) => got = n));
      final left = tester.getTopLeft(find.byType(HaloSlider)).dx;
      await tester.tapAt(Offset(left + 341, 12));
      expect(got, lessThanOrEqualTo(1));
    });

    testWidgets('accessibility increase and decrease', (tester) async {
      final handle = tester.ensureSemantics();
      double? got;
      await pumpHalo(
        tester,
        HaloSlider(
          value: 0.5,
          onChanged: (n) => got = n,
          semanticLabel: 'Text size',
        ),
      );
      final id = tester.getSemantics(find.byType(HaloSlider));
      expect(id.label, 'Text size');
      expect(id.value, '50%');
      tester.semantics.increase(find.semantics.byLabel('Text size'));
      expect(got, closeTo(0.55, 1e-9));
      tester.semantics.decrease(find.semantics.byLabel('Text size'));
      expect(got, closeTo(0.45, 1e-9));
      handle.dispose();
    });
  });

  group('HaloKicker', () {
    testWidgets('uppercases and draws an 8x8 volt square', (tester) async {
      await pumpHalo(tester, const HaloKicker('Now'));
      expect(find.text('NOW'), findsOneWidget);
      final square = find.descendant(
        of: find.byType(HaloKicker),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == HaloColors.volt,
        ),
      );
      expect(tester.getSize(square), const Size(8, 8));
    });

    testWidgets('plain ash variant has no square', (tester) async {
      await pumpHalo(
        tester,
        const HaloKicker('Today', color: HaloColors.ash, square: false),
      );
      expect(
        find.descendant(
          of: find.byType(HaloKicker),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });

  group('Battery', () {
    testWidgets('line is 3 high and filled to the fraction', (tester) async {
      await pumpHalo(tester, const HaloBatteryLine(fraction: 0.82));
      expect(tester.getSize(find.byType(HaloBatteryLine)).height, 3);
      final fill = find.descendant(
        of: find.byType(HaloBatteryLine),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == HaloColors.volt,
        ),
      );
      expect(tester.getSize(fill).width, closeTo(342 * 0.82, 0.01));
    });

    testWidgets('cells: 82% is 8 full, one 20% cell, one empty', (
      tester,
    ) async {
      await pumpHalo(tester, const HaloBatteryCells(fraction: 0.82));
      final cells = find.descendant(
        of: find.byType(HaloBatteryCells),
        matching: find.byType(ClipRRect),
      );
      expect(cells, findsNWidgets(10));
      final colors = tester
          .widgetList<ColoredBox>(
            find.descendant(of: cells, matching: find.byType(ColoredBox)),
          )
          .map((b) => b.color)
          .toList();
      // 8 full cells, the partial cell's fill, and 2 empty bases.
      expect(colors.where((c) => c == HaloColors.volt).length, 9);
      expect(colors.where((c) => c == HaloColors.line12).length, 2);
      final partialFill = find.descendant(
        of: cells.at(8),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == HaloColors.volt,
        ),
      );
      final cellWidth = tester.getSize(cells.at(8)).width;
      expect(tester.getSize(partialFill).width, closeTo(cellWidth * 0.2, 0.01));
      expect(tester.getSize(find.byType(HaloBatteryCells)).height, 14);
    });

    testWidgets('cells at the extremes', (tester) async {
      await pumpHalo(tester, const HaloBatteryCells(fraction: 0));
      expect(voltBoxes(tester, find.byType(HaloBatteryCells)), 0);
      await pumpHalo(tester, const HaloBatteryCells(fraction: 1));
      expect(voltBoxes(tester, find.byType(HaloBatteryCells)), 10);
    });
  });
}
