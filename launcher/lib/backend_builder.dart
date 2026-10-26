import 'package:flutter/widgets.dart';
import 'package:halo_sdk/halo_sdk.dart';

/// Rebuilds whenever the backend reports a change.
class BackendBuilder extends StatelessWidget {
  const BackendBuilder({
    super.key,
    required this.backend,
    required this.builder,
  });

  final HaloBackend backend;
  final Widget Function(BuildContext context, HaloBackend backend) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: backend.changes,
    builder: (context, _) => builder(context, backend),
  );
}
