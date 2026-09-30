import 'package:flsony/core/app_settings.dart';
import 'package:flsony/core/headphones_controller.dart';
import 'package:flsony/ui/home_page.dart';
import 'package:flsony/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home renders and settings shows opt-in extras', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    tester.view.physicalSize = const Size(420, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: HomePage(controller: HeadphonesController(), settings: settings),
      ),
    );
    expect(find.text('Not connected'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Pause media before power off'), findsOneWidget);
    expect(settings.pauseBeforePowerOff, isFalse);

    await tester.tap(find.text('Pause media before power off'));
    await tester.pump();
    expect(settings.pauseBeforePowerOff, isTrue);
  });
}
