import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_launcher/apps/apps_screen.dart';
import 'package:halo_launcher/home/home_screen.dart';
import 'package:halo_launcher/lock/lock_screen.dart';
import 'package:halo_launcher/recents/recents_screen.dart';
import 'package:halo_launcher/stream/stream_screen.dart';
import 'package:halo_launcher/switchboard/switchboard_screen.dart';
import 'package:halo_launcher/system/system_screen.dart';
import 'package:halo_launcher/text_scale.dart';
import 'package:halo_launcher/welcome/welcome_screen.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'support/fonts.dart';

/// Every screen, for the accessibility checks below.
final _screens = <String, Widget Function(MockBackend)>{
  'lock': (b) => LockScreen(backend: b, onUnlock: () {}),
  'home': (b) => HomeScreen(backend: b, onLaunch: (_) {}),
  'apps': (b) => AppsScreen(backend: b, onLaunch: (_) {}, onLongPress: (_) {}),
  'switchboard': (b) => SwitchboardScreen(backend: b),
  'recents': (b) => RecentsScreen(backend: b),
  'stream': (b) => StreamScreen(backend: b),
  'system': (b) => SystemScreen(backend: b, initiallyOpen: 'display'),
  'welcome': (b) => WelcomeScreen(backend: b, onDone: () {}),
};

/// Tappable nodes are at least 48 dp each way. The one exception is a tall
/// narrow strip (a Recents slat: 36 wide by about 600 high, the design's
/// own measure, 6 apart): its other side is far over 48, so it is easy to hit.
class _TapTargets extends AccessibilityGuideline {
  const _TapTargets();

  @override
  String get description => 'Tap targets are at least 48 × 48 dp';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    final dpr = tester.view.devicePixelRatio;
    var result = const Evaluation.pass();
    void visit(SemanticsNode node, Matrix4 parent) {
      final transform = node.transform == null
          ? parent
          : (parent.clone()..multiply(node.transform!));
      final data = node.getSemanticsData();
      final tappable =
          data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      final hidden = data.flagsCollection.isHidden || node.isInvisible;
      if (tappable && !hidden) {
        final size = MatrixUtils.transformRect(transform, node.rect).size / dpr;
        final long = size.longestSide, short = size.shortestSide;
        final strip = long >= 200 && short >= 36;
        // A row cut off by a scroll viewport is only partly in view.
        final inParent = node.transform == null
            ? node.rect
            : MatrixUtils.transformRect(node.transform!, node.rect);
        final cut = [node.parentSemanticsClipRect, node.parentPaintClipRect]
            .whereType<Rect>()
            .any(
              (clip) =>
                  inParent.top <= clip.top + 0.5 ||
                  inParent.bottom >= clip.bottom - 0.5,
            );
        if (short < 48 && !strip && !cut) {
          result += Evaluation.fail(
            '${node.label.isEmpty ? node.identifier : node.label}: '
            '${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)}',
          );
        }
      }
      node.visitChildren((child) {
        visit(child, transform);
        return true;
      });
    }

    visit(
      RendererBinding
          .instance
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
      Matrix4.identity(),
    );
    return result;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadHaloFonts();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool light = false,
    double textScale = 1,
  }) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? HaloTheme.light() : HaloTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: HaloTextScaler(textScale)),
          child: child!,
        ),
        home: Scaffold(body: screen),
      ),
    );
  }

  for (final light in [false, true]) {
    final look = light ? 'light' : 'dark';
    for (final MapEntry(key: name, value: build) in _screens.entries) {
      group('$name ($look)', () {
        testWidgets('tap targets are at least 48 dp', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, build(MockBackend(welcomed: false)), light: light);
          await expectLater(tester, meetsGuideline(const _TapTargets()));
          handle.dispose();
        });

        testWidgets('every tap target has a label', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, build(MockBackend(welcomed: false)), light: light);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });
      });
    }
  }

  // Each screen at the smallest size, and at the most it holds (D-036).
  for (final MapEntry(key: name, value: build) in _screens.entries) {
    for (final scale in [0.75, haloTextScaleCaps[name]!]) {
      testWidgets('$name lays out at text scale $scale', (tester) async {
        await pump(
          tester,
          build(MockBackend(welcomed: false)),
          textScale: scale,
        );
        await tester.pump();
        // An overflow is reported as an exception, whose details name the
        // widget.
        final error = tester.takeException();
        if (error != null) {
          fail(
            error is FlutterError
                ? error.diagnostics.map((d) => d.toDescription()).join('\n')
                : '$error',
          );
        }
      });
    }
  }
}
