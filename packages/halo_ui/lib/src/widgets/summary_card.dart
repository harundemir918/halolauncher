import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// The Stream summary: a Volt block with a mono kicker, a big sentence and a
/// numbered list. Halo writes it; the user decides what to do.
class HaloSummaryCard extends StatelessWidget {
  const HaloSummaryCard({
    super.key,
    required this.kicker,
    required this.headline,
    required this.items,
  });

  /// Mono line on top (`Halo read 11 things for you`).
  final String kicker;

  /// `3 need you.`
  final String headline;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final ink = halo.onSignal;
    return Semantics(
      container: true,
      label: '$kicker. $headline ${items.join('. ')}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: ShapeDecoration(
            color: halo.signalFill,
            shape: NotchBorder(radius: HaloRadii.notchXXL, side: halo.fillSide),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                HaloType.upper(kicker),
                style: HaloType.label.copyWith(color: ink),
              ),
              const SizedBox(height: 8),
              Text(headline, style: HaloType.displayS.copyWith(color: ink)),
              const SizedBox(height: 14),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        '${i + 1}',
                        style: HaloType.tileTime.copyWith(color: ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i],
                        style: HaloType.summaryItem.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
