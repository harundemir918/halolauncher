import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

/// [HaloBackend] on an Android phone, over the `halo_android` channels.
///
/// Serves the clock, installed apps in every profile (with icons), the arc
/// the user keeps, launching, shortcuts, App info and uninstall, battery, the
/// default home app, Home presses, today's calendar, the phone's
/// notifications and the playing media, and the Switchboard's brightness,
/// volume, connection and Do Not Disturb state. The arc, appearance, text size
/// and when Stream was last seen are saved on the phone. Recents is empty until
/// Phase 6. Empty, not invented (CLAUDE.md rule 1).
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
      b._loadCalendar(),
      b._loadNotifications(),
      b._loadMedia(),
      b._loadQuick(),
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
      case 'calendar':
        unawaited(_loadCalendar().then((_) => _notify()));
      case 'notifications':
        unawaited(
          Future.wait([_loadNotifications(), _loadMedia()])
              .then((_) => _notify()),
        );
      case 'media':
        unawaited(_loadMedia().then((_) => _notify()));
      case 'quick':
        // A dial being dragged already shows its value; skip the echo.
        if (DateTime.now().difference(_dialTouched) > _echoWindow) {
          unawaited(_loadQuick().then((_) => _notify()));
        }
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
        Future.wait([
          _loadDefaultHome(),
          _loadContactsAccess(),
          _loadCalendar(),
          _loadNotifications(),
          _loadMedia(),
          _loadQuick(),
        ]).then((_) => _notify()),
      );
    }
  }

  /// Rebuilds on each minute boundary so the clock stays right, the next
  /// event moves on and the media progress follows; reloads the agenda when
  /// the day changes.
  void _tickEachMinute() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _clock = Timer(next.difference(now), () async {
      final today = DateTime.now();
      await Future.wait([
        if (today.day != _agendaDay) _loadCalendar(),
        if (_media != null) _loadMedia(),
      ]);
      _notify();
      _tickEachMinute();
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _mediaTick?.cancel();
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
    // Notifications name their arc app from this list.
    _shown = null;
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

  @override
  Future<bool> openAssistant() async =>
      await _methods.invokeMethod<bool>('openAssistant') ?? false;

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
  DateTime? _fullAt;

  @override
  DeviceStatus get status {
    final at = _fullAt;
    return DeviceStatus(
      battery: _battery,
      network: '',
      fullBy: at == null
          ? null
          : '${at.hour.toString().padLeft(2, '0')}:'
                '${at.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _loadBattery() async {
    final b = await _methods.invokeMapMethod<String, Object>('battery');
    _battery = (b?['level'] as num?)?.toDouble() ?? 0;
    // Android's estimate to full, only while charging and once it has one.
    final ms = (b?['fullInMs'] as num?)?.toInt() ?? -1;
    _fullAt = b?['charging'] == true && ms > 0
        ? DateTime.now().add(Duration(milliseconds: ms))
        : null;
  }

  // Switchboard: the phone's brightness, media volume, radios and Do Not
  // Disturb, plus the playing media session. Android lets an app set the
  // volume and Do Not Disturb (with a grant) and brightness (with Write
  // settings); the radios it only lets the user switch, so those rows open
  // the matching Settings panel and read the new state back.

  QuickSettings _quick = const QuickSettings(
    brightness: 0.5,
    brightnessAuto: true,
    volume: 0.5,
    volumeFooter: 'Media',
    toggles: [],
  );

  bool _focusAccess = false;

  /// Local dial moves and the echo from the system's own change event.
  static const _echoWindow = Duration(milliseconds: 400);
  DateTime _dialTouched = DateTime.fromMillisecondsSinceEpoch(0);

  MediaSession? _media;

  @override
  QuickSettings get quick => _quick.copyWith(media: _media);

  Future<void> _loadQuick() async {
    final q = await _methods.invokeMapMethod<String, Object?>('quick');
    if (q == null) return;
    Map<String, Object?> row(String id) =>
        (q[id] as Map?)?.cast<String, Object?>() ?? const {};
    QuickToggle toggle(String id, String title, String Function(Map) detail) =>
        QuickToggle(
          id: id,
          title: title,
          detail: detail(row(id)),
          on: row(id)['on'] == true,
        );
    String state(Map r) => switch (r['state']) {
      'connected' => 'Connected',
      'on' => 'On',
      _ => 'Off',
    };
    final focus = row('focus');
    _focusAccess = focus['canChange'] == true;
    _quick = QuickSettings(
      brightness: (q['brightness'] as num?)?.toDouble() ?? 0.5,
      brightnessAuto: q['brightnessAuto'] == true,
      brightnessWritable: q['canWriteSettings'] == true,
      volume: (q['volume'] as num?)?.toDouble() ?? 0.5,
      volumeFooter: 'Media · ${q['ringer'] ?? 'ring'}',
      toggles: [
        toggle('wifi', 'Wi-Fi', state),
        toggle('bluetooth', 'Bluetooth', state),
        toggle('cellular', 'Cellular', state),
        toggle('airplane', 'Airplane', state),
        QuickToggle(
          id: 'focus',
          title: 'Focus',
          detail: focus['on'] == true
              ? 'Do not disturb'
              : focus['canChange'] == true
              ? 'Off'
              : 'Allow access',
          on: focus['on'] == true,
        ),
      ],
    );
  }

  Future<void> _loadMedia() async {
    final m = await _methods.invokeMapMethod<String, Object?>('media');
    _media = m == null
        ? null
        : MediaSession(
            title: m['title'] as String? ?? '',
            artist: m['artist'] as String? ?? '',
            progress: (m['progress'] as num?)?.toDouble() ?? 0,
            playing: m['playing'] as bool? ?? false,
          );
    _syncMediaTick();
  }

  Timer? _mediaTick;

  /// While a track plays the position keeps moving without any session event,
  /// so reload it each second; stop as soon as nothing plays.
  void _syncMediaTick() {
    if (_media?.playing != true) {
      _mediaTick?.cancel();
      _mediaTick = null;
      return;
    }
    _mediaTick ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      await _loadMedia();
      _notify();
    });
  }

  @override
  void setToggle(String id, bool on) {
    if (id == 'focus') {
      unawaited(_methods.invokeMethod<void>('setFocus', {'on': on}));
    } else {
      unawaited(_methods.invokeMethod<void>('openRadio', {'id': id}));
    }
  }

  @override
  void setBrightness(double value) {
    if (!_quick.brightnessWritable) {
      unawaited(
        _methods.invokeMethod<void>('setBrightnessAuto', {'auto': true}),
      );
      return;
    }
    final v = value.clamp(0.0, 1.0);
    _dialTouched = DateTime.now();
    _quick = _quick.copyWith(brightness: v, brightnessAuto: false);
    _notify();
    unawaited(_methods.invokeMethod<void>('setBrightness', {'value': v}));
  }

  @override
  void setBrightnessAuto(bool auto) {
    // Without the Write settings grant this opens the screen that gives it.
    if (_quick.brightnessWritable) {
      _quick = _quick.copyWith(brightnessAuto: auto);
      _notify();
    }
    unawaited(_methods.invokeMethod<void>('setBrightnessAuto', {'auto': auto}));
  }

  @override
  void setVolume(double value) {
    final v = value.clamp(0.0, 1.0);
    _dialTouched = DateTime.now();
    _quick = _quick.copyWith(volume: v);
    _notify();
    unawaited(_methods.invokeMethod<void>('setVolume', {'value': v}));
  }

  @override
  void skipMedia({required bool next}) =>
      unawaited(_methods.invokeMethod<void>('skip', {'next': next}));

  @override
  void setPlaying(bool playing) {
    final m = _media;
    if (m == null) return;
    // Show it at once; the session's own event confirms it.
    _media = m.copyWith(playing: playing);
    _syncMediaTick();
    _notify();
    unawaited(_methods.invokeMethod<void>('setPlaying', {'playing': playing}));
  }

  // System: the launcher's own settings, saved as `appearance` and `textSize`.

  SystemState _system = const SystemState(
    account: Account(name: '', initials: ''),
    appearance: Appearance.auto,
    textSize: 0.5,
    focus: 'Off',
    privacyAlerts: 0,
  );

  @override
  SystemState get system => _system.copyWith(
    focus: _quick.toggles.any((t) => t.id == 'focus' && t.on)
        ? 'Do not disturb'
        : 'Off',
    privacyAlerts: accessGrants.where((g) => !g.granted).length,
  );

  @override
  List<AccessGrant> get accessGrants => [
    AccessGrant(
      id: 'notifications',
      title: 'Notifications',
      detail: 'Stream and Home',
      granted: canReadNotifications,
    ),
    AccessGrant(
      id: 'calendar',
      title: 'Calendar',
      detail: 'Home, today',
      granted: canReadCalendar,
    ),
    AccessGrant(
      id: 'contacts',
      title: 'Contacts',
      detail: 'Search',
      granted: canSearchContacts,
    ),
    AccessGrant(
      id: 'brightness',
      title: 'Write settings',
      detail: 'Light dial',
      granted: _quick.brightnessWritable,
    ),
    AccessGrant(
      id: 'focus',
      title: 'Do not disturb',
      detail: 'Focus row',
      granted: _focusAccess,
    ),
  ];

  @override
  Future<void> openAccess(String id) => switch (id) {
    'notifications' => requestNotificationAccess(),
    'calendar' => requestCalendarAccess(),
    'contacts' => requestContactsAccess(),
    'brightness' => _methods.invokeMethod<void>('requestWriteSettings'),
    'focus' => _methods.invokeMethod<void>('requestPolicyAccess'),
    _ => Future<void>.value(),
  };

  @override
  Future<void> openAndroidSettings(String section) =>
      _methods.invokeMethod<void>('openSystemSettings', {'section': section});

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

  // Calendar

  List<CalendarEvent> _agenda = const [];
  int? _agendaDay;
  bool _canReadCalendar = false;

  @override
  List<CalendarEvent> get agenda => _agenda;

  @override
  CalendarEvent? get nextEvent => nextEventIn(_agenda, now);

  @override
  bool get canReadCalendar => _canReadCalendar;

  @override
  Future<void> requestCalendarAccess() =>
      _methods.invokeMethod<void>('requestCalendar');

  Future<void> _loadCalendar() async {
    _canReadCalendar =
        await _methods.invokeMethod<bool>('canReadCalendar') ?? false;
    final list = _canReadCalendar
        ? await _methods.invokeListMethod<Map>('agenda') ?? const []
        : const <Map>[];
    _agendaDay = DateTime.now().day;
    _agenda = [
      for (final e in list)
        CalendarEvent(
          start: DateTime.fromMillisecondsSinceEpoch(e['start'] as int),
          title: e['title'] as String,
          location: e['location'] as String,
          attendees: e['attendees'] as int?,
          id: e['id'] as String?,
          allDay: e['allDay'] as bool? ?? false,
        ),
    ];
  }

  // Recents (Phase 6)

  @override
  List<HaloAppInfo> get recents => const [];

  @override
  void closeRecent(String id) {}

  @override
  void clearRecents() {}

  // Notifications

  List<Map> _raw = const [];
  bool _canReadNotifications = false;

  // When the user last left Stream (epoch ms, saved as `streamSeen`). What
  // arrived after it is unread: Android doesn't track reading.
  int _seenAt = 0;

  List<HaloNotification>? _shown;

  @override
  bool get canReadNotifications => _canReadNotifications;

  @override
  Future<void> requestNotificationAccess() =>
      _methods.invokeMethod<void>('requestNotificationAccess');

  Future<void> _loadNotifications() async {
    final [access, seen] = await Future.wait([
      _methods.invokeMethod<bool>('canReadNotifications'),
      _methods.invokeMethod<String>('getPref', {'key': 'streamSeen'}),
    ]);
    _canReadNotifications = access as bool? ?? false;
    _seenAt = int.tryParse(seen as String? ?? '') ?? 0;
    _raw = _canReadNotifications
        ? await _methods.invokeListMethod<Map>('notifications') ?? const []
        : const [];
    _shown = null;
  }

  /// The arc app a notification belongs to, so its unread badge shows there.
  String _appIdFor(String package) {
    for (final a in _apps) {
      if (a.id.startsWith('$package/') && !a.work) return a.id;
    }
    return package;
  }

  @override
  List<HaloNotification> get notifications => _shown ??= _build();

  /// Halo's marks (D-012 rules): unread ones are in play now; the newest
  /// unread message that can be replied to is the current one (Volt), other
  /// unread ones are alerts (Flare), the rest read.
  List<HaloNotification> _build() {
    var current = false;
    final list = <HaloNotification>[];
    for (final r in _raw) {
      final title = r['title'] as String;
      final app = r['app'] as String;
      final postTime = r['postTime'] as int;
      final unread = postTime > _seenAt;
      final canReply = r['canReply'] as bool? ?? false;
      final StreamMark mark;
      if (!unread) {
        mark = StreamMark.read;
      } else if (canReply && !current) {
        current = true;
        mark = StreamMark.current;
      } else {
        mark = StreamMark.alert;
      }
      list.add(
        HaloNotification(
          id: r['id'] as String,
          app: _appIdFor(r['package'] as String),
          sender: title.isNotEmpty ? title : app,
          source: title.isNotEmpty ? '$app · $title' : app,
          body: r['text'] as String,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(postTime),
          unread: unread,
          mark: mark,
          canReply: canReply,
          canDismiss: r['canDismiss'] as bool? ?? true,
          actions: [
            for (final a in (r['actions'] as List?) ?? const [])
              NotificationAction(
                id: (a as Map)['id'] as String,
                label: a['label'] as String,
              ),
          ],
        ),
      );
    }
    // Stream order: in play first, then earlier, newest first within each.
    return [...list.where((n) => n.unread), ...list.where((n) => !n.unread)];
  }

  @override
  List<HaloNotification> get lockPreviews => previewsOf(notifications);

  @override
  StreamSummary get streamSummary => summaryOf(notifications);

  @override
  Future<void> openNotification(String id) =>
      _methods.invokeMethod<bool>('openNotification', {'id': id});

  @override
  Future<void> dismissNotification(String id) =>
      _methods.invokeMethod<void>('dismissNotification', {'id': id});

  @override
  Future<bool> replyToNotification(String id, String text) async =>
      await _methods.invokeMethod<bool>('replyNotification', {
        'id': id,
        'text': text,
      }) ??
      false;

  @override
  Future<void> snoozeNotification(String id) =>
      _methods.invokeMethod<void>('snoozeNotification', {'id': id});

  @override
  Future<void> runNotificationAction(String id, String actionId) => _methods
      .invokeMethod<bool>('notificationAction', {'id': id, 'action': actionId});

  @override
  Future<void> openMap(String place) =>
      _methods.invokeMethod<void>('openMap', {'place': place});

  @override
  Future<void> openEvent(String eventId) =>
      _methods.invokeMethod<void>('openEvent', {'id': eventId});

  @override
  void markNotificationsSeen() {
    final latest = _raw.fold<int>(
      _seenAt,
      (m, r) => (r['postTime'] as int) > m ? r['postTime'] as int : m,
    );
    if (latest == _seenAt) return;
    _seenAt = latest;
    _shown = null;
    _savePref('streamSeen', '$latest');
    _notify();
  }
}
