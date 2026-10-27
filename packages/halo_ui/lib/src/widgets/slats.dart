import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../notch_border.dart';
import '../palette.dart';
import '../type.dart';
import 'icons.dart';

/// One slat: an app in Recents.
class HaloSlatData {
  const HaloSlatData({
    required this.id,
    required this.label,
    required this.icon,
    required this.preview,
    this.iconWidget,
  });

  final String id;
  final String label;
  final HaloIcons icon;

  /// Drawn in place of [icon] on a collapsed slat (a real app's icon).
  final Widget? iconWidget;

  /// The app's live surface, shown when the slat is focused.
  final Widget preview;
}

/// Tall vertical cards in a row. Collapsed slats are 36 wide with the icon on
/// top and a rotated mono label; the focused one expands to show the app's
/// live content with a `voltLine` border. Tap a collapsed slat to focus it.
/// Flick any slat up to close it.
///
/// Fills its parent's height. See docs/DESIGN_SYSTEM.md §6.
class HaloSlats extends StatefulWidget {
  const HaloSlats({
    super.key,
    required this.slats,
    required this.focusedIndex,
    required this.onFocus,
    required this.onClose,
    this.onOpen,
  });

  final List<HaloSlatData> slats;
  final int focusedIndex;
  final ValueChanged<int> onFocus;
  final ValueChanged<HaloSlatData> onClose;

  /// A tap on the focused slat: switch to its app.
  final ValueChanged<HaloSlatData>? onOpen;

  static const double collapsedWidth = 36;
  static const double gap = 6;

  @override
  State<HaloSlats> createState() => _HaloSlatsState();
}

class _HaloSlatsState extends State<HaloSlats>
    with SingleTickerProviderStateMixin {
  // Unbounded so a shrinking list never invalidates the bounds; the position
  // is clamped to the list when it is read.
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.focusedIndex.toDouble(),
  );

  double get _clampedPos =>
      _pos.value.clamp(0.0, math.max(0, widget.slats.length - 1).toDouble());

  @override
  void didUpdateWidget(HaloSlats old) {
    super.didUpdateWidget(old);
    if (old.focusedIndex != widget.focusedIndex) {
      _pos.animateTo(
        widget.focusedIndex.toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slats = widget.slats;
    final n = slats.length;
    return LayoutBuilder(
      builder: (context, box) {
        final focusedW =
            box.maxWidth - (n - 1) * (HaloSlats.collapsedWidth + HaloSlats.gap);
        return AnimatedBuilder(
          animation: _pos,
          builder: (context, _) {
            final pos = _clampedPos;
            var left = 0.0;
            final tiles = <Widget>[];
            for (var i = 0; i < n; i++) {
              final t = (1 - (i - pos).abs()).clamp(0.0, 1.0);
              final w =
                  HaloSlats.collapsedWidth +
                  t * (focusedW - HaloSlats.collapsedWidth);
              tiles.add(
                Positioned(
                  key: ValueKey('slat-${slats[i].id}'),
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: _SlatTile(
                    data: slats[i],
                    focus: t,
                    onTap: () => widget.onFocus(i),
                    onClose: () => widget.onClose(slats[i]),
                    onOpen: widget.onOpen == null
                        ? null
                        : () => widget.onOpen!(slats[i]),
                  ),
                ),
              );
              left += w + HaloSlats.gap;
            }
            return Stack(clipBehavior: Clip.none, children: tiles);
          },
        );
      },
    );
  }
}

class _SlatTile extends StatefulWidget {
  const _SlatTile({
    required this.data,
    required this.focus,
    required this.onTap,
    required this.onClose,
    this.onOpen,
  });

  final HaloSlatData data;

  /// 0 collapsed, 1 focused.
  final double focus;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback? onOpen;

  @override
  State<_SlatTile> createState() => _SlatTileState();
}

class _SlatTileState extends State<_SlatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this);
  double _dy = 0;
  Animation<double>? _anim;

  static const _closeDistance = 140.0;
  static const _closeVelocity = 700.0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(double target, {required VoidCallback? then}) {
    final from = _dy;
    _settle
      ..stop()
      ..duration = const Duration(milliseconds: 180)
      ..value = 0;
    _anim = Tween<double>(
      begin: from,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    _anim!.addListener(() => setState(() => _dy = _anim!.value));
    _settle.forward().whenComplete(() => then?.call());
  }

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dy < -_closeDistance || v < -_closeVelocity) {
      final height = context.size?.height ?? 620;
      _animateTo(-height, then: widget.onClose);
    } else {
      _animateTo(0, then: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final t = widget.focus;
    final focused = t >= 0.5;
    final d = widget.data;
    return Semantics(
      button: true,
      label: focused ? '${d.label}, focused' : d.label,
      onTap: focused ? widget.onOpen : widget.onTap,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Close'): widget.onClose,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focused ? widget.onOpen : widget.onTap,
        onVerticalDragUpdate: (u) =>
            setState(() => _dy = math.min(0, _dy + u.delta.dy)),
        onVerticalDragEnd: _end,
        child: Transform.translate(
          offset: Offset(0, _dy),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: Color.lerp(halo.surface, halo.well, t),
              shape: NotchBorder(
                radius: HaloRadii.notchXL,
                side: BorderSide(
                  color: Color.lerp(halo.border, halo.focusBorder, t)!,
                  width: 1 + (halo.focusBorderWidth - 1) * t,
                ),
              ),
            ),
            child: focused
                ? d.preview
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        d.iconWidget ?? HaloIcon(d.icon, size: 20),
                        const SizedBox(height: 18),
                        RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            HaloType.upper(d.label),
                            maxLines: 1,
                            style: HaloType.slatLabel.copyWith(
                              color: halo.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
