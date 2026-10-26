import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// Command field: a Volt `>` prompt, a mono placeholder and a solid Volt
/// block cursor on a `surface` notch. 48 high.
///
/// For now it only looks like the design and reports taps. Text entry arrives
/// with the on-screen keyboard (ROADMAP Phase 3).
class HaloCommandField extends StatelessWidget {
  const HaloCommandField({
    super.key,
    this.placeholder = 'find a setting',
    this.onTap,
  });

  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      textField: true,
      label: placeholder,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(
              color: halo.surface,
              shape: NotchBorder(
                radius: HaloRadii.notchField,
                side: BorderSide(color: halo.soft),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '>',
                  style: HaloType.command.copyWith(color: halo.signalText),
                ),
                const SizedBox(width: 10),
                Text(
                  placeholder,
                  style: HaloType.command.copyWith(color: halo.muted),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 9,
                  height: 18,
                  child: ColoredBox(color: halo.signalLine),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
