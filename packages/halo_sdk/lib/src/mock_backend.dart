import 'dart:async';

import 'app_search.dart';
import 'backend.dart';
import 'models.dart';
import 'rules.dart';
import 'settings_pages.dart';

/// Fixtures that reuse the copy from the designs (design/screens/) so golden
/// tests line up: Friday 23 October, 09:41, Design review in Room 3, Elif.
class MockBackend implements HaloBackend {
  MockBackend({DateTime? now}) : now = now ?? DateTime(2026, 10, 23, 9, 41);

  @override
  final DateTime now;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<void> get homePressed => const Stream.empty();

  @override
  DeviceStatus get status =>
      const DeviceStatus(battery: 0.82, network: '5G · WI-FI', fullBy: '10:20');

  QuickSettings _quick = const QuickSettings(
    brightness: 0.64,
    brightnessAuto: true,
    volume: 0.42,
    volumeFooter: 'Media · ring',
    toggles: [
      QuickToggle(id: 'wifi', title: 'Wi-Fi', detail: 'Home-5G', on: true),
      QuickToggle(
        id: 'bluetooth',
        title: 'Bluetooth',
        detail: '2 devices',
        on: true,
      ),
      QuickToggle(id: 'cellular', title: 'Cellular', detail: '5G', on: true),
      QuickToggle(id: 'airplane', title: 'Airplane', detail: 'Off', on: false),
      QuickToggle(
        id: 'focus',
        title: 'Focus',
        detail: 'Work · until 11:00',
        on: true,
      ),
    ],
    media: MediaSession(
      title: 'Night Drive',
      artist: 'Mira Okafor',
      progress: 0.42,
      playing: true,
    ),
  );

  @override
  QuickSettings get quick => _quick;

  void _update(QuickSettings next) {
    _quick = next;
    _changes.add(null);
  }

  @override
  void setToggle(String id, bool on) {
    var toggles = [
      for (final t in _quick.toggles) t.id == id ? t.copyWith(on: on) : t,
    ];
    if (id == 'airplane') {
      // Airplane mode switches the radios off; leaving it does not bring them back.
      toggles = [
        for (final t in toggles)
          switch (t.id) {
            'wifi' ||
            'bluetooth' ||
            'cellular' when on => t.copyWith(on: false, detail: 'Off'),
            'airplane' => t.copyWith(detail: on ? 'On' : 'Off'),
            _ => t,
          },
      ];
    }
    _update(_quick.copyWith(toggles: toggles));
  }

  @override
  void setBrightness(double value) => _update(
    _quick.copyWith(brightness: value.clamp(0.0, 1.0), brightnessAuto: false),
  );

  @override
  void setVolume(double value) =>
      _update(_quick.copyWith(volume: value.clamp(0.0, 1.0)));

  SystemState _system = const SystemState(
    account: Account(name: 'Avery Stone', initials: 'AS'),
    appearance: Appearance.dark,
    textSize: 0.46,
    focus: 'Work',
    privacyAlerts: 2,
  );

  @override
  SystemState get system => _system;

  @override
  void setAppearance(Appearance appearance) {
    _system = _system.copyWith(appearance: appearance);
    _changes.add(null);
  }

  @override
  void setTextSize(double value) {
    _system = _system.copyWith(textSize: value.clamp(0.0, 1.0));
    _changes.add(null);
  }

  @override
  void setPlaying(bool playing) {
    final m = _quick.media;
    if (m == null) return;
    _update(_quick.copyWith(media: m.copyWith(playing: playing)));
  }

  DateTime _at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);

  @override
  List<CalendarEvent> get agenda => [
    CalendarEvent(
      start: _at(10, 0),
      title: 'Design review',
      location: 'Room 3',
      walkMinutes: 2,
      attendees: 4,
    ),
    CalendarEvent(
      start: _at(13, 30),
      title: 'Lunch with Elif',
      location: 'Karaköy',
    ),
    CalendarEvent(
      start: _at(19, 0),
      title: 'Dinner, corner table',
      location: 'Unconfirmed',
    ),
  ];

  @override
  CalendarEvent? get nextEvent => nextEventIn(agenda, now);

  @override
  bool get canReadCalendar => true;

  /// How often the mock was asked for the calendar permission.
  var calendarRequests = 0;

  @override
  Future<void> requestCalendarAccess() async => calendarRequests++;

  @override
  Future<bool> launch(String id) async => false;

  @override
  bool get isDefaultHome => true;

  @override
  Future<void> requestDefaultHome() async {}

  late final List<HaloAppInfo> _recents = [
    for (final id in const ['messages', 'music', 'maps', 'notes', 'web'])
      apps.firstWhere((a) => a.id == id),
  ];

  @override
  List<HaloAppInfo> get recents => List.unmodifiable(_recents);

  @override
  void closeRecent(String id) {
    if (_recents.any((a) => a.id == id)) {
      _recents.removeWhere((a) => a.id == id);
      _changes.add(null);
    }
  }

  @override
  void clearRecents() {
    if (_recents.isEmpty) return;
    _recents.clear();
    _changes.add(null);
  }

  @override
  List<HaloAppInfo> get apps => const [
    HaloAppInfo(id: 'camera', label: 'Camera'),
    HaloAppInfo(id: 'maps', label: 'Maps'),
    HaloAppInfo(id: 'messages', label: 'Messages'),
    HaloAppInfo(id: 'music', label: 'Music'),
    HaloAppInfo(id: 'notes', label: 'Notes'),
    HaloAppInfo(id: 'phone', label: 'Phone'),
    HaloAppInfo(id: 'web', label: 'Web'),
  ];

  // The Home design's order, Messages in the middle.
  final List<String> _arc = [
    'notes',
    'maps',
    'music',
    'messages',
    'camera',
    'web',
    'phone',
  ];

  @override
  List<HaloAppInfo> get arcApps => [
    for (final id in _arc) apps.firstWhere((a) => a.id == id),
  ];

  @override
  void pinToArc(String id) {
    if (_arc.contains(id) || !apps.any((a) => a.id == id)) return;
    _arc.add(id);
    _changes.add(null);
  }

  @override
  void unpinFromArc(String id) {
    if (_arc.remove(id)) _changes.add(null);
  }

  @override
  void moveOnArc(String id, int by) {
    final from = _arc.indexOf(id);
    if (from < 0) return;
    final to = (from + by).clamp(0, _arc.length - 1);
    if (to == from) return;
    _arc
      ..removeAt(from)
      ..insert(to, id);
    _changes.add(null);
  }

  @override
  Future<List<AppShortcut>> shortcuts(String appId) async => switch (appId) {
    'messages' => const [
      AppShortcut(id: 'new', label: 'New message'),
      AppShortcut(id: 'elif', label: 'Elif'),
    ],
    'maps' => const [AppShortcut(id: 'home', label: 'Directions home')],
    _ => const [],
  };

  @override
  Future<bool> startShortcut(String appId, String shortcutId) async => false;

  /// App ids the mock was asked to show App info for, in order.
  final appInfoRequests = <String>[];

  /// App ids the mock was asked to uninstall, in order.
  final uninstallRequests = <String>[];

  @override
  Future<void> openAppInfo(String appId) async => appInfoRequests.add(appId);

  @override
  Future<void> uninstall(String appId) async => uninstallRequests.add(appId);

  @override
  List<SettingsPage> get settingsPages => defaultSettingsPages;

  /// Settings page ids the mock was asked to open, in order.
  final settingsRequests = <String>[];

  @override
  Future<void> openSettingsPage(String id) async => settingsRequests.add(id);

  bool _contacts = true;

  /// Contact search allowed. Tests turn it off to see the ask.
  set canSearchContacts(bool value) {
    _contacts = value;
    _changes.add(null);
  }

  @override
  bool get canSearchContacts => _contacts;

  /// How often the mock was asked for the contacts permission.
  var contactsRequests = 0;

  @override
  Future<void> requestContactsAccess() async => contactsRequests++;

  static const _contactsFixture = [
    ContactResult(id: 'elif', name: 'Elif'),
    ContactResult(id: 'deniz', name: 'Deniz'),
    ContactResult(id: 'mira', name: 'Mira Okafor'),
  ];

  @override
  Future<List<ContactResult>> searchContacts(String query) async => _contacts
      ? searchByLabel(_contactsFixture, (c) => c.name, query)
      : const [];

  /// Contact ids the mock was asked to open, in order.
  final contactRequests = <String>[];

  @override
  Future<void> openContact(String id) async => contactRequests.add(id);

  /// How often the mock was asked to open the system assistant.
  var assistantRequests = 0;

  @override
  Future<bool> openAssistant() async {
    assistantRequests++;
    return false;
  }

  @override
  PrivateSpaceState get privateSpace => PrivateSpaceState.none;

  @override
  Future<void> setPrivateSpaceLocked(bool locked) async {}

  late final List<HaloNotification> _notifications = [
    HaloNotification(
      id: 'elif-1',
      app: 'messages',
      sender: 'Elif',
      source: 'Messages · Elif',
      body: 'Are we still on for 7? I booked the corner table.',
      preview: 'Are we still on for 7?',
      receivedAt: _at(9, 39),
      unread: true,
      mark: StreamMark.current,
      canReply: true,
      actionPrompt: 'Still on for 7?',
    ),
    HaloNotification(
      id: 'calendar-1',
      app: 'calendar',
      sender: 'Calendar',
      body: 'Design review starts in 19 minutes. Room 3.',
      receivedAt: _at(9, 40),
      unread: true,
      mark: StreamMark.alert,
    ),
    HaloNotification(
      id: 'parcel-1',
      app: 'parcel',
      sender: 'Parcel',
      body: 'Arrives today between 14:00 and 16:00.',
      preview: 'Arriving 14:00 to 16:00',
      receivedAt: _at(8, 15),
      unread: false,
    ),
    HaloNotification(
      id: 'deniz-1',
      app: 'messages',
      sender: 'Deniz',
      source: 'Messages · Deniz',
      body: 'Sent you 3 files for tomorrow.',
      receivedAt: DateTime(now.year, now.month, now.day - 1, 18, 5),
      unread: false,
    ),
  ];

  @override
  List<HaloNotification> get notifications => List.unmodifiable(_notifications);

  @override
  bool get canReadNotifications => true;

  /// How often the mock was asked to open notification access.
  var notificationAccessRequests = 0;

  @override
  Future<void> requestNotificationAccess() async =>
      notificationAccessRequests++;

  /// Notification ids the mock was asked to open, in order.
  final openedNotifications = <String>[];

  /// Replies the mock was asked to send, as (id, text).
  final replies = <(String, String)>[];

  /// Notification ids the mock snoozed, in order.
  final snoozed = <String>[];

  /// How often the mock was told the Stream was seen. It keeps the design's
  /// fixtures as they are.
  var seenMarks = 0;

  @override
  Future<void> openNotification(String id) async => openedNotifications.add(id);

  @override
  Future<void> dismissNotification(String id) async {
    if (_notifications.any((n) => n.id == id)) {
      _notifications.removeWhere((n) => n.id == id);
      _changes.add(null);
    }
  }

  @override
  Future<bool> replyToNotification(String id, String text) async {
    final n = _notifications.where((n) => n.id == id).firstOrNull;
    if (n == null || !n.canReply) return false;
    replies.add((id, text));
    return true;
  }

  @override
  Future<void> snoozeNotification(String id) async {
    snoozed.add(id);
    await dismissNotification(id);
  }

  @override
  void markNotificationsSeen() => seenMarks++;

  @override
  List<HaloNotification> get lockPreviews => [
    for (final id in const ['elif-1', 'parcel-1'])
      _notifications.firstWhere((n) => n.id == id),
  ];

  @override
  StreamSummary get streamSummary => const StreamSummary(
    newCount: 4,
    read: 11,
    needYou: [
      'Reply to Elif about dinner',
      'Design review moved to Room 3',
      'Be home 14:00 to 16:00 for the parcel',
    ],
  );
}
