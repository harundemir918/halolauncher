import 'package:flutter/widgets.dart';

/// Where a system swipe started.
enum EdgeZone { topLeft, topRight, bottom }

/// System edge swipes (the proposal in ROADMAP "Shell gestures"):
///
///  * swipe down from the top right: Switchboard
///  * swipe down from the top left: Stream
///  * swipe up from the bottom edge: Home, and from Home, Recents
///
/// Only drags that start inside [edge] px of the top or bottom count, so they
/// do not fight scrolling or the slats in the middle of the screen.
class EdgeSwipes extends StatefulWidget {
  const EdgeSwipes({
    super.key,
    required this.child,
    required this.onSwipe,
    this.edge = 44,
    this.distance = 80,
  });

  final Widget child;
  final ValueChanged<EdgeZone> onSwipe;
  final double edge;
  final double distance;

  @override
  State<EdgeSwipes> createState() => _EdgeSwipesState();
}

class _EdgeSwipesState extends State<EdgeSwipes> {
  EdgeZone? _zone;
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        // The zone comes from where the finger went down. `onVerticalDragStart`
        // reports where the drag was recognized, about one touch slop (18 px)
        // later, which misses the edge on a slow swipe.
        onVerticalDragDown: (d) {
          final p = d.localPosition;
          _dy = 0;
          if (p.dy <= widget.edge) {
            _zone = p.dx >= box.maxWidth / 2
                ? EdgeZone.topRight
                : EdgeZone.topLeft;
          } else if (p.dy >= box.maxHeight - widget.edge) {
            _zone = EdgeZone.bottom;
          } else {
            _zone = null;
          }
        },
        onVerticalDragCancel: () => _zone = null,
        onVerticalDragUpdate: (d) => _dy += d.delta.dy,
        onVerticalDragEnd: (_) {
          final zone = _zone;
          _zone = null;
          if (zone == null) return;
          final down = zone != EdgeZone.bottom;
          if (down && _dy > widget.distance) widget.onSwipe(zone);
          if (!down && _dy < -widget.distance) widget.onSwipe(zone);
        },
        child: widget.child,
      ),
    );
  }
}
