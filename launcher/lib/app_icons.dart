import 'package:flutter/painting.dart';
import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

/// Glyph for an app: its design role's glyph, else the glyph matching its id
/// (the mock), else the notes glyph.
HaloIcons iconFor(HaloAppInfo app) {
  for (final i in HaloIcons.values) {
    if (i.name == app.glyph) return i;
  }
  for (final i in HaloIcons.values) {
    if (i.name == app.id) return i;
  }
  return HaloIcons.notes;
}

/// The app's own icon, when the platform gave one.
ImageProvider? imageFor(HaloAppInfo app) =>
    app.icon == null ? null : MemoryImage(app.icon!);

/// The app's monochrome icon layer, when the platform gave one.
ImageProvider? monoImageFor(HaloAppInfo app) =>
    app.monoIcon == null ? null : MemoryImage(app.monoIcon!);
