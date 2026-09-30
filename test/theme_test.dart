import 'package:flsony/core/app_settings.dart';
import 'package:flsony/core/headphones_controller.dart';
import 'package:flsony/ui/home_page.dart';
import 'package:flsony/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  test('every accent is readable as text in both themes', () {
    for (final p in accentPresets) {
      for (final b in Brightness.values) {
        final c = AppColors.of(b, p.color);
        expect(contrast(c.accentInk, c.surface), greaterThanOrEqualTo(4.5), reason: '${p.name} ink on $b');
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5), reason: '${p.name} on-accent on $b');
      }
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('home renders in $mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      tester.view.physicalSize = const Size(420, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light, accentPresets[3].color),
          darkTheme: buildTheme(Brightness.dark, accentPresets[3].color),
          themeMode: mode,
          home: HomePage(controller: HeadphonesController(), settings: settings),
        ),
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('APPEARANCE'), findsOneWidget);
    });
  }
}
