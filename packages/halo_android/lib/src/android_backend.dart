import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

/// [HaloBackend] on an Android phone, over the `halo_android` channels.
///
/// Phase 1 serves the clock, installed apps (with icons), launching, battery,
/// the default home app and Home presses. Everything else is empty until its
/// phase lands (ROADMAP): no agenda, notifications or Recents, and Switchboard
/// and System hold their values only in memory. Empty, not invented
/// (CLAUDE.md rule 1).
class AndroidBackend with WidgetsBindingObserver implements HaloBackend {
  AndroidBackend._();

  static const _methods = MethodChannel('halo_android');
  static const _events = EventChannel('halo_android/events');

  /// Icon edge in pixels: the focused arc app (68) at a 2x scale, rounded up.
  static const iconSize = 144;

  /// Loads apps, battery and the default home state before the first frame,
  /// so Home never paints an empty arc. Icons follow in the background.
  static Future<AndroidBackend> create() async {
    final b = AndroidBackend._();
    await Future.wait([b._loadApps(), b._loadBattery(), b._loadDefaultHome()]);
    b._subscription = _events.receiveBroadcastStream().listen(b._onEvent);
    WidgetsBinding.instance.addObserver(b);
    b._tickEachMinute();
    return b;
  }

  final _changes = StreamController<void>.broadcast();
  final _home = StreamController<void>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  Timer? _clock;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<void> get homePressed => _home.stream;

  void _notify() => _changes.add(null);

  void _onEvent(dynamic event) {
    switch ((event as Map)['type']) {
      case 'apps':
        unawaited(_loadApps().then((_) => _notify()));
      case 'battery':
        unawaited(_loadBattery().then((_) => _notify()));
      case 'defaultHome':
        unawaited(_loadDefaultHome().then((_) => _notify()));
      case 'home':
        _home.add(null);
    }
  }

  // The user may change the default home app in Settings while Halo is away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadDefaultHome().then((_) => _notify()));
    }
  }

  /// Rebuilds on each minute boundary so the clock stays right.
  void _tickEachMinute() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _clock = Timer(next.difference(now), () {
      _notify();
      _tickEachMinute();
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_changes.close());
    unawaited(_home.close());
  }

  @override
  DateTime get now => DateTime.now();

  // Apps

  List<HaloAppInfo> _apps = const [];
  final _icons = <String, Uint8List>{};

  @override
  List<HaloAppInfo> get apps => _apps;

  Future<void> _loadApps() async {
    final list = await _methods.invokeListMethod<Map>('apps') ?? const [];
    _apps = [
      for (final a in list)
        HaloAppInfo(
          id: a['id'] as String,
          label: a['label'] as String,
          icon: _icons[a['id']],
        ),
    ];
    final missing = [
      for (final a in _apps)
        if (!_icons.containsKey(a.id)) a.id,
    ];
    if (missing.isNotEmpty) unawaited(_loadIcons(missing));
  }

  Future<void> _loadIcons(List<String> ids) async {
    final icons = await _methods.invokeMapMethod<String, Uint8List>('icons', {
      'ids': ids,
      'size': iconSize,
    });
    if (icons == null || icons.isEmpty) return;
    _icons.addAll(icons);
    _apps = [
      for (final a in _apps)
        HaloAppInfo(id: a.id, label: a.label, icon: _icons[a.id]),
    ];
    _notify();
  }

  @override
  Future<bool> launch(String id) async =>
      await _methods.invokeMethod<bool>('launch', {'id': id}) ?? false;

  // Default home app

  bool _isDefaultHome = false;

  @override
  bool get isDefaultHome => _isDefaultHome;

  Future<void> _loadDefaultHome() async {
    _isDefaultHome =
        await _methods.invokeMethod<bool>('isDefaultHome') ?? false;
  }

  @override
  Future<void> requestDefaultHome() =>
      _methods.invokeMethod<void>('requestDefaultHome');

  // Status

  double _battery = 0;

  @override
  DeviceStatus get status => DeviceStatus(battery: _battery, network: '');

  Future<void> _loadBattery() async {
    final b = await _methods.invokeMapMethod<String, Object>('battery');
    _battery = (b?['level'] as num?)?.toDouble() ?? 0;
  }

  // Switchboard (Phase 5): held in memory, not applied to the device yet.

  QuickSettings _quick = const QuickSettings(
    brightness: 0.5,
    brightnessAuto: true,
    volume: 0.5,
    volumeFooter: 'Media',
    toggles: [],
  );

  @override
  QuickSettings get quick => _quick;

  @override
  void setToggle(String id, bool on) {}

  @override
  void setBrightness(double value) {
    _quick = _quick.copyWith(
      brightness: value.clamp(0.0, 1.0),
      brightnessAuto: false,
    );
    _notify();
  }

  @override
  void setVolume(double value) {
    _quick = _quick.copyWith(volume: value.clamp(0.0, 1.0));
    _notify();
  }

  @override
  void setPlaying(bool playing) {}

  // System: the launcher's own settings. Not persisted yet.

  SystemState _system = const SystemState(
    account: Account(name: '', initials: ''),
    appearance: Appearance.auto,
    textSize: 0.5,
    focus: 'Off',
    privacyAlerts: 0,
  );

  @override
  SystemState get system => _system;

  @override
  void setAppearance(Appearance appearance) {
    _system = _system.copyWith(appearance: appearance);
    _notify();
  }

  @override
  void setTextSize(double value) {
    _system = _system.copyWith(textSize: value.clamp(0.0, 1.0));
    _notify();
  }

  // Calendar (Phase 4)

  @override
  List<CalendarEvent> get agenda => const [];

  @override
  CalendarEvent? get nextEvent => null;

  // Recents (Phase 6)

  @override
  List<HaloAppInfo> get recents => const [];

  @override
  void closeRecent(String id) {}

  @override
  void clearRecents() {}

  // Notifications (Phase 4)

  @override
  List<HaloNotification> get notifications => const [];

  @override
  List<HaloNotification> get lockPreviews => const [];

  @override
  StreamSummary get streamSummary =>
      const StreamSummary(newCount: 0, read: 0, needYou: []);
}
