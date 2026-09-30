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
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(420, 780),
      minimumSize: const Size(380, 560),
      center: true,
      title: 'FlSony',
      backgroundColor: Palette.bg,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final settings = await AppSettings.load();
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

class FlSonyApp extends StatelessWidget {
  const FlSonyApp({super.key, required this.controller, required this.settings});
  final HeadphonesController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlSony',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(controller: controller, settings: settings),
    );
  }
}
