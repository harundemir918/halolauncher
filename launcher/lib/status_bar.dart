import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'shell_nav.dart';

/// The battery line across the very top and, below it, the way to Stream on
/// the left and to Switchboard on the right. Android's own status bar shows
/// the time and the battery, so Halo doesn't repeat them (D-024). A Flare dot
/// before STREAM means something is unread; the screen shown is Volt.
/// Place it at the top of a `Stack`. (Lock has its own `LOCKED` row.)
class ShellStatusBar extends StatelessWidget {
  const ShellStatusBar({super.key, required this.backend});

  final HaloBackend backend;

  /// Height of the touch area below the battery line: tall enough to tap,
  /// short of the screen titles below.
  static const double touchHeight = 41;

  @override
  Widget build(BuildContext context) {
    final nav = ShellNav.maybeOf(context);
    final unread = backend.notifications.any((n) => n.unread);
    return Column(
      children: [
        HaloBatteryLine(fraction: backend.status.battery),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HaloSpace.gutter - 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Shortcut(
                key: const ValueKey('status-stream'),
                label: 'Stream',
                screen: 'stream',
                nav: nav,
                unread: unread,
              ),
              _Shortcut(
                key: const ValueKey('status-switchboard'),
                label: 'Switchboard',
                screen: 'switchboard',
                nav: nav,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    super.key,
    required this.label,
    required this.screen,
    required this.nav,
    this.unread = false,
  });

  final String label;
  final String screen;
  final ShellNav? nav;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final current = nav?.current == screen;
    final open = nav == null || current ? null : () => nav!.open(screen);
    return Semantics(
      button: true,
      label: unread ? '$label, unread' : label,
      selected: current,
      onTap: open,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: Container(
            height: ShellStatusBar.touchHeight,
            padding: const EdgeInsets.fromLTRB(
              12,
              HaloSpace.statusTop - HaloSpace.batteryLine,
              12,
              0,
            ),
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unread) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: halo.flare,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  HaloType.upper(label),
                  style: HaloType.status.copyWith(
                    color: current ? halo.signalText : halo.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
