import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';
import 'switch.dart';

/// `surface` row with a name, a mono sub-label and a [HaloSwitch].
/// When on, a 3 px Volt bar runs down the left edge. The whole row toggles.
class HaloToggleRow extends StatelessWidget {
  const HaloToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      container: true,
      label: '$title, $subtitle',
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: halo.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: HaloRadii.flat,
                  side: BorderSide(color: halo.border),
                ),
              ),
              child: ClipRRect(
                borderRadius: HaloRadii.flat,
                child: Stack(
                  children: [
                    if (value)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: ColoredBox(color: halo.signalLine),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(19, 0, 5, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: HaloType.rowTitle.copyWith(
                                    color: value ? halo.text : halo.textDim,
                                  ),
                                ),
                                Text(
                                  HaloType.upper(subtitle),
                                  style: HaloType.caption.copyWith(
                                    color: halo.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IgnorePointer(
                            child: HaloSwitch(
                              value: value,
                              onChanged: onChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
