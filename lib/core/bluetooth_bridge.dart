import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LinkState { disconnected, connecting, connected, failed }

sealed class BridgeEvent {}

class StatusEvent extends BridgeEvent {
  StatusEvent(this.state, {this.deviceName, this.reason, this.details = const {}});
  final LinkState state;
  final String? deviceName;
  final String? reason;
  final Map<String, String> details;
}

class DataEvent extends BridgeEvent {
  DataEvent(this.bytes);
  final Uint8List bytes;
}

/// Headphones are present at the Bluetooth (ACL) level, independent of
/// whether our RFCOMM control channel is open.
class ReachabilityEvent extends BridgeEvent {
  ReachabilityEvent(this.reachable, this.deviceName);
  final bool reachable;
  final String? deviceName;
}

/// Thin byte pipe to the platform's classic-Bluetooth RFCOMM stack
/// (IOBluetooth on macOS, Windows.Devices.Bluetooth.Rfcomm on Windows).
/// All Sony protocol logic lives in Dart.
class BluetoothBridge {
  static const _method = MethodChannel('flsony/bt');
  static const _events = EventChannel('flsony/bt/events');

  Stream<BridgeEvent> get events => _events.receiveBroadcastStream().map((raw) {
        final m = Map<String, Object?>.from(raw as Map);
        switch (m['type']) {
          case 'data':
            return DataEvent(m['bytes'] as Uint8List);
          case 'reachable':
            return ReachabilityEvent(m['value'] == true, m['name'] as String?);
          default:
            return StatusEvent(
              LinkState.values.byName(m['state'] as String),
              deviceName: m['name'] as String?,
              reason: m['reason'] as String?,
              details: Map<String, String>.from((m['details'] as Map?) ?? const {}),
            );
        }
      });

  Future<void> startMonitoring() => _invoke('startMonitoring');
  Future<void> connect() => _invoke('connect');
  Future<void> disconnect() => _invoke('disconnect');
  Future<void> send(Uint8List data) => _invoke('send', data);

  Future<void> _invoke(String method, [Object? args]) async {
    try {
      await _method.invokeMethod<void>(method, args);
    } on MissingPluginException {
      debugPrint('Bluetooth bridge not available on this platform');
    } on PlatformException catch (e) {
      debugPrint('bt.$method failed: ${e.message}');
    }
  }
}
