import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_settings.dart';
import 'core/headphones_controller.dart';
import 'core/system_bridge.dart';
import 'ui/home_page.dart';
import 'ui/menu_bar.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(420, 780),
      minimumSize: const Size(380, 560),
      center: true,
      title: 'FlSony',
      backgroundColor: AppColors.of(_brightness(settings.themeMode), settings.accent).bg,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final system = SystemBridge();
  final controller = HeadphonesController()
    ..beforePowerOff = () async {
      if (!settings.pauseBeforePowerOff) return;
      if (await system.pauseMedia()) {
        // Let the player actually stop before A2DP drops.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    ..start();
  await TrayMenu(controller, settings).init();
  runApp(FlSonyApp(controller: controller, settings: settings));
}

Brightness _brightness(ThemeMode mode) => switch (mode) {
  ThemeMode.light => Brightness.light,
  ThemeMode.dark => Brightness.dark,
  ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
};

class FlSonyApp extends StatelessWidget {
  const FlSonyApp({super.key, required this.controller, required this.settings});
  final HeadphonesController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'FlSony',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, settings.accent),
        darkTheme: buildTheme(Brightness.dark, settings.accent),
        themeMode: settings.themeMode,
        home: HomePage(controller: controller, settings: settings),
      ),
    );
  }
}
