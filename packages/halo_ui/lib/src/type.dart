import 'package:flutter/painting.dart';

/// Halo type tokens. See docs/DESIGN_SYSTEM.md §3.
///
/// Where the design gives a range, the value is the one used most often in
/// `design/source/*.dc.html`; use [TextStyle.copyWith] for the odd screen.
/// Styles carry no color: the caller picks bone, boneDim or ash.
///
/// Bricolage Grotesque is a variable font, so the weight axis is set
/// explicitly. Mono labels are UPPERCASE: use [HaloType.upper] on the string.
abstract final class HaloType {
  static const String voiceFamily = 'Bricolage Grotesque';
  static const String monoFamily = 'DM Mono';
  static const String package = 'halo_ui';

  static TextStyle _voice(
    double size,
    int weight,
    double tracking, {
    double? height,
  }) => TextStyle(
    fontFamily: voiceFamily,
    package: package,
    fontSize: size,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    // The design export uses the font's default optical size, so we do too
    // (setting opsz from the font size makes large text visibly narrower).
    fontVariations: [FontVariation.weight(weight.toDouble())],
    letterSpacing: size * tracking,
    height: height,
  );

  static TextStyle _mono(
    double size,
    int weight,
    double tracking, {
    double? height,
  }) => TextStyle(
    fontFamily: monoFamily,
    package: package,
    fontSize: size,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    letterSpacing: size * tracking,
    height: height,
  );

  // Voice: Bricolage Grotesque. Negative tracking.
  static final TextStyle clockHero = _voice(196, 800, -0.05, height: 0.8);
  static final TextStyle display = _voice(92, 800, -0.045, height: 1);
  static final TextStyle screenTitle = _voice(36, 800, -0.04, height: 1);
  static final TextStyle headline = _voice(38, 800, -0.04, height: 1);
  static final TextStyle dialValue = _voice(38, 800, -0.04, height: 1);
  static final TextStyle sectionTitle = _voice(24, 700, -0.03);
  static final TextStyle title = _voice(19, 700, -0.02);
  static final TextStyle body = _voice(16, 500, 0, height: 1.3);
  static final TextStyle rowTitle = _voice(16, 600, 0);

  /// Primary button label; [buttonLight] is the secondary button.
  static final TextStyle button = _voice(15, 700, 0);
  static final TextStyle buttonLight = _voice(15, 500, 0);

  /// Small inline buttons ("Yes", "Later").
  static final TextStyle buttonSmall = _voice(13, 700, 0);
  static final TextStyle buttonSmallLight = _voice(13, 500, 0);

  // Mono: DM Mono. Positive tracking, UPPERCASE for labels.
  static final TextStyle label = _mono(11, 500, 0.12);
  static final TextStyle labelSmall = _mono(10.5, 400, 0.09);
  static final TextStyle monoValue = _mono(13, 500, 0.06);

  /// Status row at the top of every screen (`LOCKED`, `5G · WI-FI · 82%`).
  static final TextStyle status = _mono(11, 400, 0.08);

  /// Date line under the Lock clock (`FRIDAY — 23 OCTOBER`).
  static final TextStyle dateLine = _mono(12, 400, 0.14);

  /// Time inside the Volt tile (`10:00`).
  static final TextStyle tileTime = _mono(15, 500, 0);

  /// Title in an event card (`Design review · Room 3`).
  static final TextStyle cardTitle = _voice(18, 700, -0.01);

  /// Notification preview body on Lock.
  static final TextStyle preview = _voice(14, 400, 0);

  /// Home headline ("Design review in 19 min"). [headline] is the 38 px one.
  static final TextStyle headlineL = _voice(42, 800, -0.04, height: 1);

  /// Context line under the Home headline (`ROOM 3 · 2 MIN WALK`).
  static final TextStyle context = _mono(12, 400, 0.08);

  /// Time in an agenda row (`10:00`).
  static final TextStyle timeLabel = _mono(12, 400, 0);

  /// Agenda and inline-card titles (`Design review`, `Still on for 7?`).
  static final TextStyle itemTitle = _voice(17, 600, -0.01);

  /// Small mono metadata with no tracking: ages and row trailers (`2M`, `ROOM 3`).
  static final TextStyle meta = _mono(11, 400, 0);

  /// Caption inside a dial under its value (`LIGHT`).
  static final TextStyle dialCaption = _mono(10, 400, 0.16);

  /// Mono footer under a dial or a row of cells (`AUTO · ON`, `FULL BY 10:20`).
  static final TextStyle footer = _mono(11, 400, 0.1);

  /// Track title in the media strip.
  static final TextStyle mediaTitle = _voice(15, 600, 0);

  /// "3 need you." on the Stream summary card. [display] is the 92 px one.
  static final TextStyle displayS = _voice(44, 800, -0.045, height: 1);

  /// Numbered lines on the summary card.
  static final TextStyle summaryItem = _voice(15, 600, -0.005);

  /// "4 NEW" chip.
  static final TextStyle chip = _mono(11, 500, 0.1);

  /// Underlined text action (`REPLY`, `LATER`).
  static final TextStyle textAction = _mono(11, 400, 0.12);

  /// Command field text (`find a setting`).
  static final TextStyle command = _mono(14, 400, 0);

  /// Initials in the avatar (`AS`).
  static final TextStyle avatar = _mono(13, 500, 0);

  /// Right-hand status on an accordion row (`HOME-5G`, `OPEN`).
  static final TextStyle accordionStatus = _mono(11, 400, 0.06);

  /// Label above a control (`APPEARANCE`, `TEXT SIZE`).
  static final TextStyle fieldLabel = _mono(11, 400, 0.12);

  /// Rotated label on a collapsed slat (`MESSAGES`).
  static final TextStyle slatLabel = _mono(11, 400, 0.16);

  /// Count next to a screen title (`05`).
  static final TextStyle count = _mono(13, 400, 0);

  /// Small sentence under a figure (`3.4 km via Galata`).
  static final TextStyle note = _voice(13, 400, 0);

  /// Section kicker (`NOW`) and list-section labels (`TODAY`).
  static final TextStyle kicker = _mono(11, 400, 0.14);

  /// Sub-label under a row title (`HOME-5G`).
  static final TextStyle caption = _mono(10.5, 400, 0.08);

  /// Segmented control option; [segmentSelected] for the chosen one.
  static final TextStyle segment = _mono(12, 400, 0.1);
  static final TextStyle segmentSelected = _mono(12, 500, 0.1);

  /// Mono labels are uppercase by design.
  static String upper(String s) => s.toUpperCase();
}
