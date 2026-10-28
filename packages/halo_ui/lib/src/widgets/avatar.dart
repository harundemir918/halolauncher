import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';
import 'tap_target.dart';

/// 44 × 44 notch with the account initials. Circles are for apps only, so the
/// avatar is a notch, not a circle.
class HaloAvatar extends StatelessWidget {
  const HaloAvatar({
    super.key,
    required this.initials,
    required this.label,
    required this.onPressed,
  });

  final String initials;

  /// Spoken label (`Account: Avery Stone`).
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    // 44 as designed, with a 48 touch target.
    return HaloTapTarget(
      properties: SemanticsProperties(
        button: true,
        label: label,
        onTap: onPressed,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: halo.surface,
            shape: NotchBorder(
              radius: HaloRadii.notchAvatar,
              side: BorderSide(color: halo.outline),
            ),
          ),
          child: Text(
            HaloType.upper(initials),
            style: HaloType.avatar.copyWith(color: halo.text),
          ),
        ),
      ),
    );
  }
}
