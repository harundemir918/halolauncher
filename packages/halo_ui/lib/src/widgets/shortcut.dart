import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import 'icons.dart';

/// 52 × 52 notch square with an icon (Lock: flashlight, camera).
class HaloShortcut extends StatelessWidget {
  const HaloShortcut({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final HaloIcons icon;

  /// Spoken label (`Flashlight`).
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: halo.surface,
              shape: NotchBorder(
                radius: HaloRadii.notchML,
                side: BorderSide(color: halo.soft),
              ),
            ),
            child: HaloIcon(icon),
          ),
        ),
      ),
    );
  }
}
