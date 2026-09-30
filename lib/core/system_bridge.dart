import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OS integrations that aren't Bluetooth (media control, …).
class SystemBridge {
  static const _method = MethodChannel('flsony/system');

  /// Pauses whatever is playing. A no-op if nothing is; never starts playback.
  Future<bool> pauseMedia() async {
    try {
      return await _method.invokeMethod<bool>('pauseMedia') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('pauseMedia failed: ${e.message}');
      return false;
    }
  }
}
