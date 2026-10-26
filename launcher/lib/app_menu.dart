import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

/// The long-press menu for an app, laid over the current screen: the app's
/// shortcuts, its place on the arc, App info and Uninstall. Tapping outside
/// closes it. No scrim: the screen stays solid behind a solid card.
class AppMenuLayer extends StatefulWidget {
  const AppMenuLayer({
    super.key,
    required this.backend,
    required this.app,
    required this.onClose,
  });

  final HaloBackend backend;
  final HaloAppInfo app;
  final VoidCallback onClose;

  @override
  State<AppMenuLayer> createState() => _AppMenuLayerState();
}

class _AppMenuLayerState extends State<AppMenuLayer> {
  late final Future<List<AppShortcut>> _shortcuts = widget.backend.shortcuts(
    widget.app.id,
  );

  /// Runs [action] and closes the menu.
  VoidCallback _then(void Function() action) => () {
    action();
    widget.onClose();
  };

  @override
  Widget build(BuildContext context) {
    final b = widget.backend;
    final app = widget.app;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('menu-outside'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
          ),
        ),
        Positioned(
          left: HaloSpace.gutter,
          right: HaloSpace.gutter,
          bottom: 28,
          child: FutureBuilder<List<AppShortcut>>(
            future: _shortcuts,
            builder: (context, snap) {
              final shortcuts = snap.data ?? const <AppShortcut>[];
              final arc = b.arcApps.map((a) => a.id).toList();
              final at = arc.indexOf(app.id);
              return HaloMenu(
                key: const ValueKey('app-menu'),
                title: app.label,
                tag: app.work ? 'Work' : null,
                sections: [
                  HaloMenuSection(
                    label: 'Shortcuts',
                    items: [
                      for (final s in shortcuts)
                        HaloMenuItem(
                          s.label,
                          onPressed: _then(() => b.startShortcut(app.id, s.id)),
                        ),
                    ],
                  ),
                  HaloMenuSection(
                    label: 'Arc',
                    items: at < 0
                        ? [
                            HaloMenuItem(
                              'Add to arc',
                              onPressed: _then(() => b.pinToArc(app.id)),
                            ),
                          ]
                        : [
                            HaloMenuItem(
                              'Move left',
                              onPressed: at == 0
                                  ? null
                                  : _then(() => b.moveOnArc(app.id, -1)),
                            ),
                            HaloMenuItem(
                              'Move right',
                              onPressed: at == arc.length - 1
                                  ? null
                                  : _then(() => b.moveOnArc(app.id, 1)),
                            ),
                            HaloMenuItem(
                              'Remove from arc',
                              onPressed: _then(() => b.unpinFromArc(app.id)),
                            ),
                          ],
                  ),
                  HaloMenuSection(
                    label: 'App',
                    items: [
                      HaloMenuItem(
                        'App info',
                        onPressed: _then(() => b.openAppInfo(app.id)),
                      ),
                      if (app.canUninstall)
                        HaloMenuItem(
                          'Uninstall',
                          onPressed: _then(() => b.uninstall(app.id)),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
