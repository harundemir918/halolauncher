import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

import '../home/home_screen.dart';

/// Dev only (`--dart-define=HALO_START=bench`): the real Home screen sliding
/// side to side forever. Every frame repaints the whole screen, like a screen
/// transition, so the frame rate shows rendering cost without any input.
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

  @override
  void dispose() {
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
