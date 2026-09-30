import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OS integrations that aren't Bluetooth (media control, …).
class SystemBridge {
  static const _method = MethodChannel('flsony/system');

  /// Pauses whatever is playing. A no-op if nothing is; never starts playback.
  /// Gives up after a few seconds so power-off never hangs on it.
  Future<bool> pauseMedia() async {
    try {
      return await _method
              .invokeMethod<bool>('pauseMedia')
              .timeout(const Duration(seconds: 4), onTimeout: () => false) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('pauseMedia failed: ${e.message}');
      return false;
    }
  }

  /// Asks now for permission to control running media players, so the
  /// prompt doesn't appear at power-off time.
  Future<void> prepareMediaPause() async {
    try {
      await _method.invokeMethod<void>('prepareMediaPause');
    } on MissingPluginException {
      // Not implemented on this platform yet.
    }
  }
}
