import 'package:flutter/widgets.dart';

import '../palette.dart';

/// 2 px track with a Volt fill and a Volt rounded-rectangle knob (14 × 20).
/// [value] runs from 0 to 1. The label row (name and mono value) is the
/// caller's.
class HaloSlider extends StatelessWidget {
  const HaloSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.semanticValue,
    this.step = 0.05,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final String? semanticLabel;

  /// Spoken value, such as "16". Defaults to a percentage.
  final String? semanticValue;

  /// Change applied by accessibility increase and decrease actions.
  final double step;

  static const double _knobWidth = 14;

  void _set(double v) => onChanged?.call(v.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final halo = context.halo;
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: semanticValue ?? '${(v * 100).round()}%',
      increasedValue: '${((v + step).clamp(0.0, 1.0) * 100).round()}%',
      decreasedValue: '${((v - step).clamp(0.0, 1.0) * 100).round()}%',
      enabled: onChanged != null,
      onIncrease: onChanged == null ? null : () => _set(v + step),
      onDecrease: onChanged == null ? null : () => _set(v - step),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            void fromDx(double dx) => _set(w <= 0 ? 0 : dx / w);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => fromDx(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => fromDx(d.localPosition.dx),
              child: SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 11,
                      height: 2,
                      child: ColoredBox(color: halo.sliderTrack),
                    ),
                    Positioned(
                      left: 0,
                      width: w * v,
                      top: 11,
                      height: 2,
                      child: ColoredBox(color: halo.sliderFill),
                    ),
                    Positioned(
                      left: w * v - _knobWidth / 2,
                      top: 2,
                      width: _knobWidth,
                      height: 20,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: halo.signalFill,
                          border: halo.fillEdge == null
                              ? null
                              : Border.all(color: halo.fillEdge!),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
