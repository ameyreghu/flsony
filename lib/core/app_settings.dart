import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app preferences. "Extras" are features Sony's Sound Connect
/// app doesn't have; each one is opt-in and off by default.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static Future<AppSettings> load() async => AppSettings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  bool _get(String key, bool fallback) => _prefs.getBool(key) ?? fallback;

  void _set(String key, bool value) {
    _prefs.setBool(key, value);
    notifyListeners();
  }

  // --- Extras -------------------------------------------------------------
  bool get pauseBeforePowerOff => _get('extras.pauseBeforePowerOff', false);
  set pauseBeforePowerOff(bool v) => _set('extras.pauseBeforePowerOff', v);
}
