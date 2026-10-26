import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// Small Volt chip with a mono label (`4 NEW`).
class HaloChip extends StatelessWidget {
  const HaloChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: ShapeDecoration(
        color: halo.chipFill,
        shape: const NotchBorder(radius: HaloRadii.notchXS),
      ),
      child: Text(
        HaloType.upper(label),
        style: HaloType.chip.copyWith(color: halo.chipText),
      ),
    );
  }
}
