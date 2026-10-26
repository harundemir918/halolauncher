import 'package:flutter/widgets.dart';

/// Lays out [child] on the 390-wide design frame inside the safe area, scaled
/// to the screen's width (docs/DECISIONS.md D-024). The frame's height is
/// whatever the safe area leaves at that scale, so screens anchored to the
/// bottom (the arc) stay in thumb reach on tall phones.
///
/// At 390 wide with no insets (macOS, tests, goldens) this is a no-op.
class DesignFrame extends StatelessWidget {
  const DesignFrame({super.key, required this.child});

  static const double width = 390;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safe = mq.padding.deflateSize(mq.size);
    if (safe.isEmpty) return const SizedBox.shrink();
    final scale = safe.width / width;
    final frame = Size(width, safe.height / scale);
    return Padding(
      padding: mq.padding,
      child: FittedBox(
        alignment: Alignment.topCenter,
        child: SizedBox.fromSize(
          size: frame,
          child: MediaQuery(
            data: mq.copyWith(
              size: frame,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
