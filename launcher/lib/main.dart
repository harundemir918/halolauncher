import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_android/halo_android.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'backend_builder.dart';
import 'app_menu.dart';
import 'apps/apps_screen.dart';
import 'design_frame.dart';
import 'dev/bench_screen.dart';
import 'gestures.dart';
import 'home/home_screen.dart';
import 'lock/lock_screen.dart';
import 'recents/recents_screen.dart';
import 'stream/stream_screen.dart';
import 'switchboard/switchboard_screen.dart';
import 'system/system_screen.dart';

/// `mock` or `android`. Defaults to `android` on Android and `mock` elsewhere
/// (`--dart-define=HALO_BACKEND=mock`).
const _backendName = String.fromEnvironment('HALO_BACKEND');

/// Dev only: open on another screen (`--dart-define=HALO_START=home`). The
/// default is Lock with the mock, which follows the designs, and Home on
/// Android, where a launcher can't be the lock screen (D-021).
const _start = String.fromEnvironment('HALO_START');

Future<HaloBackend> createBackend() async {
  final name = _backendName.isNotEmpty
      ? _backendName
      : defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'mock';
  return switch (name) {
    'mock' => MockBackend(),
    'android' => await AndroidBackend.create(),
    final other => throw StateError('Unknown HALO_BACKEND "$other"'),
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await createBackend();
  if (backend is AndroidBackend) {
    // Draw behind transparent system bars (D-024).
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(
    HaloLauncher(
      backend: backend,
      start: _start.isNotEmpty
          ? _start
          : backend is AndroidBackend
          ? 'home'
          : 'lock',
    ),
  );
}

class HaloLauncher extends StatefulWidget {
  const HaloLauncher({super.key, required this.backend, this.start = 'lock'});

  final HaloBackend backend;
  final String start;

  @override
  State<HaloLauncher> createState() => _HaloLauncherState();
}

class _HaloLauncherState extends State<HaloLauncher> {
  late String _screen = widget.start;
  late final StreamSubscription<void> _home;

  @override
  void initState() {
    super.initState();
    _home = widget.backend.homePressed.listen((_) => _goHome());
  }

  @override
  void dispose() {
    unawaited(_home.cancel());
    super.dispose();
  }

  /// The app whose long-press menu is open.
  HaloAppInfo? _menu;

  void _openMenu(HaloAppInfo app) => setState(() => _menu = app);

  void _closeMenu() => setState(() => _menu = null);

  void _goHome() {
    if (_screen != 'home' || _menu != null) {
      setState(() {
        _screen = 'home';
        _menu = null;
      });
    }
  }

  /// Back closes the menu first, then returns to Home.
  void _back() => _menu != null ? _closeMenu() : _goHome();

  /// Starts the app, or shows a stand-in when the backend can't (the mock).
  Future<void> _launch(String id) async {
    if (!await widget.backend.launch(id) && mounted) {
      setState(() => _screen = 'app:$id');
    }
  }

  void _onSwipe(EdgeZone zone) => setState(() {
    _screen = switch (zone) {
      EdgeZone.topRight => 'switchboard',
      EdgeZone.topLeft => 'stream',
      // Up from the bottom: Home, and from Home, Recents.
      EdgeZone.bottom => _screen == 'home' ? 'recents' : 'home',
      EdgeZone.lowerArea => 'apps',
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
        onLaunch: _launch,
        onLongPress: _openMenu,
      ),
      'apps' => AppsScreen(
        backend: widget.backend,
        onLaunch: _launch,
        onLongPress: _openMenu,
      ),
      'switchboard' => SwitchboardScreen(backend: widget.backend),
      'recents' => RecentsScreen(backend: widget.backend),
      'stream' => StreamScreen(backend: widget.backend),
      'system' => SystemScreen(backend: widget.backend),
      'bench' => BenchScreen(backend: widget.backend),
      final app => _Placeholder(title: app, onBack: _goHome),
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
        home: Builder(
          builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: _barsFor(Theme.of(context).brightness),
            // Back never leaves the launcher; it returns to Home.
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) => _back(),
              child: Scaffold(
                backgroundColor: context.halo.ground,
                // The keyboard shortens the design frame instead (DesignFrame).
                resizeToAvoidBottomInset: false,
                body: DesignFrame(
                  child: Stack(
                    children: [
                      // Lock only opens with the hold ring, so it has no edge
                      // swipes. On Home, an up swipe on the arc opens Apps.
                      if (_screen == 'lock')
                        screen
                      else
                        EdgeSwipes(
                          onSwipe: _onSwipe,
                          lowerArea: _screen == 'home' ? HaloArc.dragZone : 0,
                          child: screen,
                        ),
                      if (_menu case final app?)
                        AppMenuLayer(
                          key: ValueKey('menu-${app.id}'),
                          backend: widget.backend,
                          app: app,
                          onClose: _closeMenu,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

/// Transparent system bars with icons that read on the Halo ground.
SystemUiOverlayStyle _barsFor(Brightness brightness) {
  final icons = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    systemNavigationBarColor: const Color(0x00000000),
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: icons,
    statusBarBrightness: brightness,
    systemNavigationBarIconBrightness: icons,
  );
}
