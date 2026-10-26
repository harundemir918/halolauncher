import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';

/// One row of the Home `TODAY` agenda: mono time, title, mono trailer.
/// The current item's time is Volt. A hairline runs above the row.
class HaloAgendaRow extends StatelessWidget {
  const HaloAgendaRow({
    super.key,
    required this.time,
    required this.title,
    required this.trailing,
    this.current = false,
  });

  final String time;
  final String title;
  final String trailing;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      container: true,
      label: '$time, $title, $trailing${current ? ', next' : ''}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: halo.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    time,
                    style: HaloType.timeLabel.copyWith(
                      color: current ? halo.signalText : halo.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.itemTitle.copyWith(color: halo.text),
                  ),
                ),
                Text(
                  HaloType.upper(trailing),
                  style: HaloType.meta.copyWith(color: halo.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
