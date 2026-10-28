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
import 'shell_nav.dart';
import 'home/home_screen.dart';
import 'lock/lock_screen.dart';
import 'recents/recents_screen.dart';
import 'stream/stream_screen.dart';
import 'switchboard/switchboard_screen.dart';
import 'text_scale.dart';
import 'welcome/welcome_screen.dart';
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
          ? (backend.welcomed ? 'home' : 'welcome')
          : 'lock',
      bottomEdgeOpensApps: backend is AndroidBackend,
      glancePage: backend is AndroidBackend,
    ),
  );
}

class HaloLauncher extends StatefulWidget {
  const HaloLauncher({
    super.key,
    required this.backend,
    this.start = 'lock',
    this.bottomEdgeOpensApps = false,
    this.glancePage = false,
  });

  final HaloBackend backend;
  final String start;

  /// On a phone, an up swipe from just above the system's gesture bar opens
  /// Apps from Home, and Recents from Apps: that is where a thumb starts
  /// (D-023, D-026).
  final bool bottomEdgeOpensApps;

  /// Lock is the glance page left of Home: a swipe right on Home opens it, a
  /// swipe left (or the ring, or back) returns (D-021).
  final bool glancePage;

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

  /// Apps was opened from Ask Halo, so its search starts focused.
  bool _ask = false;

  /// Apps is picking an app for the start (true) or the end (false) of the
  /// arc, from a plus slot on Home. Null for the usual Apps list.
  bool? _addToArc;

  /// The app Home's arc starts on: the one just added.
  String? _focusOnHome;

  void _openPicker(bool atStart) => setState(() {
    _screen = 'apps';
    _addToArc = atStart;
    _ask = false;
    _menu = null;
  });

  void _pick(String id) {
    widget.backend.pinToArc(id, atStart: _addToArc ?? false);
    setState(() {
      _focusOnHome = id;
      _addToArc = null;
      _screen = 'home';
    });
  }

  /// A notification whose reply field Stream opens with (Home's card).
  String? _replyTo;

  void _replyIn(String id) => setState(() {
    _screen = 'stream';
    _replyTo = id;
  });

  // The screen shown at the last build, to notice leaving Stream.
  late String _shownBefore = widget.start;

  void _openSearch() => setState(() {
    _screen = 'apps';
    _ask = true;
  });

  void _openMenu(HaloAppInfo app) => setState(() => _menu = app);

  void _closeMenu() => setState(() => _menu = null);

  void _goHome() {
    if (_screen != 'home' || _menu != null) {
      setState(() {
        _screen = 'home';
        _menu = null;
        _ask = false;
        _addToArc = null;
      });
    }
  }

  /// Opens a screen from inside one (the status row's Stream / Switchboard).
  void _open(String screen) => setState(() {
    _screen = screen;
    _menu = null;
    _ask = false;
    _addToArc = null;
  });

  /// Back closes the menu first, then returns to Home.
  void _back() => _menu != null ? _closeMenu() : _goHome();

  /// Starts the app, or shows a stand-in when the backend can't (the mock).
  Future<void> _launch(String id) async {
    if (!await widget.backend.launch(id) && mounted) {
      setState(() => _screen = 'app:$id');
    }
  }

  /// The user's camera app, for the glance page's shortcut.
  HaloAppInfo? get _cameraApp =>
      widget.backend.apps.where((a) => a.glyph == 'camera').firstOrNull;

  void _onGlanceSwipe(bool right) => setState(() {
    if (_screen == 'home' && right) {
      _screen = 'lock';
      _menu = null;
      _ask = false;
    } else if (_screen == 'lock' && !right) {
      _screen = 'home';
    }
  });

  void _onSwipe(EdgeZone zone) => setState(() {
    _ask = false;
    _addToArc = null;
    _screen = switch (zone) {
      EdgeZone.topRight => 'switchboard',
      EdgeZone.topLeft => 'stream',
      // Up from the bottom: Home, and from Home, Recents.
      // On Android the bottom edge climbs: Home, Apps, Recents (D-023).
      EdgeZone.bottom => switch (_screen) {
        'home' => widget.bottomEdgeOpensApps ? 'apps' : 'recents',
        'apps' when widget.bottomEdgeOpensApps => 'recents',
        _ => 'home',
      },
      EdgeZone.lowerArea => 'apps',
    };
  });

  @override
  Widget build(BuildContext context) {
    // Leaving Stream: what was there counts as seen (NOW moves to EARLIER).
    if (_shownBefore == 'stream' && _screen != 'stream') {
      _replyTo = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.backend.markNotificationsSeen(),
      );
    }
    _shownBefore = _screen;
    // Home takes the app to start on once, when it is built.
    if (_focusOnHome != null && _screen == 'home') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusOnHome = null);
    }
    final shown = switch (_screen) {
      'lock' => LockScreen(
        backend: widget.backend,
        onUnlock: () => setState(() => _screen = 'home'),
        glance: widget.glancePage,
        onCamera: _cameraApp == null ? null : () => _launch(_cameraApp!.id),
      ),
      'home' => HomeScreen(
        backend: widget.backend,
        onLaunch: _launch,
        onLongPress: _openMenu,
        onAsk: _openSearch,
        onReply: _replyIn,
        onAddToArc: _openPicker,
        focusAppId: _focusOnHome,
      ),
      'apps' => AppsScreen(
        backend: widget.backend,
        onLaunch: _launch,
        onLongPress: _openMenu,
        autofocusSearch: _ask,
        addToArc: _addToArc,
        onPick: _pick,
      ),
      'switchboard' => SwitchboardScreen(backend: widget.backend),
      'recents' => RecentsScreen(backend: widget.backend, onLaunch: _launch),
      'stream' => StreamScreen(
        key: ValueKey('stream-$_replyTo'),
        backend: widget.backend,
        replyTo: _replyTo,
      ),
      'system' => SystemScreen(backend: widget.backend),
      'welcome' => WelcomeScreen(
        backend: widget.backend,
        onDone: () {
          widget.backend.markWelcomed();
          setState(() => _screen = 'home');
        },
      ),
      'bench' => BenchScreen(backend: widget.backend),
      final app => _Placeholder(title: app, onBack: _goHome),
    };
    // System's text size and Android's font size, up to what the screen holds.
    final screen = HaloTextScale(
      backend: widget.backend,
      max: haloTextScaleCaps[_screen] ?? 1.15,
      child: shown,
    );
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
                  child: ShellNav(
                    current: _screen,
                    open: _open,
                    child: Stack(
                      children: [
                        // Lock only opens with the hold ring, so it has no edge
                        // swipes. On Home, an up swipe on the arc opens Apps.
                        if (_screen == 'lock')
                          widget.glancePage
                              ? GlanceSwipe(
                                  onSwipe: _onGlanceSwipe,
                                  child: screen,
                                )
                              : screen
                        else if (_screen == 'home' && widget.glancePage)
                          GlanceSwipe(
                            onSwipe: _onGlanceSwipe,
                            child: EdgeSwipes(
                              onSwipe: _onSwipe,
                              lowerArea: HaloArc.dragZone,
                              child: screen,
                            ),
                          )
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
