import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_profile.dart';

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

  bool get menuBarIcon => _get('extras.menuBarIcon', false);
  set menuBarIcon(bool v) => _set('extras.menuBarIcon', v);

  bool get profilesEnabled => _get('extras.profiles', false);
  set profilesEnabled(bool v) => _set('extras.profiles', v);

  List<SoundProfile> get profiles => [
    for (final raw in _prefs.getStringList('extras.profiles.list') ?? const <String>[])
      SoundProfile.fromJson(jsonDecode(raw) as Map<String, Object?>),
  ];

  set profiles(List<SoundProfile> value) {
    _prefs.setStringList('extras.profiles.list', [for (final p in value) jsonEncode(p.toJson())]);
    notifyListeners();
  }
}
