import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';

/// Square-knob switch. 44 × 24 track inside a 44 × 44 touch target.
///
/// On: signal track, knob on the right. Off: outlined track, ash knob on
/// the left. See docs/DESIGN_SYSTEM.md §6.
class HaloSwitch extends StatelessWidget {
  const HaloSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ExcludeSemantics(
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 44,
                height: 24,
                // The knob sits 4 px from the edge either way. Off has a 1 px
                // border, so it needs 3 px of padding inside it.
                padding: EdgeInsets.symmetric(horizontal: value ? 4 : 3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? halo.switchOnTrack : null,
                  borderRadius: HaloRadii.flatS,
                  border: value ? null : Border.all(color: halo.switchOff),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? halo.switchOnKnob : halo.muted,
                    borderRadius: HaloRadii.knob,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
