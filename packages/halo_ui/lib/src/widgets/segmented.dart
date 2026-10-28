import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';
import 'tap_target.dart';

/// One option of a [HaloSegmented].
class HaloSegment<T> {
  const HaloSegment(this.value, this.label);

  final T value;
  final String label;
}

/// Equal-width options, 40 high. The selected one is Volt with the notch.
class HaloSegmented<T> extends StatelessWidget {
  const HaloSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<HaloSegment<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _option(context, options[i])),
        ],
      ],
    );
  }

  Widget _option(BuildContext context, HaloSegment<T> o) {
    final halo = context.halo;
    final selected = o.value == value;
    // 40 high as designed, with a 48 touch target.
    return HaloTapTarget(
      properties: SemanticsProperties(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        enabled: onChanged != null,
        label: o.label,
        onTap: onChanged == null ? null : () => onChanged!(o.value),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(o.value),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: selected ? halo.signalFill : null,
            shape: NotchBorder(
              radius: selected ? HaloRadii.notchSM : HaloRadii.flatS,
              side: selected ? halo.fillSide : BorderSide(color: halo.outline),
            ),
          ),
          child: Text(
            HaloType.upper(o.label),
            style: (selected ? HaloType.segmentSelected : HaloType.segment)
                .copyWith(color: selected ? halo.onSignal : halo.text),
          ),
        ),
      ),
    );
  }
}
