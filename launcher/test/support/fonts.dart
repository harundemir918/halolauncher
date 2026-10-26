import 'dart:io';

import 'package:flutter/services.dart';

/// `flutter test` does not load package fonts, so load the bundled ones from
/// halo_ui. Without this, golden text renders as blocks.
Future<void> loadHaloFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader('packages/halo_ui/$family');
    for (final f in files) {
      final bytes = File('../packages/halo_ui/assets/fonts/$f')
          .readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Bricolage Grotesque', ['BricolageGrotesque-Variable.ttf']);
  await load('DM Mono', ['DMMono-Regular.ttf', 'DMMono-Medium.ttf']);
}
