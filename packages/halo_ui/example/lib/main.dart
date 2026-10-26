import 'package:flutter/material.dart';
import 'package:halo_ui/halo_ui.dart';

void main() => runApp(const GalleryApp());

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: HaloTheme.dark(),
    home: const Gallery(),
  );
}

class Gallery extends StatelessWidget {
  const Gallery({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HaloTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: HaloSpace.gutter,
            vertical: HaloSpace.g18,
          ),
          children: [
            Text(HaloType.upper('halo_ui · tokens'), style: HaloType.label),
            const SizedBox(height: HaloSpace.g12),
            Text('Design review in 19 min', style: HaloType.headline),
            const SizedBox(height: HaloSpace.g18),
            _section('Color'),
            Wrap(
              spacing: HaloSpace.g8,
              runSpacing: HaloSpace.g8,
              children: [
                _swatch('carbon', HaloColors.carbon),
                _swatch('surface', HaloColors.surface),
                _swatch('bone', HaloColors.bone),
                _swatch('boneDim', HaloColors.boneDim),
                _swatch('ash', HaloColors.ash),
                _swatch('volt', HaloColors.volt),
                _swatch('flare', HaloColors.flare),
              ],
            ),
            _section('Voice · Bricolage Grotesque'),
            for (final (name, style) in [
              ('display', HaloType.display),
              ('screenTitle', HaloType.screenTitle),
              ('headline', HaloType.headline),
              ('sectionTitle', HaloType.sectionTitle),
              ('title', HaloType.title),
              ('body', HaloType.body),
              ('button', HaloType.button),
            ]) ...[
              Text(
                HaloType.upper(name),
                style: HaloType.labelSmall.copyWith(color: tokens.ash),
              ),
              Text(
                name == 'display' ? '3 need you.' : 'Switchboard 64 / 42',
                style: style,
              ),
              const SizedBox(height: HaloSpace.g12),
            ],
            _section('Weights 400 · 500 · 700 · 800'),
            for (final w in [400, 500, 700, 800])
              Text(
                'Elif, Karaköy $w',
                style: HaloType.title.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.values[w ~/ 100 - 1],
                  fontVariations: [FontVariation.weight(w.toDouble())],
                ),
              ),
            _section('Mono · DM Mono'),
            Text(HaloType.upper('Now · Room 3 · 10:00'), style: HaloType.label),
            Text(HaloType.upper('Full by 10:20'), style: HaloType.labelSmall),
            Text('09:41  82%  5G', style: HaloType.monoValue),
            _section('Notch'),
            Wrap(
              spacing: HaloSpace.g12,
              runSpacing: HaloSpace.g12,
              children: [
                for (final (name, r) in [
                  ('XS', HaloRadii.notchXS),
                  ('S', HaloRadii.notchS),
                  ('M', HaloRadii.notchM),
                  ('ML', HaloRadii.notchML),
                  ('L', HaloRadii.notchL),
                  ('XL', HaloRadii.notchXL),
                  ('XXL', HaloRadii.notchXXL),
                ])
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: HaloColors.surface,
                      shape: NotchBorder(
                        radius: r,
                        side: const BorderSide(color: HaloColors.line08),
                      ),
                    ),
                    child: Text(name, style: HaloType.label),
                  ),
              ],
            ),
            const _WidgetsDemo(),
          ],
        ),
      ),
    );
  }

  static Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: HaloSpace.g12),
    child: Text(
      HaloType.upper(t),
      style: HaloType.label.copyWith(color: HaloColors.ash),
    ),
  );

  static Widget _swatch(String name, Color c) => Container(
    width: 96,
    height: 64,
    padding: const EdgeInsets.all(HaloSpace.g8),
    alignment: Alignment.bottomLeft,
    decoration: ShapeDecoration(
      color: c,
      shape: const NotchBorder(
        radius: HaloRadii.notchS,
        side: BorderSide(color: HaloColors.line12),
      ),
    ),
    child: Text(
      name,
      style: HaloType.labelSmall.copyWith(
        color: c.computeLuminance() > 0.4 ? HaloColors.carbon : HaloColors.bone,
      ),
    ),
  );
}

class _WidgetsDemo extends StatefulWidget {
  const _WidgetsDemo();

  @override
  State<_WidgetsDemo> createState() => _WidgetsDemoState();
}

class _WidgetsDemoState extends State<_WidgetsDemo> {
  bool wifi = true;
  bool bluetooth = true;
  bool airplane = false;
  String appearance = 'dark';
  double textSize = 0.46;

  @override
  Widget build(BuildContext context) {
    final tokens = HaloTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Gallery._section('Kicker · Buttons'),
        const HaloKicker('Now'),
        const SizedBox(height: HaloSpace.g12),
        Wrap(
          spacing: HaloSpace.g8,
          runSpacing: HaloSpace.g8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            HaloButton(label: 'Navigate', onPressed: () {}),
            HaloButton(
              label: 'Open notes',
              variant: HaloButtonVariant.secondary,
              onPressed: () {},
            ),
            HaloButton(
              label: 'Yes',
              variant: HaloButtonVariant.bone,
              size: HaloButtonSize.small,
              onPressed: () {},
            ),
            HaloButton(
              label: 'Later',
              variant: HaloButtonVariant.secondary,
              size: HaloButtonSize.small,
              onPressed: () {},
            ),
          ],
        ),
        Gallery._section('Toggle rows'),
        HaloToggleRow(
          title: 'Wi-Fi',
          subtitle: 'Home-5G',
          value: wifi,
          onChanged: (v) => setState(() => wifi = v),
        ),
        const SizedBox(height: HaloSpace.g6),
        HaloToggleRow(
          title: 'Bluetooth',
          subtitle: '2 devices',
          value: bluetooth,
          onChanged: (v) => setState(() => bluetooth = v),
        ),
        const SizedBox(height: HaloSpace.g6),
        HaloToggleRow(
          title: 'Airplane',
          subtitle: 'Off',
          value: airplane,
          onChanged: (v) => setState(() => airplane = v),
        ),
        Gallery._section('Segmented · Slider'),
        HaloSegmented<String>(
          value: appearance,
          onChanged: (v) => setState(() => appearance = v),
          options: const [
            HaloSegment('dark', 'Dark'),
            HaloSegment('light', 'Light'),
            HaloSegment('auto', 'Auto'),
          ],
        ),
        const SizedBox(height: HaloSpace.g18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              HaloType.upper('Text size'),
              style: HaloType.label.copyWith(color: tokens.ash),
            ),
            Text(
              '${(12 + textSize * 8).round()}',
              style: HaloType.label.copyWith(color: HaloColors.bone),
            ),
          ],
        ),
        const SizedBox(height: HaloSpace.g12),
        HaloSlider(
          value: textSize,
          onChanged: (v) => setState(() => textSize = v),
          semanticLabel: 'Text size',
        ),
        Gallery._section('Battery'),
        const HaloBatteryLine(fraction: 0.82),
        const SizedBox(height: HaloSpace.g12),
        const HaloBatteryCells(fraction: 0.82),
      ],
    );
  }
}
