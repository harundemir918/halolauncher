import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
import '../format.dart';
import '../status_bar.dart';

/// Stream: one timeline with time as the spine, and Halo's summary on top.
class StreamScreen extends StatelessWidget {
  const StreamScreen({super.key, required this.backend});

  final HaloBackend backend;

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: backend,
      builder: (context, b) {
        final summary = b.streamSummary;
        final now = b.now;
        final all = b.notifications;
        final inPlay = all.where((n) => n.mark != StreamMark.read).toList();
        final earlier = all.where((n) => n.mark == StreamMark.read).toList();

        Widget item(HaloNotification n, {required double gapBefore}) =>
            HaloTimelineItem(
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
                    color: context.halo.signalText,
                    onPressed: () {},
                  ),
                  HaloTextAction('Later', onPressed: () {}),
                ],
              ],
            );

        return ColoredBox(
          color: context.halo.ground,
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
                      style: HaloType.screenTitle.copyWith(
                        color: context.halo.text,
                      ),
                    ),
                    if (summary.newCount > 0)
                      HaloChip('${summary.newCount} new'),
                  ],
                ),
              ),
              Positioned(
                top: 116,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: HaloSummaryCard(
                  kicker: 'Halo read ${summary.read} things for you',
                  headline: '${summary.needYou.length} need you.',
                  items: summary.needYou,
                ),
              ),
              Positioned(
                top: 338,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                bottom: 0,
                child: SingleChildScrollView(
                  child: HaloTimeline(
                    children: [
                      if (inPlay.isNotEmpty) ...[
                        const HaloTimelineSection('Now'),
                        for (var i = 0; i < inPlay.length; i++)
                          item(inPlay[i], gapBefore: i == 0 ? 4 : 20),
                      ],
                      if (earlier.isNotEmpty) ...[
                        HaloTimelineSection(
                          'Earlier',
                          gapBefore: inPlay.isEmpty ? 0 : 24,
                        ),
                        for (var i = 0; i < earlier.length; i++)
                          item(earlier[i], gapBefore: i == 0 ? 4 : 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
