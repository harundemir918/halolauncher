import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';

/// 3 px bar across the very top of every screen: a `line10` track filled with
/// Volt to [fraction] (0 to 1). This is Halo's battery indicator.
class HaloBatteryLine extends StatelessWidget {
  const HaloBatteryLine({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final halo = context.halo;
    return Semantics(
      label: 'Battery ${(f * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 3,
          child: ColoredBox(
            color: halo.track,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: f,
                child: SizedBox(
                  height: 3,
                  child: ColoredBox(color: halo.signalLine),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of [count] cells (10 in the design), 14 high with 4 px gaps. Filled
/// cells are Volt, empty ones `line12`. The boundary cell fills partially.
class HaloBatteryCells extends StatelessWidget {
  const HaloBatteryCells({super.key, required this.fraction, this.count = 10});

  final double fraction;
  final int count;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final halo = context.halo;
    return Semantics(
      label: 'Battery ${(f * 100).round()}%',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _cell(halo, (f * count - i).clamp(0.0, 1.0))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(HaloPalette halo, double fill) {
    return SizedBox(
      height: 14,
      child: ClipRRect(
        borderRadius: HaloRadii.knob,
        child: ColoredBox(
          color: fill >= 1 ? halo.signalLine : halo.cells,
          child: fill > 0 && fill < 1
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fill,
                    heightFactor: 1,
                    child: ColoredBox(color: halo.signalLine),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
