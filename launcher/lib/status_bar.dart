import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import 'format.dart';

/// The battery line across the very top and the status row below it, as on
/// Home, Switchboard, Stream and System. (Lock has its own `LOCKED` row.)
/// Place it at the top of a `Stack`.
class ShellStatusBar extends StatelessWidget {
  const ShellStatusBar({super.key, required this.backend});

  final HaloBackend backend;

  @override
  Widget build(BuildContext context) {
    final now = backend.now;
    final status = backend.status;
    return Column(
      children: [
        HaloBatteryLine(fraction: status.battery),
        const SizedBox(height: HaloSpace.statusTop - HaloSpace.batteryLine),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HaloSpace.gutter),
          child: HaloStatusRow(
            left: TextSpan(
              children: [
                HaloStatusRow.strong(context, HaloFormat.clock(now)),
                TextSpan(text: '  ${HaloFormat.statusDate(now)}'),
              ],
            ),
            right: '${status.network} · ${status.batteryPercent}%',
          ),
        ),
      ],
    );
  }
}
