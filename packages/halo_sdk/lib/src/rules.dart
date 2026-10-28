import 'models.dart';

// Halo's rules: what a backend derives from the phone's data. No AI, no
// model, just these (docs/DECISIONS.md D-012).

/// The first timed event that hasn't started yet, if any. All-day events
/// have no "in 19 min", so they are never next.
CalendarEvent? nextEventIn(List<CalendarEvent> agenda, DateTime now) {
  for (final e in agenda) {
    if (!e.allDay && !e.start.isBefore(now)) return e;
  }
  return null;
}

/// How much a notification matters, lowest first (D-030). People come before
/// apps and starred people before other people. With Focus on, what isn't a
/// person is held back: it still shows in Stream but never asks for the user.
enum Priority { starred, person, app, held }

Priority priorityOf(HaloNotification n, {bool focus = false}) {
  if (n.starred) return Priority.starred;
  if (n.fromPerson || n.kind == NotificationKind.missedCall) {
    return Priority.person;
  }
  return focus ? Priority.held : Priority.app;
}

/// An event this close is something the user is about to need.
const eventSoon = Duration(hours: 1);

/// Stream's summary: how many are new, how many Halo has read through, and
/// what needs the user, most important first: replies waiting, missed calls
/// and an event about to start. [focus] holds back what isn't a person.
StreamSummary summaryOf(
  List<HaloNotification> notifications, {
  List<CalendarEvent> agenda = const [],
  DateTime? now,
  bool focus = false,
}) {
  final unread = notifications.where((n) => n.unread).toList();
  // (rank, line): starred 0, event soon 1, people 2, apps 3.
  final needs = <(int, String)>[];
  for (final n in unread) {
    final p = priorityOf(n, focus: focus);
    if (p == Priority.held) continue;
    final rank = switch (p) {
      Priority.starred => 0,
      Priority.person => 2,
      _ => 3,
    };
    if (n.kind == NotificationKind.missedCall) {
      needs.add((rank, 'Call back ${n.sender}'));
    } else if (n.canReply) {
      needs.add((rank, 'Reply to ${n.sender}'));
    } else if (n.fromPerson) {
      // A person wrote, and the app offers no reply: it can be opened.
      needs.add((rank, 'Read ${n.sender}'));
    }
  }
  final e = now == null ? null : nextEventIn(agenda, now);
  if (e != null && now != null && e.start.difference(now) <= eventSoon) {
    final m = e.minutesUntil(now);
    needs.add((1, m < 1 ? '${e.title} now' : '${e.title} in $m min'));
  }
  // Dart's sort isn't stable, so order ties by where they came from.
  final order = [for (var i = 0; i < needs.length; i++) i]
    ..sort((a, b) {
      final c = needs[a].$1.compareTo(needs[b].$1);
      return c != 0 ? c : a.compareTo(b);
    });
  return StreamSummary(
    newCount: unread.length,
    read: notifications.length - unread.length,
    needYou: [for (final i in order) needs[i].$2],
  );
}

/// Lock's previews: the newest two unread, else the newest two.
List<HaloNotification> previewsOf(List<HaloNotification> notifications) {
  final unread = notifications.where((n) => n.unread).toList();
  return (unread.isNotEmpty ? unread : notifications).take(2).toList();
}

/// The message Home offers: among unread messages that can be replied to or
/// that come from a person (then it is opened, not answered), the most
/// important, then the newest (the list is newest first). A missed call and
/// what an app posts without a person behind it and without a reply are not
/// messages.
HaloNotification? topMessageOf(
  List<HaloNotification> notifications, {
  bool focus = false,
}) {
  HaloNotification? best;
  for (final n in notifications) {
    if (!n.unread || n.kind == NotificationKind.missedCall) continue;
    if (!n.canReply && !n.fromPerson) continue;
    final p = priorityOf(n, focus: focus);
    if (p == Priority.held) continue;
    if (best == null || p.index < priorityOf(best, focus: focus).index) {
      best = n;
    }
  }
  return best;
}

/// What Home's NOW block shows: the next event, else the top message, else
/// nothing ("Clear for the day").
sealed class NowPick {
  const NowPick();
}

class NowEvent extends NowPick {
  const NowEvent(this.event);
  final CalendarEvent event;
}

class NowMessage extends NowPick {
  const NowMessage(this.message);
  final HaloNotification message;
}

class NowClear extends NowPick {
  const NowClear();
}

NowPick nowPickOf({
  required List<CalendarEvent> agenda,
  required List<HaloNotification> notifications,
  required DateTime now,
  bool focus = false,
}) {
  final e = nextEventIn(agenda, now);
  if (e != null) return NowEvent(e);
  final m = topMessageOf(notifications, focus: focus);
  if (m != null) return NowMessage(m);
  return const NowClear();
}
