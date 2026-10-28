import 'app_search.dart';
import 'models.dart';

// Ask Halo's commands: typed into the search field and answered by rules, no
// model (docs/DECISIONS.md D-012, D-027, D-030).

/// What a typed query asks Halo to do or tell.
sealed class AskCommand {
  const AskCommand();
}

/// "next": the next event today.
class AskNext extends AskCommand {
  const AskNext();
}

/// "battery": the charge.
class AskBattery extends AskCommand {
  const AskBattery();
}

/// "dark", "light": set the appearance.
class AskAppearance extends AskCommand {
  const AskAppearance(this.appearance);
  final Appearance appearance;
}

/// "focus", "focus on", "focus off". [on] is null for a plain toggle.
class AskFocus extends AskCommand {
  const AskFocus(this.on);
  final bool? on;
}

/// "reply Elif on my way": send [text] to [to]. [text] is empty until typed.
class AskReply extends AskCommand {
  const AskReply(this.to, this.text);
  final HaloNotification to;
  final String text;
}

/// The command a query means, or null when it is an ordinary search. A
/// one-word command matches from its third letter ("bat"), so it shows while
/// the user types.
AskCommand? parseAsk(
  String query, {
  List<HaloNotification> notifications = const [],
}) {
  final tokens = query.trim().split(RegExp(r'\s+'));
  if (tokens.first.isEmpty) return null;
  final words = [for (final t in tokens) foldForSearch(t)];
  final head = words.first;

  bool word(String keyword) =>
      words.length == 1 && head.length >= 3 && keyword.startsWith(head);

  if (word('next') ||
      (words.length == 2 && head == 'next' && words[1] == 'event')) {
    return const AskNext();
  }
  if (word('battery')) return const AskBattery();
  if (word('dark')) return const AskAppearance(Appearance.dark);
  if (word('light')) return const AskAppearance(Appearance.light);
  if (head.length >= 3 && 'focus'.startsWith(head) && words.length <= 2) {
    if (words.length == 1) return const AskFocus(null);
    return switch (words[1]) {
      'on' => const AskFocus(true),
      'off' => const AskFocus(false),
      _ => null,
    };
  }
  if (head == 'reply' && words.length > 1) {
    return _reply(tokens, words, notifications);
  }
  return null;
}

/// "reply" then a name (a sender's full name or first name) then the text.
/// With only a start of a name typed, it still points at that sender.
AskCommand? _reply(
  List<String> tokens,
  List<String> words,
  List<HaloNotification> notifications,
) {
  final rest = words.sublist(1);
  HaloNotification? best;
  var bestLength = 0;
  for (final n in notifications) {
    if (!n.canReply) continue;
    final name = [
      for (final w in n.sender.trim().split(RegExp(r'\s+'))) foldForSearch(w),
    ];
    // The full name, else the first name.
    for (final candidate in [name, name.sublist(0, 1)]) {
      if (candidate.length > rest.length) continue;
      var match = true;
      for (var i = 0; i < candidate.length; i++) {
        if (candidate[i] != rest[i]) match = false;
      }
      if (match && candidate.length > bestLength) {
        best = n;
        bestLength = candidate.length;
      }
    }
  }
  if (best != null) {
    return AskReply(best, tokens.sublist(1 + bestLength).join(' '));
  }
  // Still typing the name.
  if (rest.length == 1) {
    for (final n in notifications) {
      if (n.canReply && foldForSearch(n.sender).startsWith(rest.first)) {
        return AskReply(n, '');
      }
    }
  }
  return null;
}
