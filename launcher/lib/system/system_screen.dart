import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
import '../gestures.dart';
import '../format.dart';
import '../status_bar.dart';

/// System: the Settings app. Numbered sections, one open at a time, controls
/// inline. Only Display has designed contents so far. The field above them
/// finds a section (by its name or what is in it) or one of Android's own
/// settings pages.
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
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);

  /// What is in each section, so that searching "bluetooth" or "text size"
  /// finds the one that has it.
  static const _inside = {
    'connections': [
      'Wi-Fi',
      'Bluetooth',
      'Mobile data',
      'Cellular',
      'Airplane mode',
      'Network',
    ],
    'display': ['Appearance', 'Theme', 'Dark', 'Light', 'Text size', 'Font'],
    'sound': ['Volume', 'Ringer', 'Vibration', 'Silent'],
    'focus': ['Do not disturb', 'Quiet', 'Schedule'],
    'privacy': [
      'Permissions',
      'Access',
      'Notifications access',
      'Calendar',
      'Contacts',
      'Usage access',
      'Write settings',
    ],
    'battery': ['Power saver', 'Charging', 'Usage'],
  };

  /// The sections that match the query, best first, each once.
  List<_Section> _found(List<_Section> sections) {
    final entries = [
      for (final sec in sections) ...[
        (sec.title, sec),
        for (final word in _inside[sec.id] ?? const <String>[]) (word, sec),
      ],
    ];
    final hits = searchByLabel(entries, (e) => e.$1, _query.text);
    return [
      for (final id in {for (final h in hits) h.$2.id})
        sections.firstWhere((sec) => sec.id == id),
    ];
  }

  Widget _heading(String label) => SizedBox(
    height: 36,
    child: Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: HaloKicker(label, color: context.halo.muted, square: false),
      ),
    ),
  );

  /// The list while there is a query: sections, then Android's own pages.
  Widget _results(HaloBackend b, List<_Section> sections) {
    final mine = _found(sections);
    final pages = searchByLabel(b.settingsPages, (p) => p.label, _query.text);
    if (mine.isEmpty && pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          HaloType.upper('No matches'),
          style: HaloType.kicker.copyWith(color: context.halo.muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (mine.isNotEmpty) ...[
          _heading('System'),
          for (final sec in mine)
            HaloResultRow(
              key: ValueKey('system-result-${sec.id}'),
              title: sec.title,
              caption: sec.status,
              onTap: () => _show(sec.id),
            ),
        ],
        if (pages.isNotEmpty) ...[
          _heading('Android settings'),
          for (final p in pages)
            HaloResultRow(
              key: ValueKey('setting-${p.id}'),
              title: p.label,
              onTap: () => b.openSettingsPage(p.id),
            ),
        ],
      ],
    );
  }

  /// Open a section from the results: back to the list, with it open.
  void _show(String id) => setState(() {
    _query.clear();
    _open = id;
  });

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
          _Section(
            'privacy',
            'Privacy',
            '${sys.privacyAlerts} ${sys.privacyAlerts == 1 ? 'alert' : 'alerts'}',
          ),
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
                    // Android doesn't tell a launcher who the user is, so
                    // there is only an avatar when a backend knows.
                    if (sys.account.initials.isNotEmpty)
                      HaloAvatar(
                        initials: sys.account.initials,
                        label: 'Account: ${sys.account.name}',
                        onPressed: () {},
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 118,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: HaloCommandField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    // Go opens the best match.
                    final mine = _found(sections);
                    if (mine.isNotEmpty) return _show(mine.first.id);
                    final pages = searchByLabel(
                      b.settingsPages,
                      (p) => p.label,
                      _query.text,
                    );
                    if (pages.isNotEmpty) b.openSettingsPage(pages.first.id);
                  },
                ),
              ),
              Positioned(
                top: 190,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                bottom: EdgeSwipes.defaultEdge,
                child: _query.text.trim().isNotEmpty
                    ? _results(b, sections)
                    : SingleChildScrollView(
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
    if (id != 'display') return _shortcut(id, b);
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

  /// What each other section hands to Android: Halo shows the state and opens
  /// the system's own page, since an app can't change these itself.
  static const _hints = {
    'connections': 'Wi-Fi, Bluetooth and mobile data',
    'sound': 'Volume, ringer and vibration',
    'focus': 'Do Not Disturb and its schedules',
    'privacy': 'What Halo may read. All optional',
    'battery': 'Usage and battery saver',
  };

  Widget _shortcut(String id, HaloBackend b) {
    final halo = context.halo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          HaloType.upper(_hints[id] ?? ''),
          style: HaloType.fieldLabel.copyWith(color: halo.muted),
        ),
        if (id == 'privacy')
          for (final g in b.accessGrants) ...[
            const SizedBox(height: HaloSpace.g6),
            HaloToggleRow(
              title: g.title,
              subtitle: g.granted ? g.detail : '${g.detail} · allow',
              value: g.granted,
              onChanged: (_) => b.openAccess(g.id),
            ),
          ],
        const SizedBox(height: 14),
        HaloButton(
          label: 'Open Android settings',
          variant: HaloButtonVariant.secondary,
          onPressed: () => b.openAndroidSettings(id),
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
