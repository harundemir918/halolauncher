/// Halo spacing tokens on the 390 × 844 reference frame.
/// See docs/DESIGN_SYSTEM.md §5.
abstract final class HaloSpace {
  static const double frameWidth = 390;
  static const double frameHeight = 844;

  /// Screen gutter, left and right.
  static const double gutter = 24;

  /// Top offset of the status row.
  static const double statusTop = 16;

  /// Height of the battery line across the top of every screen.
  static const double batteryLine = 3;

  /// Minimum touch target.
  static const double touchTarget = 44;

  /// Common gaps.
  static const double g4 = 4;
  static const double g6 = 6;
  static const double g8 = 8;
  static const double g12 = 12;
  static const double g14 = 14;
  static const double g18 = 18;

  /// Vertical padding of list rows (13 to 16 in the designs).
  static const double rowPadding = 14;
}
