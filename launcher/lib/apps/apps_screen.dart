import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../app_icons.dart';
import '../backend_builder.dart';
import '../status_bar.dart';

/// Apps: every installed app in one list, never a grid (D-026). A command
/// field searches apps, contacts (with the user's permission) and settings
/// pages; without a query the list runs A to Z with letter headings and a
/// letter index down the right edge, then the private space, if there is one.
/// Reached by swiping up on the arc.
class AppsScreen extends StatefulWidget {
  const AppsScreen({
    super.key,
    required this.backend,
    required this.onLaunch,
    required this.onLongPress,
    this.autofocusSearch = false,
  });

  final HaloBackend backend;

  /// Open with the keyboard up, as from Ask Halo (D-027).
  final bool autofocusSearch;
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

  // Contact search is asynchronous; one lookup per query.
  String? _contactsFor;
  Future<List<ContactResult>> _contacts = Future.value(const []);

  Future<List<ContactResult>> _contactsMatching(String query) {
    if (query != _contactsFor) {
      _contactsFor = query;
      _contacts = widget.backend.searchContacts(query);
    }
    return _contacts;
  }

  Widget _heading(String label, {Key? key}) => SizedBox(
    height: AppsScreen.headingHeight,
    child: Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: HaloKicker(
          label,
          key: key,
          color: context.halo.muted,
          square: false,
        ),
      ),
    ),
  );

  /// The CONTACTS part of the results: an ask while search may not look in
  /// the contacts, else the matches (nothing when there are none).
  Widget _contactResults(HaloBackend b, String query) {
    final halo = context.halo;
    if (!b.canSearchContacts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Contacts'),
          HaloResultRow(
            key: const ValueKey('contacts-allow'),
            title: 'Search your contacts too',
            caption: 'Allow',
            captionSignal: true,
            onTap: b.requestContactsAccess,
          ),
          const SizedBox(height: 8),
          Text(
            HaloType.upper('Names stay on this phone'),
            style: HaloType.caption.copyWith(color: halo.muted),
          ),
        ],
      );
    }
    return FutureBuilder<List<ContactResult>>(
      future: _contactsMatching(query),
      builder: (context, snap) {
        final found = snap.data ?? const <ContactResult>[];
        if (found.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Contacts', key: const ValueKey('section-contacts')),
            for (final c in found)
              HaloResultRow(
                key: ValueKey('contact-${c.id}'),
                title: c.name,
                initials: c.initials,
                onTap: () => b.openContact(c.id),
              ),
          ],
        );
      },
    );
  }

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
    privateSpace: a.privateSpace,
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
          final pages = searchByLabel(b.settingsPages, (p) => p.label, query);
          list = ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (results.isNotEmpty) ...[
                _heading('Apps', key: const ValueKey('section-apps')),
                for (final a in results) _row(a, onArc),
              ],
              _contactResults(b, query),
              if (pages.isNotEmpty) ...[
                _heading('Settings', key: const ValueKey('section-settings')),
                for (final p in pages)
                  HaloResultRow(
                    key: ValueKey('setting-${p.id}'),
                    title: p.label,
                    onTap: () => b.openSettingsPage(p.id),
                  ),
              ],
              if (results.isEmpty && pages.isEmpty && b.canSearchContacts)
                FutureBuilder<List<ContactResult>>(
                  future: _contactsMatching(query),
                  builder: (context, snap) =>
                      snap.connectionState == ConnectionState.done &&
                          (snap.data ?? const []).isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            HaloType.upper('No matches'),
                            style: HaloType.kicker.copyWith(color: halo.muted),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          );
        } else {
          list = ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final (letter, group) in _shown) ...[
                _heading(letter, key: ValueKey('heading-$letter')),
                for (final a in group) _row(a, onArc),
              ],
              if (b.privateSpace != PrivateSpaceState.none) ...[
                _heading('Private'),
                HaloResultRow(
                  key: const ValueKey('private-space'),
                  title: 'Private space',
                  caption: b.privateSpace == PrivateSpaceState.locked
                      ? 'Locked · unlock'
                      : 'Lock',
                  onTap: () => b.setPrivateSpaceLocked(
                    b.privateSpace == PrivateSpaceState.unlocked,
                  ),
                ),
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
                  placeholder: 'find anything',
                  controller: _query,
                  autofocus: widget.autofocusSearch,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (text) {
                    final best = searchApps(widget.backend.apps, text);
                    if (best.isNotEmpty) return widget.onLaunch(best.first.id);
                    final pages = searchByLabel(
                      widget.backend.settingsPages,
                      (p) => p.label,
                      text,
                    );
                    if (pages.isNotEmpty) {
                      widget.backend.openSettingsPage(pages.first.id);
                    }
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
