import 'package:flutter/material.dart';

import 'theme.dart';

/// Vertical graphic-EQ sliders. Bands are 0…20 on the wire (10 = flat);
/// values commit on release so we don't flood the RFCOMM link.
class EqualizerBands extends StatefulWidget {
  const EqualizerBands({super.key, required this.bands, required this.onCommit, required this.enabled});
  final List<int> bands;
  final ValueChanged<List<int>> onCommit;
  final bool enabled;

  @override
  State<EqualizerBands> createState() => _EqualizerBandsState();
}

class _EqualizerBandsState extends State<EqualizerBands> {
  List<double>? _drag;

  static List<String> _labels(int n) => switch (n) {
        6 => const ['400', '1k', '2.5k', '6.3k', '16k', 'Bass'],
        5 => const ['400', '1k', '2.5k', '6.3k', '16k'],
        _ => List.generate(n, (i) => '${i + 1}'),
      };

  @override
  Widget build(BuildContext context) {
    final values = _drag ?? widget.bands.map((e) => e.toDouble()).toList();
    final labels = _labels(values.length);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${(values[i] - 10).round() > 0 ? '+' : ''}${(values[i] - 10).round()}',
                    style: const TextStyle(fontFamily: Fonts.display, fontSize: 11, fontWeight: FontWeight.w600, color: Palette.textDim),
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                        child: Slider(
                          min: 0,
                          max: 20,
                          divisions: 20,
                          value: values[i].clamp(0, 20),
                          onChanged: widget.enabled
                              ? (v) => setState(() {
                                    _drag ??= List.of(values);
                                    _drag![i] = v;
                                  })
                              : null,
                          onChangeEnd: (_) {
                            final out = _drag!.map((e) => e.round()).toList();
                            setState(() => _drag = null);
                            widget.onCommit(out);
                          },
                        ),
                      ),
                    ),
                  ),
                  Text(labels[i], style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Palette.textDim)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
