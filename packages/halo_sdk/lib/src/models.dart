import 'dart:typed_data';

/// Battery and connectivity for the status row.
class DeviceStatus {
  const DeviceStatus({
    required this.battery,
    required this.network,
    this.fullBy,
  });

  /// 0 to 1.
  final double battery;

  /// Estimated time the battery is full (`10:20`), while charging.
  final String? fullBy;

  /// Connectivity summary such as `5G · WI-FI`.
  final String network;

  int get batteryPercent => (battery.clamp(0.0, 1.0) * 100).round();
}

/// A calendar entry.
class CalendarEvent {
  const CalendarEvent({
    required this.start,
    required this.title,
    required this.location,
    this.walkMinutes,
    this.attendees,
    this.id,
    this.allDay = false,
  });

  /// The calendar's own id, when the event comes from the phone (to open it).
  final String? id;

  /// An all-day event: [start] is the day's midnight, and it has no time.
  final bool allDay;

  final DateTime start;
  final String title;

  /// Where it is, or a status shown in the same slot (`Unconfirmed`).
  final String location;

  /// Walking time to the venue, when known.
  final int? walkMinutes;

  /// Number of people, when known.
  final int? attendees;

  /// Whole minutes from [now] until the event starts, never negative.
  int minutesUntil(DateTime now) {
    final m = start.difference(now).inMinutes;
    return m < 0 ? 0 : m;
  }
}

/// How the Stream marks a notification: Volt for the one in play, Flare for
/// an alert, a hollow ring once it has been dealt with.
enum StreamMark { current, alert, read }

/// A notification in the Stream timeline.
/// What kind of thing a notification is, from the app's own category.
enum NotificationKind { message, missedCall, other }

class HaloNotification {
  const HaloNotification({
    required this.id,
    required this.app,
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.unread,
    this.source,
    this.mark = StreamMark.read,
    this.preview,
    this.canReply = false,
    this.canDismiss = true,
    this.actions = const [],
    this.actionPrompt,
    this.kind = NotificationKind.other,
    this.fromPerson = false,
    this.starred = false,
  });

  final String id;

  /// Source app id (`messages`, `parcel`).
  final String app;

  /// Mono sender label as shown (`Elif`, `Parcel`).
  final String sender;
  final String body;
  final DateTime receivedAt;
  final bool unread;

  /// Header in the Stream (`Messages · Elif`). Defaults to the sender.
  final String? source;

  /// Which dot the Stream draws.
  final StreamMark mark;

  /// Shorter copy for Lock. Defaults to [body].
  final String? preview;

  /// Whether the Stream offers REPLY and LATER.
  final bool canReply;

  /// Whether it can be swiped away (ongoing ones can't).
  final bool canDismiss;

  /// A message, a missed call or anything else (priority, D-030).
  final NotificationKind kind;

  /// Whether the app names a person behind it (a chat, a call).
  final bool fromPerson;

  /// Whether that person is starred in the user's contacts.
  final bool starred;

  /// The app's own actions besides reply (`Mark as read`, `Archive`).
  final List<NotificationAction> actions;

  /// Short question Halo offers to answer from Home (`Still on for 7?`).
  final String? actionPrompt;

  HaloNotification copyWith({StreamMark? mark}) => HaloNotification(
    id: id,
    app: app,
    sender: sender,
    body: body,
    receivedAt: receivedAt,
    unread: unread,
    source: source,
    mark: mark ?? this.mark,
    preview: preview,
    canReply: canReply,
    canDismiss: canDismiss,
    actions: actions,
    actionPrompt: actionPrompt,
    kind: kind,
    fromPerson: fromPerson,
    starred: starred,
  );

  /// Compact age as the designs show it: `2M`, `1H`, `3D`.
  String age(DateTime now) {
    final d = now.difference(receivedAt);
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes}M';
    if (d.inHours < 24) return '${d.inHours}H';
    return '${d.inDays}D';
  }
}

/// One of a notification's own actions, by its place in the notification.
class NotificationAction {
  const NotificationAction({required this.id, required this.label});

  final String id;
  final String label;
}

/// An installed app, in arc order.
class HaloAppInfo {
  const HaloAppInfo({
    required this.id,
    required this.label,
    this.icon,
    this.monoIcon,
    this.glyph,
    this.work = false,
    this.privateSpace = false,
    this.canUninstall = true,
    this.accent,
  });

  /// Stable id: `messages` in the mock, the flattened component name
  /// (`com.example/.MainActivity`) on Android.
  final String id;
  final String label;

  /// The app's own icon as PNG bytes, when the platform has one. Without it
  /// the launcher draws a Halo glyph.
  final Uint8List? icon;

  /// A monochrome version of the icon as a PNG alpha mask: the icon's own
  /// monochrome layer (Android 13+) or one derived from it. The arc tints it
  /// like the design's glyphs: bone, or carbon on Volt when focused.
  final Uint8List? monoIcon;

  /// The design glyph for the role this app fills, when it is the user's
  /// default for one (`maps`, `music`, `messages`, `camera`, `web`, `phone`).
  /// The arc draws such apps with the design's own glyph (D-025).
  final String? glyph;

  /// Installed in the work profile.
  final bool work;

  /// Installed in the private space (Android 15+).
  final bool privateSpace;

  /// False for apps that ship with the system and can't be removed.
  final bool canUninstall;

  /// The icon's main color as ARGB, when the platform worked one out. Recents
  /// tints a slat with it, since Halo can't read another app's last frame.
  final int? accent;

  HaloAppInfo withIcons(Uint8List? icon, Uint8List? monoIcon, [int? accent]) =>
      HaloAppInfo(
        id: id,
        label: label,
        icon: icon,
        monoIcon: monoIcon,
        glyph: glyph,
        work: work,
        privateSpace: privateSpace,
        canUninstall: canUninstall,
        accent: accent ?? this.accent,
      );
}

/// A page of the system settings that search can open (`Wi-Fi`, `Battery`).
class SettingsPage {
  const SettingsPage({required this.id, required this.label});

  /// Stable id the backend maps to a settings screen (`wifi`).
  final String id;
  final String label;
}

/// A contact found by search. Its [id] is opaque to the launcher.
class ContactResult {
  const ContactResult({required this.id, required this.name});

  final String id;
  final String name;

  /// Up to two initials for the notch avatar (`MO` for Mira Okafor).
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words
        .take(2)
        .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
        .join();
  }
}

/// The Android 15 private space: absent, or present and locked or unlocked.
/// Its apps are listed only while it is unlocked.
enum PrivateSpaceState { none, locked, unlocked }

/// One of an app's shortcuts (`New message`, `Elif`), from a long press.
class AppShortcut {
  const AppShortcut({required this.id, required this.label});

  final String id;
  final String label;
}

/// A quick toggle on the Switchboard (Wi-Fi, Bluetooth, ...).
class QuickToggle {
  const QuickToggle({
    required this.id,
    required this.title,
    required this.detail,
    required this.on,
  });

  final String id;
  final String title;

  /// Mono sub-label (`Home-5G`, `2 devices`, `Off`).
  final String detail;
  final bool on;

  QuickToggle copyWith({String? detail, bool? on}) => QuickToggle(
    id: id,
    title: title,
    detail: detail ?? this.detail,
    on: on ?? this.on,
  );
}

/// The now-playing session shown on the Switchboard.
class MediaSession {
  const MediaSession({
    required this.title,
    required this.artist,
    required this.progress,
    required this.playing,
    this.canSeek = false,
  });

  final String title;
  final String artist;

  /// 0 to 1.
  final double progress;
  final bool playing;

  /// Whether the player lets the position be set (it has a length and offers
  /// seeking). Without it the progress bar only shows.
  final bool canSeek;

  MediaSession copyWith({double? progress, bool? playing}) => MediaSession(
    title: title,
    artist: artist,
    progress: progress ?? this.progress,
    playing: playing ?? this.playing,
    canSeek: canSeek,
  );
}

/// State behind the Switchboard.
class QuickSettings {
  const QuickSettings({
    required this.brightness,
    required this.brightnessAuto,
    required this.volume,
    required this.volumeFooter,
    required this.toggles,
    this.media,
    this.brightnessWritable = true,
  });

  /// 0 to 1.
  final double brightness;

  /// Whether Halo may set brightness (Android's Write settings grant). When
  /// not, the dial only reads, and touching it opens the grant screen.
  final bool brightnessWritable;

  /// Auto brightness. Setting a level by hand turns it off.
  final bool brightnessAuto;

  /// 0 to 1.
  final double volume;

  /// Which streams the volume dial controls (`Media · ring`).
  final String volumeFooter;
  final List<QuickToggle> toggles;
  final MediaSession? media;

  /// Whether Focus (Do Not Disturb) is on. The priority rules hold back what
  /// isn't a person while it is (D-030).
  bool get focus => toggles.any((t) => t.id == 'focus' && t.on);

  QuickSettings copyWith({
    double? brightness,
    bool? brightnessAuto,
    double? volume,
    List<QuickToggle>? toggles,
    MediaSession? media,
  }) => QuickSettings(
    brightnessWritable: brightnessWritable,
    brightness: brightness ?? this.brightness,
    brightnessAuto: brightnessAuto ?? this.brightnessAuto,
    volume: volume ?? this.volume,
    volumeFooter: volumeFooter,
    toggles: toggles ?? this.toggles,
    media: media ?? this.media,
  );
}

/// Halo's digest at the top of the Stream.
class StreamSummary {
  const StreamSummary({
    required this.newCount,
    required this.read,
    required this.needYou,
  });

  /// Notifications since the Stream was last opened.
  final int newCount;

  /// How many things Halo read for the user.
  final int read;

  /// The few that need the user, in priority order.
  final List<String> needYou;
}

/// Appearance. Only dark is designed so far (D-013), so choosing light or auto
/// is stored but does not change the theme yet.
enum Appearance { dark, light, auto }

/// The signed-in person.
class Account {
  const Account({required this.name, required this.initials});

  final String name;

  /// Two letters for the avatar (`AS`).
  final String initials;
}

/// State behind the System (settings) screen.
class SystemState {
  const SystemState({
    required this.account,
    required this.appearance,
    required this.textSize,
    required this.focus,
    required this.privacyAlerts,
  });

  final Account account;
  final Appearance appearance;

  /// 0 to 1, mapped onto [minTextSize] to [maxTextSize].
  final double textSize;

  /// Active focus mode name (`Work`).
  final String focus;
  final int privacyAlerts;

  static const int minTextSize = 12;
  static const int maxTextSize = 20;

  /// Text size in px (16 at 0.5).
  int get textSizePx =>
      (minTextSize + textSize.clamp(0.0, 1.0) * (maxTextSize - minTextSize))
          .round();

  SystemState copyWith({
    Appearance? appearance,
    double? textSize,
    String? focus,
    int? privacyAlerts,
  }) => SystemState(
    account: account,
    appearance: appearance ?? this.appearance,
    textSize: textSize ?? this.textSize,
    focus: focus ?? this.focus,
    privacyAlerts: privacyAlerts ?? this.privacyAlerts,
  );
}

/// One optional access Halo can be given (notifications, calendar, ...). All
/// are optional: without one, the screen it feeds still works.
class AccessGrant {
  const AccessGrant({
    required this.id,
    required this.title,
    required this.detail,
    required this.granted,
  });

  final String id;
  final String title;

  /// What it is for (`Stream and Switchboard`).
  final String detail;
  final bool granted;

  AccessGrant copyWith({bool? granted}) => AccessGrant(
    id: id,
    title: title,
    detail: detail,
    granted: granted ?? this.granted,
  );
}
