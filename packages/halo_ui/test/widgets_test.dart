import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('HaloArc', () {
    // A 1 × 1 transparent PNG.
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    List<HaloArcApp> apps(int n, {bool images = false}) => [
      for (var i = 0; i < n; i++)
        HaloArcApp(
          id: 'app$i',
          label: 'App $i',
          icon: HaloIcons.notes,
          image: images ? MemoryImage(png) : null,
        ),
    ];

    Future<void> pumpArc(
      WidgetTester tester,
      List<HaloArcApp> list, {
      int focused = 0,
      ValueChanged<int>? onFocus,
    }) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: HaloTheme.dark(),
          home: Scaffold(
            body: HaloArc(
              apps: list,
              focusedIndex: focused,
              onFocus: onFocus ?? (_) {},
              onLaunch: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('draws the app icon instead of the glyph when given one', (
      tester,
    ) async {
      await pumpArc(tester, apps(3, images: true));
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.byType(HaloIcon), findsNothing);
    });

    testWidgets('draws the glyph without an image', (tester) async {
      await pumpArc(tester, apps(3));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(HaloIcon), findsNWidgets(3));
    });

    testWidgets('apps added while shown can be reached by dragging', (
      tester,
    ) async {
      int? focused;
      await pumpArc(tester, apps(1), onFocus: (i) => focused = i);
      await pumpArc(tester, apps(10), onFocus: (i) => focused = i);
      await tester.dragFrom(const Offset(300, 780), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(focused, greaterThan(0));
    });

    testWidgets('a monochrome icon is tinted on Volt when focused', (
      tester,
    ) async {
      final list = [
        for (var i = 0; i < 3; i++)
          HaloArcApp(
            id: 'app$i',
            label: 'App $i',
            icon: HaloIcons.notes,
            image: MemoryImage(png),
            monoImage: MemoryImage(png),
          ),
      ];
      await pumpArc(tester, list, focused: 1);
      await tester.pumpAndSettle();
      final mono = tester.widgetList<Image>(find.byKey(const ValueKey('mono')));
      // Only the focused app shows the tinted mask fully.
      expect(mono.single.color, HaloColors.carbon);
      final fill = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byKey(const ValueKey('arc-app1')),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>();
      expect(fill, contains(HaloColors.volt));
    });

    testWidgets('a long press reports the app', (tester) async {
      HaloArcApp? held;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: HaloTheme.dark(),
          home: Scaffold(
            body: HaloArc(
              apps: apps(3),
              focusedIndex: 1,
              onFocus: (_) {},
              onLaunch: (_) {},
              onLongPress: (a) => held = a,
            ),
          ),
        ),
      );
      await tester.longPress(find.byKey(const ValueKey('arc-app2')));
      expect(held?.id, 'app2');
    });

    testWidgets('survives the list shrinking under the focus', (tester) async {
      await pumpArc(tester, apps(10), focused: 9);
      await pumpArc(tester, apps(2), focused: 1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('APP 1'), findsOneWidget);
    });
  });

  group('HaloCommandField', () {
    testWidgets('without a controller it only reports taps', (tester) async {
      var taps = 0;
      await pumpHalo(tester, HaloCommandField(onTap: () => taps++));
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.byType(HaloCommandField));
      expect(taps, 1);
    });

    testWidgets('with a controller it takes text and hides the placeholder', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      final typed = <String>[];
      String? submitted;
      await pumpHalo(
        tester,
        HaloCommandField(
          placeholder: 'find an app',
          controller: c,
          onChanged: typed.add,
          onSubmitted: (v) => submitted = v,
        ),
      );
      expect(find.text('find an app'), findsOneWidget);
      await tester.tap(find.byType(HaloCommandField));
      await tester.enterText(find.byType(EditableText), 'map');
      await tester.pump();
      expect(c.text, 'map');
      expect(typed.last, 'map');
      expect(find.text('find an app'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      expect(submitted, 'map');
    });
  });

  group('HaloAppRow', () {
    testWidgets('shows the name, tags and reports taps and long presses', (
      tester,
    ) async {
      var taps = 0, holds = 0;
      await pumpHalo(
        tester,
        HaloAppRow(
          label: 'Slack',
          icon: HaloIcons.notes,
          work: true,
          onArc: true,
          onTap: () => taps++,
          onLongPress: () => holds++,
        ),
      );
      expect(find.text('Slack'), findsOneWidget);
      expect(find.text('WORK'), findsOneWidget);
      final onArc = tester.widget<Text>(find.text('ON ARC'));
      expect(onArc.style!.color, HaloColors.volt);
      await tester.tap(find.byType(HaloAppRow));
      await tester.longPress(find.byType(HaloAppRow));
      expect((taps, holds), (1, 1));
      expect(tester.getSize(find.byType(HaloAppRow)).height, HaloAppRow.height);
    });

    testWidgets('no tags by default', (tester) async {
      await pumpHalo(
        tester,
        const HaloAppRow(label: 'Maps', icon: HaloIcons.maps),
      );
      expect(find.text('WORK'), findsNothing);
      expect(find.text('ON ARC'), findsNothing);
    });
  });

  group('HaloLetterIndex', () {
    testWidgets('marks the current letter Volt and picks by tap', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpHalo(
        tester,
        SizedBox(
          height: 300,
          child: Align(
            alignment: Alignment.topLeft,
            child: HaloLetterIndex(
              letters: const ['A', 'B', 'C'],
              current: 'B',
              onLetter: picked.add,
            ),
          ),
        ),
      );
      final b = tester.widget<Text>(find.byKey(const ValueKey('index-B')));
      expect(b.style!.color, HaloColors.volt);
      await tester.tap(find.byKey(const ValueKey('index-C')));
      expect(picked.last, 'C');
    });
  });

  group('HaloMenu', () {
    testWidgets('lists sections, skips empty ones, runs the choice', (
      tester,
    ) async {
      var opened = 0;
      await pumpHalo(
        tester,
        HaloMenu(
          title: 'Messages',
          tag: 'Work',
          sections: [
            HaloMenuSection(
              label: 'Shortcuts',
              items: [HaloMenuItem('New message', onPressed: () => opened++)],
            ),
            const HaloMenuSection(label: 'Empty', items: []),
            const HaloMenuSection(
              label: 'App',
              items: [HaloMenuItem('Uninstall', onPressed: null)],
            ),
          ],
        ),
      );
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('WORK'), findsOneWidget);
      expect(find.text('SHORTCUTS'), findsOneWidget);
      expect(find.text('EMPTY'), findsNothing);
      await tester.tap(find.text('New message'));
      expect(opened, 1);
      // Disabled rows are muted.
      final un = tester.widget<Text>(find.text('Uninstall'));
      expect(un.style!.color, isNot(HaloColors.bone));
    });
  });

  group('HaloResultRow', () {
    testWidgets('a contact: initials in a notch, never a circle', (
      tester,
    ) async {
      var taps = 0;
      await pumpHalo(
        tester,
        HaloResultRow(
          title: 'Mira Okafor',
          initials: 'MO',
          onTap: () => taps++,
        ),
      );
      expect(find.text('MO'), findsOneWidget);
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('MO'), matching: find.byType(Container))
            .first,
      );
      expect(box.decoration, isA<ShapeDecoration>());
      expect((box.decoration! as ShapeDecoration).shape, isA<NotchBorder>());
      await tester.tap(find.byType(HaloResultRow));
      expect(taps, 1);
    });

    testWidgets('a caption is ash, or Volt for the primary action', (
      tester,
    ) async {
      await pumpHalo(
        tester,
        const Column(
          children: [
            HaloResultRow(title: 'Battery', caption: 'Settings'),
            HaloResultRow(
              title: 'Search your contacts too',
              caption: 'Allow',
              captionSignal: true,
            ),
          ],
        ),
      );
      expect(
        tester.widget<Text>(find.text('SETTINGS')).style!.color,
        HaloColors.ash,
      );
      expect(
        tester.widget<Text>(find.text('ALLOW')).style!.color,
        HaloColors.volt,
      );
    });
  });

  testWidgets('HaloAppRow tags private space apps', (tester) async {
    await pumpHalo(
      tester,
      const HaloAppRow(
        label: 'Bank',
        icon: HaloIcons.notes,
        privateSpace: true,
      ),
    );
    expect(find.text('PRIVATE'), findsOneWidget);
  });
}
