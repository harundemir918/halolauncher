import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

import 'backend_builder.dart';

/// Text sizes as a launcher with a fixed layout can honor them (D-036).
///
/// Body text follows the scale fully. The bigger the type, the less it grows,
/// and display type (36 and up: the clock, titles, the NOW headline) doesn't
/// grow at all, since it is already large. That is how Android's own
/// nonlinear font scaling works too, and it keeps the design's layout intact.
class HaloTextScaler extends TextScaler {
  const HaloTextScaler(this.factor);

  /// How much body text grows: 1 is as designed.
  final double factor;

  static const double _fullUpTo = 20;
  static const double _noneFrom = 36;

  @override
  double scale(double fontSize) {
    if (fontSize >= _noneFrom) return fontSize;
    if (fontSize <= _fullUpTo) return fontSize * factor;
    final grows = (_noneFrom - fontSize) / (_noneFrom - _fullUpTo);
    return fontSize * (1 + (factor - 1) * grows);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => HaloTextScaler(factor.clamp(minScaleFactor, maxScaleFactor));

  @override
  bool operator ==(Object other) =>
      other is HaloTextScaler && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
}

/// The most each screen's layout holds. Screens that scroll can take a lot;
/// the ones laid out edge to edge (Home, Lock, Switchboard, Recents) take a
/// little. Beyond it the text stops growing; the System text size and
/// Android's font size both count, up to here.
const haloTextScaleCaps = {
  'home': 1.15,
  'lock': 1.15,
  'switchboard': 1.15,
  'recents': 1.15,
  'apps': 1.5,
  'stream': 1.5,
  'system': 1.5,
  'welcome': 1.5,
};

/// What System's text size (12 to 20 px) times Android's font size makes, kept
/// between 0.75 and the screen's [max].
double effectiveTextScale({
  required HaloBackend backend,
  required double system,
  required double max,
}) {
  final chosen = backend.system.textSizePx / 16;
  return (chosen * system).clamp(0.75, math.max(0.75, max));
}

/// Gives [child] the text scale it can hold: System's text size and Android's
/// font size together, up to [max] (see [haloTextScaleCaps]).
class HaloTextScale extends StatelessWidget {
  const HaloTextScale({
    super.key,
    required this.backend,
    required this.max,
    required this.child,
  });

  final HaloBackend backend;
  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Android's font size, as the factor for body text.
    final system = mq.textScaler.scale(16) / 16;
    return BackendBuilder(
      backend: backend,
      builder: (context, b) => MediaQuery(
        data: mq.copyWith(
          textScaler: HaloTextScaler(
            effectiveTextScale(backend: b, system: system, max: max),
          ),
        ),
        child: child,
      ),
    );
  }
}
