import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../app_icons.dart';
import '../format.dart';
import '../status_bar.dart';

/// Home: what matters now at the top, the apps on an arc in thumb reach.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.backend,
    required this.onLaunch,
    this.onLongPress,
    this.onAsk,
    this.onReply,
    this.onAddToArc,
    this.focusAppId,
  });

  final HaloBackend backend;

  /// Called with the app id when the focused app is tapped.
  final ValueChanged<String> onLaunch;

  /// A long press on an app on the arc (its menu).
  final ValueChanged<HaloAppInfo>? onLongPress;

  /// A plus slot at the start (true) or the end (false) of the arc was tapped:
  /// pick an app to add there. Without it the arc has no plus slots.
  final ValueChanged<bool>? onAddToArc;

  /// The app the arc starts on, such as the one just added.
  final String? focusAppId;

  /// Ask Halo was tapped: open search (D-027).
  final VoidCallback? onAsk;

  /// Reply was tapped on the action card: open Stream with that
  /// notification's reply field.
  final ValueChanged<String>? onReply;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Null until the arc has apps: right after an install the app list can
  /// arrive in pieces, and the start focus must come from the full arc.
  int? _focused;

  /// The "make Halo your home screen" card was put off for this session.
  bool _defaultHomeLater = false;

  /// Start on the app with something unread, else the middle of the arc.
  int _initialFocus() {
    final apps = widget.backend.arcApps;
    final wanted = apps.indexWhere((a) => a.id == widget.focusAppId);
    if (wanted >= 0) return wanted;
    final unread = widget.backend.notifications
        .where((n) => n.unread)
        .map((n) => n.app)
        .toSet();
    final i = apps.indexWhere((a) => unread.contains(a.id));
    return i >= 0 ? i : apps.length ~/ 2;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.backend;
    final now = b.now;
    final event = b.nextEvent;
    final unreadApps = b.notifications
        .where((n) => n.unread)
        .map((n) => n.app)
        .toSet();
    final focus = b.quick.focus;
    // The next event, else the top message, else clear (D-012, D-030).
    final pick = event != null
        ? NowEvent(event)
        : nowPickOf(
            agenda: const [],
            notifications: b.notifications,
            now: now,
            focus: focus,
          );
    // The top message (people before apps). NOW shows it when there is no
    // event, so the card below would only repeat it.
    final ask = pick is NowMessage
        ? null
        : topMessageOf(b.notifications, focus: focus);
    // Apps come and go (installs, removals), so keep the focus on the arc.
    final arc = b.arcApps;
    if (arc.isNotEmpty) _focused ??= _initialFocus();
    // A full arc has none (D-034). With plus slots the arc also rotates to one before the first app and
    // one after the last; with no apps only the end slot is there.
    final canAdd = widget.onAddToArc != null && arc.length < maxArcApps;
    final focused = arc.isEmpty
        ? 0
        : _focused!.clamp(canAdd ? -1 : 0, arc.length - (canAdd ? 0 : 1));

    return ColoredBox(
      color: context.halo.ground,
      child: Stack(
        children: [
          Positioned.fill(
            child: HaloArc(
              apps: [
                for (final a in arc)
                  HaloArcApp(
                    id: a.id,
                    label: a.label,
                    icon: iconFor(a),
                    // The user's default apps are drawn with the design's
                    // glyphs; the rest with their monochrome icons (D-025).
                    image: a.glyph == null ? imageFor(a) : null,
                    monoImage: a.glyph == null ? monoImageFor(a) : null,
                    unread: unreadApps.contains(a.id),
                  ),
              ],
              focusedIndex: focused,
              onFocus: (i) => setState(() => _focused = i),
              onLaunch: (app) => widget.onLaunch(app.id),
              // Dragging an app to another place on the arc.
              onReorder: (app, to) => b.moveOnArc(
                app.id,
                to - arc.indexWhere((a) => a.id == app.id),
              ),
              onAddStart: canAdd ? () => widget.onAddToArc!(true) : null,
              onAddEnd: canAdd ? () => widget.onAddToArc!(false) : null,
              onLongPress: widget.onLongPress == null
                  ? null
                  : (app) => widget.onLongPress!(
                      arc.firstWhere((a) => a.id == app.id),
                    ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ShellStatusBar(backend: b),
          ),
          Positioned(
            top: 58,
            left: HaloSpace.gutter,
            right: HaloSpace.gutter,
            child: _Now(
              pick: pick,
              now: now,
              backend: b,
              onReply: widget.onReply,
            ),
          ),
          Positioned(
            top: 290,
            left: HaloSpace.gutter,
            right: HaloSpace.gutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Without events there is no TODAY: "Clear for the day" says it.
                // Without calendar access, TODAY asks for it.
                if (b.agenda.isNotEmpty || !b.canReadCalendar) ...[
                  HaloKicker('Today', color: context.halo.muted, square: false),
                  const SizedBox(height: 10),
                ],
                if (!b.canReadCalendar)
                  HaloResultRow(
                    key: const ValueKey('calendar-allow'),
                    title: "Show today's events",
                    caption: 'Allow',
                    captionSignal: true,
                    onTap: b.requestCalendarAccess,
                  ),
                for (final e in b.agenda)
                  HaloAgendaRow(
                    time: e.allDay
                        ? HaloType.upper('All day')
                        : HaloFormat.clock(e.start),
                    title: e.title,
                    trailing: e.location,
                    current: identical(e, event) || e.start == event?.start,
                  ),
              ],
            ),
          ),
          if (!b.isDefaultHome && !_defaultHomeLater)
            Positioned(
              // 508 from the top on the 844 design; anchored to the arc so it
              // never overlaps it on shorter safe areas.
              bottom: 244,
              left: HaloSpace.gutter,
              right: HaloSpace.gutter,
              child: HaloActionCard(
                sender: 'Halo',
                age: 'Setup',
                message: 'Set Halo as home?',
                onYes: b.requestDefaultHome,
                onLater: () => setState(() => _defaultHomeLater = true),
              ),
            )
          else if (ask != null)
            Positioned(
              // 508 from the top on the 844 design; anchored to the arc so it
              // never overlaps it on shorter safe areas.
              bottom: 244,
              left: HaloSpace.gutter,
              right: HaloSpace.gutter,
              child: HaloActionCard(
                sender: ask.sender,
                age: ask.age(now),
                // The designs' card answers a question with Yes; a real
                // message gets Reply, which opens it in Stream.
                message: ask.actionPrompt ?? ask.body,
                // The designs' Yes answers a question; a message gets Reply,
                // which opens it in Stream; one the app lets nobody answer
                // from here gets Open.
                yesLabel: ask.actionPrompt != null
                    ? 'Yes'
                    : ask.canReply
                    ? 'Reply'
                    : 'Open',
                onYes: ask.actionPrompt != null
                    ? () => b.replyToNotification(ask.id, 'Yes')
                    : ask.canReply
                    ? () => widget.onReply?.call(ask.id)
                    : () => b.openNotification(ask.id),
                onLater: () => b.snoozeNotification(ask.id),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: SizedBox(
                width: 150,
                child: HaloButton(
                  label: 'Ask Halo',
                  variant: HaloButtonVariant.secondary,
                  leading: SizedBox(
                    width: 8,
                    height: 8,
                    child: ColoredBox(color: context.halo.signalLine),
                  ),
                  // Tap: search apps, people and settings. Long press: the
                  // system assistant, if the user has one (D-027).
                  onPressed: widget.onAsk,
                  onLongPress: b.openAssistant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The `NOW` block: kicker, headline, context line and two actions.
class _Now extends StatelessWidget {
  const _Now({
    required this.pick,
    required this.now,
    required this.backend,
    required this.onReply,
  });

  final NowPick pick;
  final DateTime now;
  final HaloBackend backend;
  final ValueChanged<String>? onReply;

  @override
  Widget build(BuildContext context) {
    final e = switch (pick) {
      NowEvent(:final event) => event,
      _ => null,
    };
    final m = switch (pick) {
      NowMessage(:final message) => message,
      _ => null,
    };
    final minutes = e?.minutesUntil(now);
    // The headline is two lines: what, and when (or who, and what).
    final (top, bottom) = e != null
        ? (
            e.title,
            minutes! < 60
                ? 'in $minutes min'
                : 'at ${HaloFormat.clock(e.start)}',
          )
        : m != null
        ? (m.sender, 'wrote you')
        : ('Clear for', 'the day');
    final context_ = e != null
        ? [
            e.location,
            if (e.walkMinutes != null) '${e.walkMinutes} min walk',
            if (e.attendees != null) '${e.attendees} people',
          ].join(' · ')
        : m?.body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HaloKicker('Now'),
        const SizedBox(height: 14),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A long title shrinks to fit its line, and past that ends in an
              // ellipsis: the headline stays two lines whatever it says.
              _FitLine(
                top,
                style: HaloType.headlineL.copyWith(color: context.halo.text),
              ),
              _FitLine(
                bottom,
                style: HaloType.headlineL.copyWith(color: context.halo.text),
              ),
            ],
          ),
        ),
        if (context_ != null && context_.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            HaloType.upper(context_),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HaloType.context.copyWith(color: context.halo.muted),
          ),
        ],
        if (m != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              // Without a reply action (the app offers none) the message is
              // opened in its app instead.
              if (m.canReply)
                HaloButton(label: 'Reply', onPressed: () => onReply?.call(m.id))
              else
                HaloButton(
                  label: 'Open',
                  onPressed: () => backend.openNotification(m.id),
                ),
              const SizedBox(width: 8),
              HaloButton(
                label: 'Later',
                variant: HaloButtonVariant.secondary,
                onPressed: () => backend.snoozeNotification(m.id),
              ),
            ],
          ),
        ],
        if (e != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              // Navigate needs a place to go to.
              if (e.location.trim().isNotEmpty) ...[
                HaloButton(
                  label: 'Navigate',
                  onPressed: () => backend.openMap(e.location),
                ),
                const SizedBox(width: 8),
              ],
              // A phone event opens in the calendar app; the designs' fixture
              // keeps its "Open notes".
              if (e.id case final id?)
                HaloButton(
                  label: 'Open event',
                  variant: HaloButtonVariant.secondary,
                  onPressed: () => backend.openEvent(id),
                )
              else
                HaloButton(
                  label: 'Open notes',
                  variant: HaloButtonVariant.secondary,
                  onPressed: () {},
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One line of headline type that shrinks to fit its width, down to 60%, and
/// then ends in an ellipsis. It keeps the height of its line at full size, so
/// whatever is under it doesn't move.
class _FitLine extends StatelessWidget {
  const _FitLine(this.text, {required this.style});

  final String text;
  final TextStyle style;

  static const _smallest = 0.6;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize!;
    return LayoutBuilder(
      builder: (context, box) {
        final line = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fit = line.width <= box.maxWidth
            ? 1.0
            : (box.maxWidth / line.width).clamp(_smallest, 1.0);
        return SizedBox(
          height: size * (style.height ?? 1),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(fontSize: size * fit),
            ),
          ),
        );
      },
    );
  }
}
