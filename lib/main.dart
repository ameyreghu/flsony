import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/headphones_controller.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(420, 780),
      minimumSize: const Size(380, 560),
      center: true,
      title: 'Sony Connect',
      backgroundColor: Palette.bg,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final controller = HeadphonesController()..start();
  runApp(SonyConnectApp(controller: controller));
}

class SonyConnectApp extends StatelessWidget {
  const SonyConnectApp({super.key, required this.controller});
  final HeadphonesController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sony Connect',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(controller: controller),
    );
  }
}
