import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The smallest touch target Android asks for, in dp.
const double haloMinTarget = 48;

/// A control's semantics (it replaces a [Semantics] and an [ExcludeSemantics]
/// around it) with a touch target of at least 48 × 48 dp, without changing the
/// layout: the child keeps the size and place the design gives it, and the
/// target reaches out around it, centered. The reach is what a screen reader
/// highlights and what a thumb can hit. It is cut short only where a parent's
/// own bounds end (a tight row), so controls on a screen's own stack get all
/// of it.
///
/// Controls the design draws smaller (44 high buttons, 32 high inline actions,
/// text links) use it, so that fidelity and reach don't trade off.
class HaloTapTarget extends SingleChildRenderObjectWidget {
  const HaloTapTarget({
    super.key,
    required this.properties,
    required Widget super.child,
  });

  /// What a screen reader says and can do: button, label, onTap and so on.
  final SemanticsProperties properties;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTapTarget(
    properties: properties,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTapTarget)
      ..properties = properties
      ..textDirection = Directionality.maybeOf(context);
  }
}

class _RenderTapTarget extends RenderSemanticsAnnotations {
  // A node of its own even inside a parent that merges its descendants (a
  // row with a tap and a swipe), so each control is reached separately.
  _RenderTapTarget({required super.properties, super.textDirection})
    : super(excludeSemantics: true, container: true);

  /// The child's box, widened to 48 each way around its center.
  Rect get _reach => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: math.max(size.width, haloMinTarget),
    height: math.max(size.height, haloMinTarget),
  );

  @override
  Rect get semanticBounds => _reach;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_reach.contains(position)) return false;
    // A touch in the margin counts as one on the child's nearest edge.
    final onChild = Offset(
      position.dx.clamp(0.0, size.width - 0.01),
      position.dy.clamp(0.0, size.height - 0.01),
    );
    return child?.hitTest(result, position: onChild) ?? false;
  }
}
