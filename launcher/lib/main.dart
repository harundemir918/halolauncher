import 'package:flutter/material.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'backend_builder.dart';
import 'dev/bench_screen.dart';
import 'gestures.dart';
import 'home/home_screen.dart';
import 'lock/lock_screen.dart';
import 'recents/recents_screen.dart';
import 'stream/stream_screen.dart';
import 'switchboard/switchboard_screen.dart';
import 'system/system_screen.dart';

/// Only the mock backend exists so far (`--dart-define=HALO_BACKEND=mock`).
const _backendName = String.fromEnvironment(
  'HALO_BACKEND',
  defaultValue: 'mock',
);

/// Dev only: open on a screen other than Lock (`--dart-define=HALO_START=home`).
const _start = String.fromEnvironment('HALO_START', defaultValue: 'lock');

HaloBackend createBackend() => switch (_backendName) {
  'mock' => MockBackend(),
  final other => throw StateError('Unknown HALO_BACKEND "$other"'),
};

void main() => runApp(HaloShell(backend: createBackend(), start: _start));

class HaloShell extends StatefulWidget {
  const HaloShell({super.key, required this.backend, this.start = 'lock'});

  final HaloBackend backend;
  final String start;

  @override
  State<HaloShell> createState() => _HaloShellState();
}

class _HaloShellState extends State<HaloShell> {
  late String _screen = widget.start;

  void _onSwipe(EdgeZone zone) => setState(() {
    _screen = switch (zone) {
      EdgeZone.topRight => 'switchboard',
      EdgeZone.topLeft => 'stream',
      // Up from the bottom: Home, and from Home, Recents.
      EdgeZone.bottom => _screen == 'home' ? 'recents' : 'home',
    };
  });

  @override
  Widget build(BuildContext context) {
    final screen = switch (_screen) {
      'lock' => LockScreen(
        backend: widget.backend,
        onUnlock: () => setState(() => _screen = 'home'),
      ),
      'home' => HomeScreen(
        backend: widget.backend,
        onLaunch: (id) => setState(() => _screen = 'app:$id'),
      ),
      'switchboard' => SwitchboardScreen(backend: widget.backend),
      'recents' => RecentsScreen(backend: widget.backend),
      'stream' => StreamScreen(backend: widget.backend),
      'system' => SystemScreen(backend: widget.backend),
      'bench' => BenchScreen(backend: widget.backend),
      final app => _Placeholder(
        title: app,
        onBack: () => setState(() => _screen = 'home'),
      ),
    };
    return BackendBuilder(
      backend: widget.backend,
      builder: (context, b) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: HaloTheme.light(),
        darkTheme: HaloTheme.dark(),
        // Auto follows the platform until D-013 decides what it follows.
        themeMode: switch (b.system.appearance) {
          Appearance.dark => ThemeMode.dark,
          Appearance.light => ThemeMode.light,
          Appearance.auto => ThemeMode.system,
        },
        home: Scaffold(
          // Lock only opens with the hold ring, so it has no edge swipes.
          body: _screen == 'lock'
              ? screen
              : EdgeSwipes(onSwipe: _onSwipe, child: screen),
        ),
      ),
    );
  }
}

/// Stand-in for screens and apps that are not built yet.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HaloKicker(title.replaceFirst('app:', '')),
        const SizedBox(height: HaloSpace.g18),
        HaloButton(
          label: 'Home',
          variant: HaloButtonVariant.secondary,
          onPressed: onBack,
        ),
      ],
    ),
  );
}
