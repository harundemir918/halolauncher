import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
import '../format.dart';
import '../status_bar.dart';

/// Stream: one timeline with time as the spine, and Halo's summary on top.
///
/// Tap an item to open it, swipe it sideways to clear it from the phone.
/// REPLY opens a reply field under the item, LATER puts it away for an hour.
/// Without notification access, Stream explains and asks for it.
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key, required this.backend, this.replyTo});

  final HaloBackend backend;

  /// A notification whose reply field starts open (Home's action card).
  final String? replyTo;

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late String? _replying = widget.replyTo;
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(HaloNotification n) async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final sent = await widget.backend.replyToNotification(n.id, text);
    if (!mounted || !sent) return;
    setState(() {
      _replying = null;
      _reply.clear();
    });
  }

  Widget _item(HaloNotification n, DateTime now, {required double gapBefore}) {
    final b = widget.backend;
    final halo = context.halo;
    final replying = _replying == n.id;
    final item = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => b.openNotification(n.id),
      child: HaloTimelineItem(
        mark: switch (n.mark) {
          StreamMark.current => HaloMark.current,
          StreamMark.alert => HaloMark.alert,
          StreamMark.read => HaloMark.read,
        },
        source: n.source ?? n.sender,
        time: HaloFormat.streamTime(n.receivedAt, now),
        body: n.body,
        gapBefore: gapBefore,
        actions: [
          if (n.canReply) ...[
            HaloTextAction(
              'Reply',
              color: halo.signalText,
              onPressed: () => setState(() {
                _replying = replying ? null : n.id;
                _reply.clear();
              }),
            ),
            HaloTextAction(
              'Later',
              onPressed: () => b.snoozeNotification(n.id),
            ),
          ],
          // The app's own actions (Mark as read, Archive…), at most two so
          // the item stays calm.
          for (final a in n.actions.take(2))
            HaloTextAction(
              a.label,
              onPressed: () => b.runNotificationAction(n.id, a.id),
            ),
        ],
      ),
    );
    final withReply = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        item,
        if (replying)
          Padding(
            // Under the item's text, clear of the spine.
            padding: const EdgeInsets.only(left: 30, top: 10),
            child: HaloCommandField(
              key: ValueKey('reply-${n.id}'),
              placeholder: 'reply to ${n.sender}',
              controller: _reply,
              autofocus: true,
              onSubmitted: (_) => _send(n),
            ),
          ),
      ],
    );
    if (!n.canDismiss) return withReply;
    return Dismissible(
      key: ValueKey('stream-${n.id}'),
      onDismissed: (_) => b.dismissNotification(n.id),
      child: withReply,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: widget.backend,
      builder: (context, b) {
        final halo = context.halo;
        final summary = b.streamSummary;
        final now = b.now;
        final all = b.notifications;
        final inPlay = all.where((n) => n.mark != StreamMark.read).toList();
        final earlier = all.where((n) => n.mark == StreamMark.read).toList();

        return ColoredBox(
          color: halo.ground,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ShellStatusBar(backend: b),
              ),
              Positioned(
                top: 54,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stream',
                      style: HaloType.screenTitle.copyWith(color: halo.text),
                    ),
                    if (summary.newCount > 0)
                      HaloChip('${summary.newCount} new'),
                  ],
                ),
              ),
              if (!b.canReadNotifications)
                Positioned(
                  top: 116,
                  left: HaloSpace.gutter,
                  right: HaloSpace.gutter,
                  child: _AccessAsk(onAllow: b.requestNotificationAccess),
                )
              else ...[
                Positioned(
                  top: 116,
                  left: HaloSpace.gutter,
                  right: HaloSpace.gutter,
                  child: HaloSummaryCard(
                    kicker:
                        'Halo read ${summary.read} '
                        '${summary.read == 1 ? 'thing' : 'things'} for you',
                    headline: '${summary.needYou.length} need you.',
                    items: summary.needYou,
                  ),
                ),
                Positioned(
                  top: 338,
                  left: HaloSpace.gutter,
                  right: HaloSpace.gutter,
                  bottom: 0,
                  child: all.isEmpty
                      ? Text(
                          HaloType.upper('Nothing here'),
                          style: HaloType.kicker.copyWith(color: halo.muted),
                        )
                      : SingleChildScrollView(
                          child: HaloTimeline(
                            children: [
                              if (inPlay.isNotEmpty) ...[
                                const HaloTimelineSection('Now'),
                                for (var i = 0; i < inPlay.length; i++)
                                  _item(
                                    inPlay[i],
                                    now,
                                    gapBefore: i == 0 ? 4 : 20,
                                  ),
                              ],
                              if (earlier.isNotEmpty) ...[
                                HaloTimelineSection(
                                  'Earlier',
                                  gapBefore: inPlay.isEmpty ? 0 : 24,
                                ),
                                for (var i = 0; i < earlier.length; i++)
                                  _item(
                                    earlier[i],
                                    now,
                                    gapBefore: i == 0 ? 4 : 20,
                                  ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Without notification access: what Stream does, that it stays on the
/// phone, and the one way to allow it (CLAUDE.md rules 5 and 6).
class _AccessAsk extends StatelessWidget {
  const _AccessAsk({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every notification\nin one timeline.',
          style: HaloType.headline.copyWith(color: halo.text),
        ),
        const SizedBox(height: 14),
        Text(
          HaloType.upper(
            'Halo needs notification access. Nothing leaves this '
            'phone.',
          ),
          style: HaloType.context.copyWith(color: halo.muted),
        ),
        const SizedBox(height: 18),
        HaloButton(
          key: const ValueKey('notification-access'),
          label: 'Allow access',
          onPressed: onAllow,
        ),
      ],
    );
  }
}
