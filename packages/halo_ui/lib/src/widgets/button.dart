import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

enum HaloButtonVariant {
  /// Volt fill, carbon text. The one primary action.
  primary,

  /// Transparent with a `line22` outline, bone text.
  secondary,

  /// Bone fill, carbon text (the inline "Yes").
  bone,
}

enum HaloButtonSize {
  /// 44 high.
  regular,

  /// 32 high, for inline actions.
  small,
}

/// Notch button. See docs/DESIGN_SYSTEM.md §6.
class HaloButton extends StatelessWidget {
  const HaloButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HaloButtonVariant.primary,
    this.size = HaloButtonSize.regular,
    this.leading,
    this.trailing,
    this.onLongPress,
  });

  final String label;
  final VoidCallback? onPressed;

  /// A second action on a long press (Ask Halo: the system assistant).
  final VoidCallback? onLongPress;
  final HaloButtonVariant variant;
  final HaloButtonSize size;

  /// Optional widget before the label (Ask Halo's Volt square).
  final Widget? leading;

  /// Optional widget after the label (a chevron for "opens another screen").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final small = size == HaloButtonSize.small;
    final outlined = variant == HaloButtonVariant.secondary;
    final style = switch ((small, outlined)) {
      (false, false) => HaloType.button,
      (false, true) => HaloType.buttonLight,
      (true, false) => HaloType.buttonSmall,
      (true, true) => HaloType.buttonSmallLight,
    };
    final halo = context.halo;
    final fill = switch (variant) {
      HaloButtonVariant.primary => halo.signalFill,
      HaloButtonVariant.secondary => null,
      HaloButtonVariant.bone => halo.yesFill,
    };
    final textColor = switch (variant) {
      HaloButtonVariant.primary => halo.onSignal,
      HaloButtonVariant.secondary => halo.text,
      HaloButtonVariant.bone => halo.yesText,
    };

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Container(
            height: small ? 32 : 44,
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
            decoration: ShapeDecoration(
              color: fill,
              shape: NotchBorder(
                radius: small ? HaloRadii.notchS : HaloRadii.notchM,
                side: outlined
                    ? BorderSide(color: halo.outline)
                    : variant == HaloButtonVariant.primary
                    ? halo.fillSide
                    : BorderSide.none,
              ),
            ),
            // widthFactor keeps the button as wide as its label.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Text(label, style: style.copyWith(color: textColor)),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
