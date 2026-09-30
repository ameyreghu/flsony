import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFF0B0D12);
  static const surface = Color(0xFF141821);
  static const surfaceHi = Color(0xFF1C2230);
  static const hairline = Color(0x14FFFFFF);
  static const text = Color(0xFFF2F5FA);
  static const textDim = Color(0xFF8A94A7);
  static const accent = Color(0xFF5EE6C8);
  static const warn = Color(0xFFFFB86B);
  static const danger = Color(0xFFFF6B7A);
}

class Fonts {
  static const body = 'Manrope';
  static const display = 'SpaceGrotesk';
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: Palette.bg,
    primary: Palette.accent,
    onPrimary: Color(0xFF04201A),
    onSurface: Palette.text,
    error: Palette.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    fontFamily: Fonts.body,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white.withValues(alpha: 0.04),
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: Fonts.body,
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: Palette.accent,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
      thumbColor: Colors.white,
      overlayColor: Palette.accent.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0, pressedElevation: 0),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
  );
}
