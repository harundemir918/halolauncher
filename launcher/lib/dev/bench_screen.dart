import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

import '../home/home_screen.dart';

/// Dev only (`--dart-define=HALO_START=bench`): the real Home screen sliding
/// side to side forever. Every frame repaints the whole screen, like a screen
/// transition, so the frame rate shows rendering cost without any input.
/// Every 300 frames it prints the build and raster times (`HALO_BENCH` in
/// logcat): run it as a release build, since debug and profile are slower.
class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key, required this.backend});

  final HaloBackend backend;

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  final _build = <double>[];
  final _raster = <double>[];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _build.add(t.buildDuration.inMicroseconds / 1000);
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
    if (_build.length < 300) return;
    String stats(List<double> v) {
      final s = [...v]..sort();
      double at(double q) => s[((s.length - 1) * q).round()];
      return 'p50 ${at(.5).toStringAsFixed(1)} '
          'p90 ${at(.9).toStringAsFixed(1)} '
          'p99 ${at(.99).toStringAsFixed(1)} '
          'max ${s.last.toStringAsFixed(1)}';
    }

    // ignore: avoid_print
    print(
      'HALO_BENCH frames ${_build.length} | build ms ${stats(_build)} '
      '| raster ms ${stats(_raster)}',
    );
    _build.clear();
    _raster.clear();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(40 * math.sin(_c.value * 2 * math.pi), 0),
        child: child,
      ),
      child: HomeScreen(backend: widget.backend, onLaunch: (_) {}),
    );
  }
}
