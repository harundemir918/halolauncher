import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

/// [HaloBackend] on an Android phone, over the `halo_android` channels.
///
/// Serves the clock, installed apps in every profile (with icons), the arc
/// the user keeps, launching, shortcuts, App info and uninstall, battery, the
/// default home app and Home presses. The arc, appearance and text size are
/// saved on the phone. Everything else is empty until its phase lands
/// (ROADMAP): no agenda, notifications or Recents, and Switchboard holds its
/// values only in memory. Empty, not invented (CLAUDE.md rule 1).
class AndroidBackend with WidgetsBindingObserver implements HaloBackend {
  AndroidBackend._();

  static const _methods = MethodChannel('halo_android');
  static const _events = EventChannel('halo_android/events');

  /// Icon edge in pixels: the focused arc app (68) at a 2x scale, rounded up.
  static const iconSize = 144;

  /// How many apps fill the arc the first time when no default apps resolve.
  static const firstArcSize = 7;

  /// Loads apps, the arc, settings, battery and the default home state before
  /// the first frame, so Home never paints an empty arc. Icons follow.
  static Future<AndroidBackend> create() async {
    final b = AndroidBackend._();
    await Future.wait([
      b._loadApps(),
      b._loadBattery(),
      b._loadDefaultHome(),
      b._loadSettings(),
      b._loadPrivateSpace(),
      b._loadContactsAccess(),
    ]);
    await b._loadArc();
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
        unawaited(
          Future.wait([_loadApps(), _loadPrivateSpace()])
              .then((_) => _notify()),
        );
      case 'battery':
        unawaited(_loadBattery().then((_) => _notify()));
      case 'defaultHome':
        unawaited(_loadDefaultHome().then((_) => _notify()));
      case 'contacts':
        unawaited(_loadContactsAccess().then((_) => _notify()));
      case 'home':
        _home.add(null);
    }
  }

  // The user may change the default home app or Halo's permissions in
  // Settings while Halo is away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        Future.wait([_loadDefaultHome(), _loadContactsAccess()])
            .then((_) => _notify()),
      );
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
  final _monos = <String, Uint8List>{};

  @override
  List<HaloAppInfo> get apps => _apps;

  Future<void> _loadApps() async {
    // Roles first: each app's glyph comes from them.
    await _loadRoles();
    final list = await _methods.invokeListMethod<Map>('apps') ?? const [];
    _apps = [
      for (final a in list)
        HaloAppInfo(
          id: a['id'] as String,
          label: a['label'] as String,
          icon: _icons[a['id']],
          monoIcon: _monos[a['id']],
          glyph: _glyphOf(a['id'] as String),
          work: a['work'] as bool? ?? false,
          privateSpace: a['privateSpace'] as bool? ?? false,
          canUninstall: a['canUninstall'] as bool? ?? true,
        ),
    ];
    final missing = [
      for (final a in _apps)
        if (!_icons.containsKey(a.id)) a.id,
    ];
    if (missing.isNotEmpty) unawaited(_loadIcons(missing));
  }

  // Role to app id for the user's default apps (D-025): those apps are drawn
  // with the design's glyphs.
  Map<String, String> _roles = const {};

  String? _glyphOf(String id) {
    for (final MapEntry(key: role, value: app) in _roles.entries) {
      if (app == id) return role;
    }
    return null;
  }

  Future<void> _loadRoles() async {
    _roles =
        await _methods.invokeMapMethod<String, String>('roles') ?? const {};
  }

  Future<void> _loadIcons(List<String> ids) async {
    final icons = await _methods.invokeMapMethod<String, Map>('icons', {
      'ids': ids,
      'size': iconSize,
    });
    if (icons == null || icons.isEmpty) return;
    for (final MapEntry(key: id, value: i) in icons.entries) {
      if (i['icon'] case final Uint8List icon) _icons[id] = icon;
      if (i['mono'] case final Uint8List mono) _monos[id] = mono;
    }
    _apps = [for (final a in _apps) a.withIcons(_icons[a.id], _monos[a.id])];
    _notify();
  }

  @override
  Future<bool> launch(String id) async =>
      await _methods.invokeMethod<bool>('launch', {'id': id}) ?? false;

  // The arc: ids in order, saved as JSON under `arc`. Ids of apps that are
  // gone stay saved (an app being updated disappears for a moment) but are
  // not shown.

  List<String> _arc = [];

  @override
  List<HaloAppInfo> get arcApps {
    final byId = {for (final a in _apps) a.id: a};
    return [for (final id in _arc) ?byId[id]];
  }

  Future<void> _loadArc() async {
    final saved = await _methods.invokeMethod<String>('getPref', {
      'key': 'arc',
    });
    if (saved != null) {
      _arc = (jsonDecode(saved) as List).cast<String>();
      return;
    }
    final defaults =
        await _methods.invokeListMethod<String>('defaultApps') ?? const [];
    _arc = defaults.isNotEmpty
        ? [...defaults]
        : [for (final a in _apps.take(firstArcSize)) a.id];
    await _saveArc();
  }

  Future<void> _saveArc() => _methods.invokeMethod<void>('setPref', {
    'key': 'arc',
    'value': jsonEncode(_arc),
  });

  void _arcChanged() {
    unawaited(_saveArc());
    _notify();
  }

  @override
  void pinToArc(String id) {
    if (_arc.contains(id) || !_apps.any((a) => a.id == id)) return;
    _arc.add(id);
    _arcChanged();
  }

  @override
  void unpinFromArc(String id) {
    if (_arc.remove(id)) _arcChanged();
  }

  @override
  void moveOnArc(String id, int by) {
    // Move among the shown apps, so hidden (missing) ids don't eat a step.
    final shown = arcApps.map((a) => a.id).toList();
    final from = shown.indexOf(id);
    if (from < 0) return;
    final to = (from + by).clamp(0, shown.length - 1);
    if (to == from) return;
    shown
      ..removeAt(from)
      ..insert(to, id);
    final hidden = _arc.where((x) => !shown.contains(x));
    _arc = [...shown, ...hidden];
    _arcChanged();
  }

  // Long-press actions

  @override
  Future<List<AppShortcut>> shortcuts(String appId) async {
    final list =
        await _methods.invokeListMethod<Map>('shortcuts', {'id': appId}) ??
        const [];
    return [
      for (final s in list)
        AppShortcut(id: s['id'] as String, label: s['label'] as String),
    ];
  }

  @override
  Future<bool> startShortcut(String appId, String shortcutId) async =>
      await _methods.invokeMethod<bool>('startShortcut', {
        'id': appId,
        'shortcut': shortcutId,
      }) ??
      false;

  @override
  Future<void> openAppInfo(String appId) =>
      _methods.invokeMethod<void>('appInfo', {'id': appId});

  @override
  Future<void> uninstall(String appId) =>
      _methods.invokeMethod<void>('uninstall', {'id': appId});

  // Search sources

  @override
  List<SettingsPage> get settingsPages => defaultSettingsPages;

  @override
  Future<void> openSettingsPage(String id) =>
      _methods.invokeMethod<void>('openSettings', {'id': id});

  bool _canSearchContacts = false;

  @override
  bool get canSearchContacts => _canSearchContacts;

  Future<void> _loadContactsAccess() async {
    _canSearchContacts =
        await _methods.invokeMethod<bool>('canSearchContacts') ?? false;
  }

  @override
  Future<void> requestContactsAccess() =>
      _methods.invokeMethod<void>('requestContacts');

  @override
  Future<List<ContactResult>> searchContacts(String query) async {
    if (!_canSearchContacts || query.trim().isEmpty) return const [];
    final list =
        await _methods.invokeListMethod<Map>('searchContacts', {
          'query': query,
        }) ??
        const [];
    return [
      for (final c in list)
        ContactResult(id: c['id'] as String, name: c['name'] as String),
    ];
  }

  @override
  Future<void> openContact(String id) =>
      _methods.invokeMethod<void>('openContact', {'id': id});

  // Private space (Android 15+)

  PrivateSpaceState _privateSpace = PrivateSpaceState.none;

  @override
  PrivateSpaceState get privateSpace => _privateSpace;

  Future<void> _loadPrivateSpace() async {
    final state = await _methods.invokeMethod<String>('privateSpace');
    _privateSpace =
        PrivateSpaceState.values.asNameMap()[state] ?? PrivateSpaceState.none;
  }

  @override
  Future<void> setPrivateSpaceLocked(bool locked) =>
      _methods.invokeMethod<void>('setPrivateSpaceLocked', {'locked': locked});

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

  // System: the launcher's own settings, saved as `appearance` and `textSize`.

  SystemState _system = const SystemState(
    account: Account(name: '', initials: ''),
    appearance: Appearance.auto,
    textSize: 0.5,
    focus: 'Off',
    privacyAlerts: 0,
  );

  @override
  SystemState get system => _system;

  Future<void> _loadSettings() async {
    Future<String?> get(String key) =>
        _methods.invokeMethod<String>('getPref', {'key': key});
    final [appearance, textSize] = await Future.wait([
      get('appearance'),
      get('textSize'),
    ]);
    _system = _system.copyWith(
      appearance: Appearance.values.asNameMap()[appearance],
      textSize: double.tryParse(textSize ?? ''),
    );
  }

  void _savePref(String key, String value) => unawaited(
    _methods.invokeMethod<void>('setPref', {'key': key, 'value': value}),
  );

  @override
  void setAppearance(Appearance appearance) {
    _system = _system.copyWith(appearance: appearance);
    _savePref('appearance', appearance.name);
    _notify();
  }

  @override
  void setTextSize(double value) {
    _system = _system.copyWith(textSize: value.clamp(0.0, 1.0));
    _savePref('textSize', '${_system.textSize}');
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
