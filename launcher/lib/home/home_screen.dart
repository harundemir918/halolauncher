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
  });

  final HaloBackend backend;

  /// Called with the app id when the focused app is tapped.
  final ValueChanged<String> onLaunch;

  /// A long press on an app on the arc (its menu).
  final ValueChanged<HaloAppInfo>? onLongPress;

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
    final ask = b.notifications
        .where((n) => n.unread && n.actionPrompt != null)
        .firstOrNull;
    // Apps come and go (installs, removals), so keep the focus on the arc.
    final arc = b.arcApps;
    if (arc.isNotEmpty) _focused ??= _initialFocus();
    final focused = arc.isEmpty ? 0 : _focused!.clamp(0, arc.length - 1);

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
            child: _Now(event: event, now: now),
          ),
          Positioned(
            top: 290,
            left: HaloSpace.gutter,
            right: HaloSpace.gutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Without events there is no TODAY: "Clear for the day" says it.
                if (b.agenda.isNotEmpty) ...[
                  HaloKicker('Today', color: context.halo.muted, square: false),
                  const SizedBox(height: 10),
                ],
                for (final e in b.agenda)
                  HaloAgendaRow(
                    time: HaloFormat.clock(e.start),
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
                message: ask.actionPrompt!,
                onYes: () {},
                onLater: () {},
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
                  onPressed: () {},
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
  const _Now({required this.event, required this.now});

  final CalendarEvent? event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final minutes = e?.minutesUntil(now);
    final headline = e == null
        ? 'Clear for\nthe day'
        : '${e.title}\n${minutes! < 60 ? 'in $minutes min' : 'at ${HaloFormat.clock(e.start)}'}';
    final context_ = e == null
        ? null
        : [
            e.location,
            if (e.walkMinutes != null) '${e.walkMinutes} min walk',
            if (e.attendees != null) '${e.attendees} people',
          ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HaloKicker('Now'),
        const SizedBox(height: 14),
        Text(
          headline,
          style: HaloType.headlineL.copyWith(color: context.halo.text),
        ),
        if (context_ != null) ...[
          const SizedBox(height: 12),
          Text(
            HaloType.upper(context_),
            style: HaloType.context.copyWith(color: context.halo.muted),
          ),
        ],
        if (e != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              HaloButton(label: 'Navigate', onPressed: () {}),
              const SizedBox(width: 8),
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
