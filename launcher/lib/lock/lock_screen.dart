import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../format.dart';
import 'lock_background.dart';

/// The Lock screen. Press and hold the ring to open.
///
/// Laid out on the 390 × 844 reference frame: the upper blocks hang from the
/// top, the controls sit on the bottom.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.backend,
    required this.onUnlock,
    this.holdDuration = const Duration(milliseconds: 700),
    this.glance = false,
    this.onFlashlight,
    this.onCamera,
  });

  final HaloBackend backend;
  final VoidCallback onUnlock;

  /// How long the ring must be held.
  final Duration holdDuration;

  /// The Android build (D-021): the page left of Home, not a lock screen. It
  /// says `GLANCE`, leaves out a network it doesn't know, and shows a shortcut
  /// only when the phone can run it. The ring takes the user back to Home.
  final bool glance;
  final VoidCallback? onFlashlight;
  final VoidCallback? onCamera;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      widget.onUnlock();
      _hold.value = 0;
    }
  }

  // After the hold completes Lock is replaced while the finger is still down,
  // so the release arrives after dispose. Ignore it.
  void _press() {
    if (mounted) _hold.forward();
  }

  void _release() {
    if (mounted) _hold.reverse();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.backend.now;
    final status = widget.backend.status;
    final event = widget.backend.nextEvent;
    final previews = widget.backend.lockPreviews;
    final hasUnread = previews.any((n) => n.unread);

    return ColoredBox(
      color: context.halo.ground,
      child: Stack(
        children: [
          Positioned.fill(child: LockBackground(hasUnread: hasUnread)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HaloBatteryLine(fraction: status.battery),
          ),
          Positioned(
            top: HaloSpace.statusTop,
            left: HaloSpace.gutter,
            right: HaloSpace.gutter,
            child: HaloStatusRow(
              left: TextSpan(text: widget.glance ? 'GLANCE' : 'LOCKED'),
              right: [
                if (status.network.isNotEmpty || !widget.glance) status.network,
                '${status.batteryPercent}%',
              ].join(' · '),
            ),
          ),
          Positioned(
            top: 64,
            left: HaloSpace.gutter,
            child: _Clock(
              hours: HaloFormat.hours(now),
              minutes: HaloFormat.minutes(now),
            ),
          ),
          Positioned(
            top: 424,
            left: HaloSpace.gutter,
            child: Text(
              HaloFormat.lockDate(now),
              style: HaloType.dateLine.copyWith(color: context.halo.muted),
            ),
          ),
          if (event != null)
            Positioned(
              top: 462,
              left: HaloSpace.gutter,
              right: HaloSpace.gutter,
              child: HaloEventCard(
                time: HaloFormat.clock(event.start),
                kicker: 'Next · in ${event.minutesUntil(now)} min',
                title: '${event.title} · ${event.location}',
              ),
            ),
          Positioned(
            top: 550,
            left: HaloSpace.gutter,
            right: HaloSpace.gutter,
            child: Column(
              children: [
                for (final n in previews.take(2))
                  HaloNotificationPreview(
                    sender: n.sender,
                    body: n.preview ?? n.body,
                    age: n.age(now),
                    unread: n.unread,
                  ),
              ],
            ),
          ),
          if (!widget.glance || widget.onFlashlight != null)
            Positioned(
              left: HaloSpace.gutter,
              bottom: 52,
              child: HaloShortcut(
                icon: HaloIcons.flashlight,
                label: 'Flashlight',
                onPressed: widget.onFlashlight ?? () {},
              ),
            ),
          if (!widget.glance || widget.onCamera != null)
            Positioned(
              right: HaloSpace.gutter,
              bottom: 52,
              child: HaloShortcut(
                icon: HaloIcons.camera,
                label: 'Camera',
                onPressed: widget.onCamera ?? () {},
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 26,
            child: Center(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _press(),
                onPointerUp: (_) => _release(),
                onPointerCancel: (_) => _release(),
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => HaloHoldRing(
                    progress:
                        HaloHoldRing.resting +
                        (1 - HaloHoldRing.resting) * _hold.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Giant clock: hours solid, minutes outlined.
class _Clock extends StatelessWidget {
  const _Clock({required this.hours, required this.minutes});

  final String hours;
  final String minutes;

  @override
  Widget build(BuildContext context) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = context.halo.text;
    return Semantics(
      label: '$hours:$minutes',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hours,
              style: HaloType.clockHero.copyWith(color: context.halo.text),
            ),
            const SizedBox(height: 22),
            Text(
              minutes,
              style: HaloType.clockHero.copyWith(foreground: outline),
            ),
          ],
        ),
      ),
    );
  }
}
