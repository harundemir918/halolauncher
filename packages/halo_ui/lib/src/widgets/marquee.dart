import 'package:flutter/widgets.dart';

/// One line of text. When it fits it just sits; when it is wider than its
/// space it rests, then moves left without stopping, coming round again from
/// the right, so the whole of it can be read and it never turns back. With
/// Android's "Remove animations" it stays still and ends in an ellipsis.
class HaloMarquee extends StatefulWidget {
  const HaloMarquee(
    this.text, {
    super.key,
    required this.style,
    this.pause = const Duration(milliseconds: 1500),
    this.speed = 36,
    this.gap = 48,
  });

  final String text;
  final TextStyle style;

  /// How long it rests with its beginning in view, before each round.
  final Duration pause;

  /// Logical pixels per second.
  final double speed;

  /// The space between the end of the text and its beginning coming round.
  final double gap;

  @override
  State<HaloMarquee> createState() => _HaloMarqueeState();
}

class _HaloMarqueeState extends State<HaloMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// How far past its space the text runs, as last measured; -1 until then.
  double _overflow = -1;

  /// One round: the text and the gap, which brings its copy to where it
  /// started.
  double _travel = 0;

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

  Duration get _round =>
      Duration(microseconds: (_travel / widget.speed * 1e6).round());
  Duration get _total => widget.pause + _round;

  /// How far left the text has gone, at [t] of a cycle: at rest first, then
  /// steadily one whole round, which ends exactly where it began.
  double _offset(double t) {
    final at = t * _total.inMicroseconds;
    final pause = widget.pause.inMicroseconds;
    if (at < pause) return 0;
    return _travel * ((at - pause) / _round.inMicroseconds).clamp(0.0, 1.0);
  }

  void _sync(double overflow, double textWidth) {
    if (!mounted) return;
    if (overflow <= 0.5) {
      _overflow = 0;
      _c.stop();
      return;
    }
    final travel = textWidth + widget.gap;
    if ((overflow - _overflow).abs() > 0.5 ||
        (travel - _travel).abs() > 0.5 ||
        !_c.isAnimating) {
      _overflow = overflow;
      _travel = travel;
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
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _sync(overflow, line.width),
        );
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
              // The text, a gap, and its copy: when the first has gone a whole
              // round the copy is where it began.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: widget.style,
                  ),
                  SizedBox(width: widget.gap),
                  // Only a picture of it: a screen reader reads the title once.
                  ExcludeSemantics(
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: widget.style,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
