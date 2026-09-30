import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/system_bridge.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showSettings(BuildContext context, AppSettings settings) => showPanelDialog(
  context,
  title: 'Settings',
  child: _Settings(settings: settings),
);

class _Settings extends StatelessWidget {
  const _Settings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        children: [
          Section(
            title: 'Appearance',
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Segmented<ThemeMode>(
                    enabled: true,
                    height: 64,
                    value: settings.themeMode,
                    onChanged: (m) => settings.themeMode = m,
                    options: const [
                      SegmentOption(ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                      SegmentOption(ThemeMode.light, 'Light', Icons.light_mode_rounded),
                      SegmentOption(ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Accent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in accentPresets)
                        _Swatch(
                          preset: p,
                          selected: p.color.toARGB32() == settings.accent.toARGB32(),
                          onTap: () => settings.accent = p.color,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Section(
            title: 'Extras',
            trailing: const _Badge('Not in Sound Connect'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Features this app adds on top of Sony\'s. All are off until you turn them on.',
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: context.colors.textDim),
                  ),
                ),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      ToggleRow(
                        icon: Icons.space_dashboard_outlined,
                        title: Platform.isWindows ? 'System tray icon' : 'Menu bar icon',
                        subtitle: 'Battery and quick controls; closing the window keeps the app running',
                        value: settings.menuBarIcon,
                        onChanged: () => settings.menuBarIcon = !settings.menuBarIcon,
                      ),
                      Divider(height: 1, color: context.colors.hairline),
                      ToggleRow(
                        icon: Icons.bookmarks_outlined,
                        title: 'Profiles',
                        subtitle: 'Save sound setups and switch in one click',
                        value: settings.profilesEnabled,
                        onChanged: () => settings.profilesEnabled = !settings.profilesEnabled,
                      ),
                      Divider(height: 1, color: context.colors.hairline),
                      ToggleRow(
                        icon: Icons.pause_circle_outline_rounded,
                        title: 'Pause media before power off',
                        subtitle: 'Pauses Music, Spotify and TV so audio doesn\'t jump to your speakers',
                        value: settings.pauseBeforePowerOff,
                        onChanged: () {
                          settings.pauseBeforePowerOff = !settings.pauseBeforePowerOff;
                          if (settings.pauseBeforePowerOff) SystemBridge().prepareMediaPause();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.colors.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: context.colors.accentInk),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.preset, required this.selected, required this.onTap});
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor = AppColors.onColor(preset.color);
    return Tooltip(
      message: preset.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? context.colors.text : Colors.transparent, width: 2),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: preset.color, shape: BoxShape.circle),
              child: selected ? Icon(Icons.check_rounded, size: 16, color: onColor) : null,
            ),
          ),
        ),
      ),
    );
  }
}
