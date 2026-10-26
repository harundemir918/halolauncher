import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';

/// Section kicker: an 8 × 8 square followed by an uppercase mono label.
/// Volt by default (`NOW`). Pass [color] and `square: false` for the plain
/// ash list label (`TODAY`).
class HaloKicker extends StatelessWidget {
  const HaloKicker(this.label, {super.key, this.color, this.square = true});

  final String label;

  /// Defaults to Volt: the signal fill for the square, the signal text color
  /// for the label.
  final Color? color;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (square) ...[
          SizedBox(
            width: 8,
            height: 8,
            child: ColoredBox(color: color ?? halo.signalLine),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          HaloType.upper(label),
          style: HaloType.kicker.copyWith(color: color ?? halo.signalText),
        ),
      ],
    );
  }
}
