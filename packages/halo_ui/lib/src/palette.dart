import 'package:flutter/material.dart';

import 'colors.dart';

/// The colors of one appearance, by role. Dark and light share layout and
/// shapes and swap these (docs/DESIGN_SYSTEM.md §2 and §2b). Widgets read the
/// palette from the theme with `context.halo`, never a fixed color.
///
/// Most roles are plain swaps. Three are not:
///  * Volt is **three** roles: [signalFill] (with a [fillEdge] in light),
///    [signalLine] and [signalText]. Dark uses one color for all three.
///  * Hairlines are role-dependent alphas, not one step per token.
///  * A few controls invert in light (switch, slider, dial, chip).
@immutable
class HaloPalette extends ThemeExtension<HaloPalette> {
  const HaloPalette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.well,
    required this.text,
    required this.textDim,
    required this.muted,
    required this.flare,
    required this.signalFill,
    required this.signalLine,
    required this.signalText,
    required this.onSignal,
    required this.fillEdge,
    required this.border,
    required this.divider,
    required this.track,
    required this.soft,
    required this.appBorder,
    required this.outline,
    required this.switchOff,
    required this.ticks,
    required this.cells,
    required this.mediaTrack,
    required this.sliderTrack,
    required this.guide,
    required this.ringsHome,
    required this.ringsLock,
    required this.holdTrack,
    required this.mapRings,
    required this.mapMajor,
    required this.mapMinor,
    required this.switchOnTrack,
    required this.switchOnKnob,
    required this.sliderFill,
    required this.dialAuto,
    required this.dialManual,
    required this.chipFill,
    required this.chipText,
    required this.yesFill,
    required this.yesText,
    required this.holdDot,
    required this.mediaFill,
    required this.focusBorder,
    required this.focusBorderWidth,
    required this.accordionRule,
    required this.accordionRuleWidth,
    required this.arcStroke,
    required this.routeStroke,
  });

  final Brightness brightness;

  // Base.
  final Color ground;
  final Color surface;

  /// Recessed ground behind a live app surface in the focused slat.
  final Color well;
  final Color text;
  final Color textDim;
  final Color muted;

  /// Unread or alert, nothing else.
  final Color flare;

  // Signal: Volt, split by how it is drawn.
  final Color signalFill;
  final Color signalLine;
  final Color signalText;

  /// Text and glyphs on a [signalFill].
  final Color onSignal;

  /// The 1 px edge around a [signalFill]. Null in dark.
  final Color? fillEdge;

  // Hairlines, by role.
  /// Card, slat and toggle-row borders.
  final Color border;

  /// Row dividers and rules.
  final Color divider;

  /// Battery-line and dial tracks.
  final Color track;

  /// Shortcut squares and the command field.
  final Color soft;
  final Color appBorder;

  /// Outline buttons, the avatar and unselected segments.
  final Color outline;
  final Color switchOff;
  final Color ticks;

  /// Empty battery cells.
  final Color cells;
  final Color mediaTrack;
  final Color sliderTrack;

  /// The Home arc's guide ring and the Stream's spine.
  final Color guide;
  final Color ringsHome;
  final Color ringsLock;
  final Color holdTrack;
  final Color mapRings;
  final Color mapMajor;
  final Color mapMinor;

  // Controls that invert in light.
  final Color switchOnTrack;
  final Color switchOnKnob;
  final Color sliderFill;
  final Color dialAuto;
  final Color dialManual;
  final Color chipFill;
  final Color chipText;
  final Color yesFill;
  final Color yesText;
  final Color holdDot;
  final Color mediaFill;

  // Focus and rules.
  final Color focusBorder;
  final double focusBorderWidth;
  final Color accordionRule;
  final double accordionRuleWidth;

  /// Stroke of the Lock background's arc, and of the Maps route.
  final double arcStroke;
  final double routeStroke;

  bool get isLight => brightness == Brightness.light;

  /// A 1 px edge for a signal fill, or none in dark.
  BorderSide get fillSide => fillEdge == null
      ? BorderSide.none
      : BorderSide(color: fillEdge!, width: 1);

  static const HaloPalette dark = HaloPalette(
    brightness: Brightness.dark,
    ground: HaloColors.carbon,
    surface: HaloColors.surface,
    well: HaloColors.well,
    text: HaloColors.bone,
    textDim: HaloColors.boneDim,
    muted: HaloColors.ash,
    flare: HaloColors.flare,
    signalFill: HaloColors.volt,
    signalLine: HaloColors.volt,
    signalText: HaloColors.volt,
    onSignal: HaloColors.carbon,
    fillEdge: null,
    border: HaloColors.line08,
    divider: HaloColors.line10,
    track: HaloColors.line10,
    soft: HaloColors.line10,
    appBorder: HaloColors.line12,
    outline: HaloColors.line22,
    switchOff: HaloColors.line35,
    ticks: HaloColors.line20,
    cells: HaloColors.line12,
    mediaTrack: HaloColors.line14,
    sliderTrack: HaloColors.line18,
    guide: HaloColors.line16,
    ringsHome: HaloColors.line05,
    ringsLock: HaloColors.line07,
    holdTrack: HaloColors.line16,
    mapRings: HaloColors.line05,
    mapMajor: HaloColors.line10,
    mapMinor: HaloColors.line05,
    switchOnTrack: HaloColors.volt,
    switchOnKnob: HaloColors.carbon,
    sliderFill: HaloColors.volt,
    dialAuto: HaloColors.volt,
    dialManual: HaloColors.bone,
    chipFill: HaloColors.volt,
    chipText: HaloColors.carbon,
    yesFill: HaloColors.bone,
    yesText: HaloColors.carbon,
    holdDot: HaloColors.volt,
    mediaFill: HaloColors.bone,
    focusBorder: HaloColors.voltLine,
    focusBorderWidth: 1,
    accordionRule: HaloColors.volt,
    accordionRuleWidth: 1,
    arcStroke: 2,
    routeStroke: 3,
  );

  /// Light. Values are from design/source/*Light.dc.html and Themes.dc.html.
  static const Color _ink = Color(0xFF14140F);

  static const HaloPalette light = HaloPalette(
    brightness: Brightness.light,
    ground: Color(0xFFF3F1E9),
    surface: Color(0xFFFBFAF5),
    well: Color(0xFFEBE8DC),
    text: _ink,
    textDim: Color(0xFF3D3C35),
    muted: Color(0xFF6A685D),
    flare: Color(0xFFE8481A),
    signalFill: HaloColors.volt,
    signalLine: Color(0xFF5F8A00),
    signalText: Color(0xFF4A6700),
    onSignal: _ink,
    fillEdge: _ink,
    border: Color(0x1F14140F), // ink 12%
    divider: Color(0x1F14140F), // 12%
    track: Color(0x1A14140F), // 10%
    soft: Color(0x2414140F), // 14%
    appBorder: Color(0x2914140F), // 16%
    outline: Color(0x4D14140F), // 30%
    switchOff: Color(0x6614140F), // 40%
    ticks: Color(0x4714140F), // 28%
    cells: Color(0x1F14140F), // 12%
    mediaTrack: Color(0x2414140F), // 14%
    sliderTrack: Color(0x3314140F), // 20%
    guide: Color(0x2E14140F), // 18%
    ringsHome: Color(0x1214140F), // 7%
    ringsLock: Color(0x1714140F), // 9%
    holdTrack: Color(0x2914140F), // 16%
    mapRings: Color(0x0F14140F), // 6%
    mapMajor: Color(0x1F14140F), // 12%
    mapMinor: Color(0x1214140F), // 7%
    switchOnTrack: _ink,
    switchOnKnob: HaloColors.volt,
    sliderFill: _ink,
    dialAuto: Color(0xFF5F8A00),
    dialManual: _ink,
    chipFill: _ink,
    chipText: HaloColors.volt,
    yesFill: _ink,
    yesText: Color(0xFFF3F1E9),
    holdDot: _ink,
    mediaFill: _ink,
    focusBorder: _ink,
    focusBorderWidth: 2,
    accordionRule: _ink,
    accordionRuleWidth: 2,
    arcStroke: 2.5,
    routeStroke: 3.5,
  );

  /// The palette in effect, dark when the theme has none.
  static HaloPalette of(BuildContext context) =>
      Theme.of(context).extension<HaloPalette>() ?? dark;

  /// Palettes are fixed sets, so there are no per-field overrides.
  @override
  HaloPalette copyWith() => this;

  /// No tweening between appearances: switching is instant.
  @override
  HaloPalette lerp(HaloPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// `context.halo` is the palette of the current theme.
extension HaloPaletteContext on BuildContext {
  HaloPalette get halo => HaloPalette.of(this);
}
