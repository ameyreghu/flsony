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
            title: 'Extras',
            trailing: const _Badge('Not in Sound Connect'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Features this app adds on top of Sony\'s. All are off until you turn them on.',
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: Palette.textDim),
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
                      const Divider(height: 1, color: Palette.hairline),
                      ToggleRow(
                        icon: Icons.bookmarks_outlined,
                        title: 'Profiles',
                        subtitle: 'Save sound setups and switch in one click',
                        value: settings.profilesEnabled,
                        onChanged: () => settings.profilesEnabled = !settings.profilesEnabled,
                      ),
                      const Divider(height: 1, color: Palette.hairline),
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
    decoration: BoxDecoration(color: Palette.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Palette.accent),
    ),
  );
}
