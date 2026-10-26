import 'models.dart';

/// What the shell can ask the system. Phase 4 adds a real implementation over
/// halo-bus; until then [MockBackend] serves fixtures. The getters are
/// snapshots for now; reactive streams arrive with the real backend.
abstract interface class HaloBackend {
  /// Current local time.
  DateTime get now;

  DeviceStatus get status;

  /// Emits whenever anything above or below changes. Broadcast.
  Stream<void> get changes;

  /// Switchboard state: dials, toggles and the media session.
  QuickSettings get quick;

  /// Turns a quick toggle on or off. Airplane mode switches the radios off.
  void setToggle(String id, bool on);

  /// Sets brightness by hand, which turns auto brightness off.
  void setBrightness(double value);

  void setVolume(double value);

  void setPlaying(bool playing);

  /// System (settings) state.
  SystemState get system;

  void setAppearance(Appearance appearance);

  /// Sets the text size from 0 to 1.
  void setTextSize(double value);

  /// Today's events in time order.
  List<CalendarEvent> get agenda;

  /// The next calendar event today, if any.
  CalendarEvent? get nextEvent;

  /// Installed apps in arc order, left to right.
  List<HaloAppInfo> get apps;

  /// Apps in Recents, left to right.
  List<HaloAppInfo> get recents;

  /// Closes one app in Recents.
  void closeRecent(String id);

  /// Closes every app in Recents.
  void clearRecents();

  /// Notifications in Stream order: what is in play now first, then earlier.
  List<HaloNotification> get notifications;

  /// The previews Lock shows, at most two.
  List<HaloNotification> get lockPreviews;

  /// Halo's digest for the top of the Stream.
  StreamSummary get streamSummary;
}
