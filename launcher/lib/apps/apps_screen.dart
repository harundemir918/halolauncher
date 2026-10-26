import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../app_icons.dart';
import '../backend_builder.dart';
import '../status_bar.dart';

/// Apps: every installed app in one list, never a grid (D-026). A command
/// field searches; without a query the list runs A to Z with letter headings
/// and a letter index down the right edge. Reached by swiping up on the arc.
class AppsScreen extends StatefulWidget {
  const AppsScreen({
    super.key,
    required this.backend,
    required this.onLaunch,
    required this.onLongPress,
  });

  final HaloBackend backend;
  final ValueChanged<String> onLaunch;
  final ValueChanged<HaloAppInfo> onLongPress;

  static const double headingHeight = 36;

  /// The section letter for an app: its folded first letter, or `#`.
  static String letterOf(HaloAppInfo app) {
    final folded = foldForSearch(app.label.trimLeft());
    final c = folded.isEmpty ? '' : folded[0];
    return RegExp('[a-z]').hasMatch(c) ? c.toUpperCase() : '#';
  }

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  String? _current;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackLetter);
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Sections in order, `#` last, apps A to Z by folded label inside each.
  List<(String, List<HaloAppInfo>)> _sections(List<HaloAppInfo> apps) {
    final sorted = [
      ...apps,
    ]..sort((a, b) => foldForSearch(a.label).compareTo(foldForSearch(b.label)));
    final byLetter = <String, List<HaloAppInfo>>{};
    for (final a in sorted) {
      byLetter.putIfAbsent(AppsScreen.letterOf(a), () => []).add(a);
    }
    final letters = byLetter.keys.toList()
      ..sort((a, b) => a == '#' ? 1 : (b == '#' ? -1 : a.compareTo(b)));
    return [for (final l in letters) (l, byLetter[l]!)];
  }

  /// Where each section starts in the list.
  Map<String, double> _offsets(List<(String, List<HaloAppInfo>)> sections) {
    final out = <String, double>{};
    var y = 0.0;
    for (final (letter, apps) in sections) {
      out[letter] = y;
      y += AppsScreen.headingHeight + apps.length * HaloAppRow.height;
    }
    return out;
  }

  List<(String, List<HaloAppInfo>)> _shown = const [];

  void _trackLetter() {
    if (!_scroll.hasClients || _query.text.isNotEmpty) return;
    String? current;
    for (final MapEntry(key: letter, value: y) in _offsets(_shown).entries) {
      if (y <= _scroll.offset + 1) current = letter;
    }
    if (current != _current) setState(() => _current = current);
  }

  void _jumpTo(String letter) {
    final y = _offsets(_shown)[letter];
    if (y == null || !_scroll.hasClients) return;
    _scroll.jumpTo(y.clamp(0.0, _scroll.position.maxScrollExtent));
    setState(() => _current = letter);
  }

  Widget _row(HaloAppInfo a, Set<String> onArc) => HaloAppRow(
    key: ValueKey('row-${a.id}'),
    label: a.label,
    icon: iconFor(a),
    image: imageFor(a),
    work: a.work,
    onArc: onArc.contains(a.id),
    onTap: () => widget.onLaunch(a.id),
    onLongPress: () => widget.onLongPress(a),
  );

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: widget.backend,
      builder: (context, b) {
        final halo = context.halo;
        final apps = b.apps;
        final onArc = {for (final a in b.arcApps) a.id};
        final query = _query.text;
        final results = searchApps(apps, query);
        _shown = _sections(apps);

        final Widget list;
        if (query.trim().isNotEmpty) {
          list = results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    HaloType.upper('No apps match'),
                    style: HaloType.kicker.copyWith(color: halo.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [for (final a in results) _row(a, onArc)],
                );
        } else {
          list = ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final (letter, group) in _shown) ...[
                SizedBox(
                  height: AppsScreen.headingHeight,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: HaloKicker(
                        letter,
                        key: ValueKey('heading-$letter'),
                        color: halo.muted,
                        square: false,
                      ),
                    ),
                  ),
                ),
                for (final a in group) _row(a, onArc),
              ],
            ],
          );
        }

        return ColoredBox(
          color: halo.ground,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ShellStatusBar(backend: b),
              ),
              Positioned(
                top: 56,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Apps',
                      style: HaloType.screenTitle.copyWith(color: halo.text),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${apps.length}'.padLeft(2, '0'),
                      style: HaloType.count.copyWith(color: halo.signalText),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 120,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: HaloCommandField(
                  placeholder: 'find an app',
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (text) {
                    final best = searchApps(widget.backend.apps, text);
                    if (best.isNotEmpty) widget.onLaunch(best.first.id);
                  },
                ),
              ),
              Positioned(
                top: 180,
                bottom: 0,
                left: HaloSpace.gutter,
                right: query.trim().isEmpty
                    ? HaloSpace.gutter + HaloLetterIndex.width
                    : HaloSpace.gutter,
                child: list,
              ),
              if (query.trim().isEmpty && _shown.isNotEmpty)
                Positioned(
                  top: 196,
                  bottom: 24,
                  right: HaloSpace.gutter - 14,
                  child: HaloLetterIndex(
                    letters: [for (final (l, _) in _shown) l],
                    current: _current ?? _shown.first.$1,
                    onLetter: _jumpTo,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
