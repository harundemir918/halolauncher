import 'models.dart';

// Halo's rules: what a backend derives from the phone's data. No AI, no
// model, just these (docs/DECISIONS.md D-012).

/// The first event that hasn't started yet, if any.
CalendarEvent? nextEventIn(List<CalendarEvent> agenda, DateTime now) {
  for (final e in agenda) {
    if (!e.start.isBefore(now)) return e;
  }
  return null;
}

/// Stream's summary: how many are new, how many Halo has read through, and
/// what needs the user: unread messages that wait for a reply.
StreamSummary summaryOf(List<HaloNotification> notifications) {
  final unread = notifications.where((n) => n.unread).toList();
  return StreamSummary(
    newCount: unread.length,
    read: notifications.length - unread.length,
    needYou: [
      for (final n in unread)
        if (n.canReply) 'Reply to ${n.sender}',
    ],
  );
}

/// Lock's previews: the newest two unread, else the newest two.
List<HaloNotification> previewsOf(List<HaloNotification> notifications) {
  final unread = notifications.where((n) => n.unread).toList();
  return (unread.isNotEmpty ? unread : notifications).take(2).toList();
}

/// The message Home's action card offers: the newest unread one that can be
/// replied to.
HaloNotification? topMessageOf(List<HaloNotification> notifications) {
  for (final n in notifications) {
    if (n.unread && n.canReply) return n;
  }
  return null;
}
