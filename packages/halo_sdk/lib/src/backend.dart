import 'models.dart';

/// What the launcher can ask the platform. [MockBackend] serves the design
/// fixtures; `AndroidBackend` in `packages/halo_android` serves the phone. The
/// getters are snapshots, and [changes] says when to read them again.
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

  /// Turns auto brightness on or off.
  void setBrightnessAuto(bool auto);

  void setVolume(double value);

  void setPlaying(bool playing);

  /// Skips to the next track, or the previous one.
  void skipMedia({required bool next});

  /// System (settings) state.
  SystemState get system;

  /// The optional accesses Halo can be given, granted or not.
  List<AccessGrant> get accessGrants;

  /// Opens the way to give [id] (a permission dialog or the Android screen).
  /// Android only lets the user take an access back, in Settings.
  Future<void> openAccess(String id);

  /// Opens Android's own Settings page for a System section: `connections`,
  /// `display`, `sound`, `focus`, `privacy` or `battery`.
  Future<void> openAndroidSettings(String section);

  void setAppearance(Appearance appearance);

  /// Sets the text size from 0 to 1.
  void setTextSize(double value);

  /// Today's events in time order. Empty without calendar access.
  List<CalendarEvent> get agenda;

  /// Whether Halo may read the calendar (an optional permission).
  bool get canReadCalendar;

  /// Asks for the calendar permission. [changes] fires once it is answered.
  Future<void> requestCalendarAccess();

  /// The next calendar event today, if any.
  CalendarEvent? get nextEvent;

  /// Every installed app, by label.
  List<HaloAppInfo> get apps;

  /// The apps the user keeps on the Home arc, left to right.
  List<HaloAppInfo> get arcApps;

  /// Adds an app to the right end of the arc. Does nothing if it is there.
  void pinToArc(String id);

  void unpinFromArc(String id);

  /// Moves an app on the arc by [by] places (negative is left), clamped.
  void moveOnArc(String id, int by);

  /// The app's shortcuts. Empty unless Halo is the default home app.
  Future<List<AppShortcut>> shortcuts(String appId);

  Future<bool> startShortcut(String appId, String shortcutId);

  /// Opens the system's App info page for the app.
  Future<void> openAppInfo(String appId);

  /// Asks the system to uninstall the app; the system confirms with the user.
  Future<void> uninstall(String appId);

  /// System settings pages that search can open.
  List<SettingsPage> get settingsPages;

  Future<void> openSettingsPage(String id);

  /// Whether search may look in the contacts (an optional permission).
  bool get canSearchContacts;

  /// Asks for the contacts permission. [changes] fires once it is answered.
  Future<void> requestContactsAccess();

  /// Contacts whose name matches [query], best first, at most a few.
  /// Empty without the permission.
  Future<List<ContactResult>> searchContacts(String query);

  Future<void> openContact(String id);

  /// Opens the assistant the user picked in the system (none is fine). Halo
  /// has no assistant of its own (D-012). False when there is none.
  Future<bool> openAssistant();

  PrivateSpaceState get privateSpace;

  /// Locks or unlocks the private space; the system may ask for the lock.
  Future<void> setPrivateSpaceLocked(bool locked);

  /// Starts an app. False when this backend can't start apps (the mock), so
  /// the launcher shows a stand-in instead.
  Future<bool> launch(String id);

  /// Whether Halo is the default home app.
  bool get isDefaultHome;

  /// Asks the platform to make Halo the default home app.
  Future<void> requestDefaultHome();

  /// Emits when the user presses Home while Halo is already showing, or comes
  /// back to it with Home. Broadcast.
  Stream<void> get homePressed;

  /// Whether Halo may see which apps were used (Android's usage access).
  /// Without it Recents is empty and offers the grant.
  bool get canReadUsage;

  /// Opens Android's usage access screen. [changes] fires once Halo is back
  /// and the grant is read again.
  Future<void> requestUsageAccess();

  /// Apps in Recents, left to right.
  List<HaloAppInfo> get recents;

  /// Closes one app in Recents.
  void closeRecent(String id);

  /// Closes every app in Recents.
  void clearRecents();

  /// Notifications in Stream order: what is in play now first, then earlier.
  List<HaloNotification> get notifications;

  /// Whether Halo may read the notifications (a special access the user
  /// grants in system settings).
  bool get canReadNotifications;

  /// Opens the system screen where the user grants notification access.
  Future<void> requestNotificationAccess();

  /// Opens what the notification points to, as tapping it would.
  Future<void> openNotification(String id);

  /// Clears the notification from the phone, not just from Halo.
  Future<void> dismissNotification(String id);

  /// Sends [text] through the notification's reply action. False when it has
  /// none or the app refused it.
  Future<bool> replyToNotification(String id, String text);

  /// Puts the notification away for an hour (Stream's LATER).
  Future<void> snoozeNotification(String id);

  /// Runs one of the notification's own actions ([HaloNotification.actions]).
  Future<void> runNotificationAction(String id, String actionId);

  /// Opens the maps app at a place (Home's Navigate).
  Future<void> openMap(String place);

  /// Opens a calendar event in the calendar app (Home's Open event).
  Future<void> openEvent(String eventId);

  /// Everything shown so far counts as seen: it moves from NOW to EARLIER.
  /// Called when the user leaves Stream.
  void markNotificationsSeen();

  /// The previews Lock shows, at most two.
  List<HaloNotification> get lockPreviews;

  /// Halo's digest for the top of the Stream.
  StreamSummary get streamSummary;
}
