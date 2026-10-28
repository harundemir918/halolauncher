import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_ui/halo_ui.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio of [text] over [background].
double contrast(Color text, Color background) {
  final a = _luminance(Color.alphaBlend(text, background));
  final b = _luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// Text meets WCAG AA (4.5:1) wherever the palette puts it. Checked on the
/// colors themselves: a pixel check on 11 px mono labels reads their thin,
/// anti-aliased strokes as low contrast when it isn't.
void main() {
  for (final (name, p) in [
    ('dark', HaloPalette.dark),
    ('light', HaloPalette.light),
  ]) {
    group('$name palette text contrast', () {
      final texts = {
        'text': p.text,
        'textDim': p.textDim,
        'muted': p.muted,
        'signalText': p.signalText,
      };
      for (final bg in {'ground': p.ground, 'surface': p.surface}.entries) {
        for (final t in texts.entries) {
          test('${t.key} on ${bg.key}', () {
            expect(contrast(t.value, bg.value), greaterThanOrEqualTo(4.5));
          });
        }
      }
      test('on a Volt fill', () {
        expect(contrast(p.onSignal, p.signalFill), greaterThanOrEqualTo(4.5));
      });
      test('on the chip fill', () {
        expect(contrast(p.chipText, p.chipFill), greaterThanOrEqualTo(4.5));
      });
      test('on the bone Yes button', () {
        expect(contrast(p.yesText, p.yesFill), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
