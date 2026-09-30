import 'package:flutter/material.dart';

class Fonts {
  static const body = 'Manrope';
  static const display = 'SpaceGrotesk';
}

class AccentPreset {
  const AccentPreset(this.name, this.color);
  final String name;
  final Color color;
}

const accentPresets = [
  AccentPreset('Mint', Color(0xFF5EE6C8)),
  AccentPreset('Sky', Color(0xFF5EB8FF)),
  AccentPreset('Indigo', Color(0xFF7C8CFF)),
  AccentPreset('Violet', Color(0xFFB08CFF)),
  AccentPreset('Rose', Color(0xFFFF7AA2)),
  AccentPreset('Coral', Color(0xFFFF8A65)),
  AccentPreset('Amber', Color(0xFFFFC15E)),
  AccentPreset('Lime', Color(0xFFB8E65E)),
];

/// App colours for one brightness, derived from the chosen accent.
///
/// [accent] fills surfaces (selected tiles, switch tracks) with [onAccent]
/// content on top. [accentInk] is the accent for text, icons and small marks
/// on [bg]/[surface]; in light mode it's darkened until it's readable on white.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.hairline,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.warn,
    required this.danger,
  });

  factory AppColors.of(Brightness brightness, Color accent) {
    final onAccent = onColor(accent);
    return brightness == Brightness.dark
        ? AppColors(
            bg: const Color(0xFF0B0D12),
            surface: const Color(0xFF141821),
            surfaceHi: const Color(0xFF1C2230),
            hairline: const Color(0x14FFFFFF),
            text: const Color(0xFFF2F5FA),
            textDim: const Color(0xFF8A94A7),
            accent: accent,
            onAccent: onAccent,
            accentInk: accent,
            warn: const Color(0xFFFFB86B),
            danger: const Color(0xFFFF6B7A),
          )
        : AppColors(
            bg: const Color(0xFFF3F4F7),
            surface: Colors.white,
            surfaceHi: const Color(0xFFEEF0F4),
            hairline: const Color(0x14000000),
            text: const Color(0xFF10141B),
            textDim: const Color(0xFF5D6778),
            accent: accent,
            onAccent: onAccent,
            accentInk: _readableOn(Colors.white, accent),
            warn: const Color(0xFFB26A00),
            danger: const Color(0xFFD6334A),
          );
  }

  final Color bg, surface, surfaceHi, hairline, text, textDim;
  final Color accent, onAccent, accentInk, warn, danger;

  /// Near-black or white, whichever reads better on [fill].
  static Color onColor(Color fill) {
    const ink = Color(0xFF0B0F14);
    return _contrast(fill, ink) >= _contrast(fill, Colors.white) ? ink : Colors.white;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  /// Darkens [color] until it reaches WCAG AA text contrast (4.5:1) on [bg].
  static Color _readableOn(Color bg, Color color) {
    var hsl = HSLColor.fromColor(color);
    while (_contrast(bg, hsl.toColor()) < 4.5 && hsl.lightness > 0.05) {
      hsl = hsl.withLightness(hsl.lightness - 0.02);
    }
    return hsl.toColor();
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHi: l(surfaceHi, other.surfaceHi),
      hairline: l(hairline, other.hairline),
      text: l(text, other.text),
      textDim: l(textDim, other.textDim),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentInk: l(accentInk, other.accentInk),
      warn: l(warn, other.warn),
      danger: l(danger, other.danger),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness, Color accent) {
  final c = AppColors.of(brightness, accent);
  final dark = brightness == Brightness.dark;
  final base = ThemeData(brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(surface: c.bg, primary: c.accentInk, onPrimary: c.onAccent, onSurface: c.text, error: c.danger),
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    fontFamily: Fonts.body,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: c.text.withValues(alpha: 0.04),
    textTheme: base.textTheme.apply(fontFamily: Fonts.body, bodyColor: c.text, displayColor: c.text),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: c.accentInk,
      inactiveTrackColor: c.text.withValues(alpha: 0.10),
      thumbColor: dark ? Colors.white : c.accentInk,
      overlayColor: c.accent.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0, pressedElevation: 0),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
  );
}
