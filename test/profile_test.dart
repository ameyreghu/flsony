import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flsony/core/bluetooth_bridge.dart';
import 'package:flsony/core/headphones_controller.dart';
import 'package:flsony/core/sony_packet.dart';
import 'package:flsony/core/sound_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBridge extends BluetoothBridge {
  final events$ = StreamController<BridgeEvent>.broadcast(sync: true);
  final sent = <Uint8List>[];

  @override
  Stream<BridgeEvent> get events => events$.stream;
  @override
  Future<void> startMonitoring() async {}
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> send(Uint8List data) async => sent.add(data);

  /// Command payloads we sent, ignoring ACKs.
  List<List<int>> get commands => [
    for (final p in SonyFrameParser().feed(sent.expand((b) => b).toList()))
      if (p.dataType == SonyDataType.command1) p.payload,
  ];
}

/// Connects the controller and completes the handshake.
HeadphonesController connected(FakeBridge bridge, FakeAsync async) {
  final c = HeadphonesController(bridge: bridge)..start();
  async.flushMicrotasks();
  bridge.events$.add(StatusEvent(LinkState.connected, deviceName: 'WH-1000XM4'));
  // Any command from the headphones completes INIT.
  bridge.events$.add(DataEvent(encodeSonyPacket(const SonyPacket(SonyDataType.command1, 0, [0x01, 0x00]))));
  async.elapse(const Duration(seconds: 5)); // let discovery queries go out
  expect(c.isReady, isTrue);
  bridge.sent.clear();
  return c;
}

void main() {
  test('applying a profile sends NC/ambient, Speak-to-Chat, then EQ preset', () {
    fakeAsync((async) {
      final bridge = FakeBridge();
      final c = connected(bridge, async);

      c.applyProfile(
        const SoundProfile(
          name: 'Office',
          ncMode: NcMode.ambient,
          ambientLevel: 12,
          focusOnVoice: true,
          speakToChat: true,
          eqPresetId: 0x16,
        ),
      );
      async.elapse(const Duration(seconds: 2));

      final sets = bridge.commands.where((p) => const {0x68, 0xF8, 0x58}.contains(p.first)).toList();
      expect(sets, [
        [0x68, 0x02, 0x11, 0x02, 0x00, 0x01, 0x01, 12], // ambient, Focus on voice, level 12
        [0xF8, 0x05, 0x01, 0x01], // Speak-to-Chat on
        [0x58, 0x01, 0x16, 0x00], // Bass Boost preset
      ]);
    });
  });

  test('an unsaved custom curve is restored under 0xFF, never into the selected Custom slot', () {
    fakeAsync((async) {
      final bridge = FakeBridge();
      final c = connected(bridge, async)..eqPresetId = 0xA1; // Custom 1 currently selected

      c.applyProfile(const SoundProfile(name: 'Curve', eqPresetId: 0xA0, eqBands: [10, 12, 14, 10, 8, 10]));
      async.elapse(const Duration(seconds: 2));

      final eq = bridge.commands.where((p) => p.first == 0x58).toList();
      expect(eq, [
        [0x58, 0x01, 0xFF, 6, 10, 12, 14, 10, 8, 10],
      ]);
    });
  });

  test('profiles survive a JSON round trip', () {
    const p = SoundProfile(name: 'Focus', ncMode: NcMode.noiseCancelling, speakToChat: false, eqPresetId: 0xA2);
    final back = SoundProfile.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
  });
}
