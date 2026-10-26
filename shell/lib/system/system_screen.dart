import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
import '../format.dart';
import '../status_bar.dart';

/// System: the Settings app. Numbered sections, one open at a time, controls
/// inline. Only Display has designed contents so far.
class SystemScreen extends StatefulWidget {
  const SystemScreen({
    super.key,
    required this.backend,
    this.initiallyOpen = 'display',
  });

  final HaloBackend backend;

  /// Id of the section open at first. Null for all closed.
  final String? initiallyOpen;

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  late String? _open = widget.initiallyOpen;

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: widget.backend,
      builder: (context, b) {
        final sys = b.system;
        final wifi = b.quick.toggles.where((t) => t.id == 'wifi').firstOrNull;
        final sections = <_Section>[
          _Section('connections', 'Connections', wifi?.detail ?? 'Off'),
          _Section('display', 'Display', sys.appearance.name),
          _Section('sound', 'Sound', 'Ring ${(b.quick.volume * 100).round()}'),
          _Section('focus', 'Focus', sys.focus),
          _Section('privacy', 'Privacy', '${sys.privacyAlerts} alerts'),
          _Section('battery', 'Battery', '${b.status.batteryPercent}%'),
        ];

        return ColoredBox(
          color: context.halo.ground,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ShellStatusBar(backend: b),
              ),
              Positioned(
                top: 54,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'System',
                      style: HaloType.screenTitle.copyWith(
                        color: context.halo.text,
                      ),
                    ),
                    HaloAvatar(
                      initials: sys.account.initials,
                      label: 'Account: ${sys.account.name}',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const Positioned(
                top: 118,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: HaloCommandField(),
              ),
              Positioned(
                top: 190,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                bottom: 0,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < sections.length; i++)
                        HaloAccordionRow(
                          number: HaloFormat.two(i + 1),
                          title: sections[i].title,
                          status: sections[i].status,
                          open: _open == sections[i].id,
                          last: i == sections.length - 1,
                          onTap: () => _toggle(sections[i].id),
                          child: _contents(sections[i].id, b),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contents(String id, HaloBackend b) {
    if (id != 'display') {
      return Text(
        HaloType.upper('Not designed yet'),
        style: HaloType.fieldLabel.copyWith(color: context.halo.muted),
      );
    }
    final sys = b.system;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          HaloType.upper('Appearance'),
          style: HaloType.fieldLabel.copyWith(color: context.halo.muted),
        ),
        const SizedBox(height: 8),
        HaloSegmented<Appearance>(
          value: sys.appearance,
          onChanged: b.setAppearance,
          options: [for (final a in Appearance.values) HaloSegment(a, a.name)],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              HaloType.upper('Text size'),
              style: HaloType.fieldLabel.copyWith(color: context.halo.muted),
            ),
            Text(
              '${sys.textSizePx}',
              style: HaloType.fieldLabel.copyWith(color: context.halo.text),
            ),
          ],
        ),
        const SizedBox(height: 12),
        HaloSlider(
          value: sys.textSize,
          onChanged: b.setTextSize,
          semanticLabel: 'Text size',
          semanticValue: '${sys.textSizePx} px',
        ),
      ],
    );
  }
}

class _Section {
  const _Section(this.id, this.title, this.status);

  final String id;
  final String title;
  final String status;
}
