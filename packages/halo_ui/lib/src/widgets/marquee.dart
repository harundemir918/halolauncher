import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One line of text. When it fits it just sits; when it is wider than its
/// space it waits, slides to its end, waits, slides back, and goes on, so the
/// whole of it can be read. With Android's "Remove animations" it stays still
/// and ends in an ellipsis instead.
class HaloMarquee extends StatefulWidget {
  const HaloMarquee(
    this.text, {
    super.key,
    required this.style,
    this.pause = const Duration(milliseconds: 1500),
    this.speed = 36,
  });

  final String text;
  final TextStyle style;

  /// How long it rests at each end.
  final Duration pause;

  /// Logical pixels per second on the way out; it comes back three times
  /// faster.
  final double speed;

  @override
  State<HaloMarquee> createState() => _HaloMarqueeState();
}

class _HaloMarqueeState extends State<HaloMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// How far past its space the text runs, as last measured; -1 until then.
  double _overflow = -1;

  @override
  void didUpdateWidget(HaloMarquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) {
      // A new title starts from its beginning.
      _overflow = -1;
      _c.reset();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Duration get _out =>
      Duration(microseconds: (_overflow / widget.speed * 1e6).round());
  Duration get _back => Duration(
    microseconds: math.max(
      350000,
      (_overflow / (widget.speed * 3) * 1e6).round(),
    ),
  );
  Duration get _total => widget.pause * 2 + _out + _back;

  /// The text's offset to the left, 0 to the overflow, at [t] of a cycle.
  double _offset(double t) {
    final at = t * _total.inMicroseconds;
    final pause = widget.pause.inMicroseconds;
    final out = _out.inMicroseconds;
    final back = _back.inMicroseconds;
    if (at < pause) return 0;
    if (at < pause + out) {
      return _overflow * Curves.easeInOutSine.transform((at - pause) / out);
    }
    if (at < 2 * pause + out) return _overflow;
    final b = ((at - 2 * pause - out) / back).clamp(0.0, 1.0);
    return _overflow * (1 - Curves.easeInOutSine.transform(b));
  }

  void _sync(double overflow) {
    if (!mounted) return;
    if (overflow <= 0.5) {
      _overflow = 0;
      _c.stop();
      return;
    }
    if ((overflow - _overflow).abs() > 0.5 || !_c.isAnimating) {
      _overflow = overflow;
      _c
        ..duration = _total
        ..repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final line = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final overflow = reduced || !box.maxWidth.isFinite
            ? 0.0
            : line.width - box.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync(overflow));
        if (overflow <= 0.5) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        return SizedBox(
          height: line.height,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) => OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-_offset(_c.value), 0),
                  child: child,
                ),
              ),
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }
}
