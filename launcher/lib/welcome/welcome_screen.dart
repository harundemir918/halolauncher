import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

import '../backend_builder.dart';
import '../status_bar.dart';

/// First run (D-031): make Halo the home app and see, one by one, what each
/// optional access is for. Nothing here is required; Halo works without any
/// of it, so Continue is always there.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.backend, required this.onDone});

  final HaloBackend backend;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return BackendBuilder(
      backend: backend,
      builder: (context, b) {
        final halo = context.halo;
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
              // The header and the list stack, so larger text moves the list
              // down; at the design's size it starts at 238.
              Positioned(
                top: 58,
                bottom: 108,
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const HaloKicker('Welcome'),
                              const SizedBox(height: 14),
                              Text(
                                b.isDefaultHome
                                    ? 'Halo is\nyour home'
                                    : 'Make Halo\nyour home',
                                style: HaloType.headlineL.copyWith(
                                  color: halo.text,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                HaloType.upper(
                                  'All optional · nothing leaves your phone',
                                ),
                                style: HaloType.context.copyWith(
                                  color: halo.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          HaloToggleRow(
                            key: const ValueKey('welcome-home'),
                            title: 'Home app',
                            subtitle: b.isDefaultHome
                                ? 'Halo is your home screen'
                                : 'Halo as your home screen · allow',
                            value: b.isDefaultHome,
                            onChanged: (_) => b.requestDefaultHome(),
                          ),
                          for (final g in b.accessGrants) ...[
                            const SizedBox(height: HaloSpace.g6),
                            HaloToggleRow(
                              key: ValueKey('welcome-${g.id}'),
                              title: g.title,
                              subtitle: g.granted
                                  ? g.detail
                                  : '${g.detail} · allow',
                              value: g.granted,
                              onChanged: (_) => b.openAccess(g.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: HaloSpace.gutter,
                right: HaloSpace.gutter,
                bottom: 40,
                child: HaloButton(
                  key: const ValueKey('welcome-continue'),
                  label: 'Continue',
                  onPressed: onDone,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
