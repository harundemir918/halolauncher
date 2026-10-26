import 'package:halo_sdk/halo_sdk.dart';
import 'package:halo_ui/halo_ui.dart';

/// Icon for an installed app. Unknown ids fall back to the notes glyph.
HaloIcons iconFor(HaloAppInfo app) {
  for (final i in HaloIcons.values) {
    if (i.name == app.id) return i;
  }
  return HaloIcons.notes;
}
