import 'dart:ui';

/// Halo color tokens. See docs/DESIGN_SYSTEM.md §2.
///
/// Volt means on, active or yours. Flare means unread or alert. Nothing else.
abstract final class HaloColors {
  static const Color carbon = Color(0xFF0C0C0B);
  static const Color surface = Color(0xFF181816);

  /// Recessed ground behind a live app surface in the focused slat.
  static const Color well = Color(0xFF121211);

  static const Color bone = Color(0xFFF2F0E8);
  static const Color boneDim = Color(0xFFD8D6CC);
  static const Color ash = Color(0xFFA09E94);
  static const Color volt = Color(0xFFD6FF3F);
  static const Color flare = Color(0xFFFF5B2E);
  static const Color voltLine = Color(0x8CD6FF3F); // 0.55

  static const Color line05 = Color(0x0DFFFFFF);
  static const Color line07 = Color(0x12FFFFFF);
  static const Color line08 = Color(0x14FFFFFF);
  static const Color line10 = Color(0x1AFFFFFF);
  static const Color line12 = Color(0x1FFFFFFF);
  static const Color line14 = Color(0x24FFFFFF);
  static const Color line16 = Color(0x29FFFFFF);
  static const Color line18 = Color(0x2EFFFFFF);
  static const Color line20 = Color(0x33FFFFFF);
  static const Color line22 = Color(0x38FFFFFF);
  static const Color line35 = Color(0x59FFFFFF);
}
