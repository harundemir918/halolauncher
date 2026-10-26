import 'package:flutter/widgets.dart';

/// Lets widgets deep in a screen (the status row) see which screen is shown
/// and open another, without threading callbacks through every screen.
class ShellNav extends InheritedWidget {
  const ShellNav({
    super.key,
    required this.current,
    required this.open,
    required super.child,
  });

  /// The screen shown (`home`, `stream`, `switchboard`…).
  final String current;

  /// Opens a screen by name.
  final ValueChanged<String> open;

  /// The nearest [ShellNav], or null outside the launcher (single-screen
  /// tests, goldens), where the status row's labels do nothing.
  static ShellNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNav>();

  @override
  bool updateShouldNotify(ShellNav old) => old.current != current;
}
