import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bluetooth_bridge.dart';
import 'sony_packet.dart';

enum NcMode { noiseCancelling, ambient, off }

class EqPreset {
  const EqPreset(this.id, this.name);
  final int id;
  final String name;
}

class FeatureSlot {
  const FeatureSlot(this.slot, this.name, this.type);
  final int slot;
  final String name;
  final String type;
}

class LogLine {
  const LogLine(this.time, this.tx, this.hex);
  final DateTime time;
  final bool tx;
  final String hex;
}

enum Phase { unavailable, idle, connecting, ready }

// Sony MDR V1 opcodes (from the Sony Headphones Connect decompile, see the
// sony-connect-osx reference implementation).
class _Op {
  static const initRequest = 0x00;
  static const batteryGet = 0x10, batteryRet = 0x11, batteryNotify = 0x13;
  static const powerOff = 0x22;
  static const eqGetCapability = 0x50, eqRetCapability = 0x51;
  static const eqGetParam = 0x56, eqRetParam = 0x57, eqSetParam = 0x58, eqNotify = 0x59;
  static const eqPresetType = 0x01, eqCustom = 0xA0, eqUnspecified = 0xFF;
  static const ncasmGet = 0x66, ncasmRet = 0x67, ncasmSet = 0x68, ncasmNotify = 0x69;
  static const ncasmCombined = 0x02;
  static const gsGetCapability = 0xD0, gsRetCapability = 0xD1;
  static const touchGet = 0xD6, touchRet = 0xD7, touchSet = 0xD8;
  static const gsSlots = [0xD1, 0xD2, 0xD3];
  static const systemGet = 0xF6, systemRet = 0xF7, systemSet = 0xF8, systemNotify = 0xF9;
  static const smartTalking = 0x05;
  static const deviceInfoGet = 0x04, deviceInfoRet = 0x05;
  // Unverified (community protocol notes): audio codec query.
  static const codecGet = 0x18, codecRet = 0x19, codecNotify = 0x1B;
}

class HeadphonesController extends ChangeNotifier {
  HeadphonesController({BluetoothBridge? bridge}) : _bridge = bridge ?? BluetoothBridge();

  static const maxAmbientLevel = 20;
  static const reconnectDelay = Duration(seconds: 5);

  final BluetoothBridge _bridge;
  final _parser = SonyFrameParser();
  StreamSubscription<BridgeEvent>? _sub;
  Timer? _reconnectTimer;
  final List<Timer> _sessionTimers = [];

  // --- Public state -------------------------------------------------------
  Phase phase = Phase.unavailable;
  String deviceName = 'WH-1000XM4';
  String? failureReason;
  bool? touchSensor;
  NcMode? ncMode;
  bool? speakToChat;
  int? battery;
  bool charging = false;
  List<EqPreset> eqPresets = const [];
  int? eqPresetId;
  List<int> eqBands = const [];
  int ambientLevel = maxAmbientLevel;
  bool ambientFocusOnVoice = false;

  // --- Diagnostics --------------------------------------------------------
  Map<String, String> linkDetails = const {};
  DateTime? connectedAt;
  int txPackets = 0, rxPackets = 0;
  String? modelName, firmwareVersion, audioCodec;
  List<FeatureSlot> featureSlots = const [];
  final List<LogLine> packetLog = [];

  bool get isReady => phase == Phase.ready;

  // --- Session state ------------------------------------------------------
  int _seq = 0;
  bool _awaitingInit = false;
  bool _initialized = false;
  bool _reachable = false;
  bool _linkOpen = false;
  bool _disposed = false;
  int? _touchSlot;
  bool _touchIsList = false;
  int _ncType = 0x02;
  int _asmType = 0x01;
  int _asmId = 0x00;

  Future<void> start() async {
    _sub = _bridge.events.listen(_onEvent);
    await _bridge.startMonitoring();
    await connect();
  }

  Future<void> connect() async {
    _reconnectTimer?.cancel();
    if (_linkOpen || phase == Phase.connecting) return;
    phase = Phase.connecting;
    failureReason = null;
    notifyListeners();
    await _bridge.connect();
  }

  Future<void> reconnect() async {
    await _bridge.disconnect();
    _resetSession();
    await connect();
  }

  // --- Commands -----------------------------------------------------------
  void toggleTouchSensor() {
    if (!isReady) return;
    final next = !(touchSensor ?? false);
    final slot = _touchSlot ?? _Op.gsSlots.first;
    _send([_Op.touchSet, slot, _touchIsList ? 0x02 : 0x01, next ? 1 : 0]);
    touchSensor = next;
    notifyListeners();
    _later(300, () => _send([_Op.touchGet, slot]));
  }

  void setNcMode(NcMode mode) {
    if (!isReady) return;
    _sendNcasm(mode);
    ncMode = mode;
    notifyListeners();
    _later(300, _requestNcasm);
  }

  void setAmbientLevel(int level) {
    if (!isReady) return;
    ambientLevel = level.clamp(0, maxAmbientLevel);
    notifyListeners();
    if (ncMode != NcMode.ambient) return;
    _sendNcasm(NcMode.ambient);
  }

  void setAmbientFocusOnVoice(bool on) {
    if (!isReady) return;
    _asmId = on ? 0x01 : 0x00;
    ambientFocusOnVoice = on;
    notifyListeners();
    if (ncMode == NcMode.ambient) _sendNcasm(NcMode.ambient);
  }

  void toggleSpeakToChat() {
    if (!isReady) return;
    final next = !(speakToChat ?? false);
    _send([_Op.systemSet, _Op.smartTalking, 0x01, next ? 1 : 0]);
    speakToChat = next;
    notifyListeners();
    _later(300, () => _send([_Op.systemGet, _Op.smartTalking]));
  }

  void setEqPreset(int id) {
    if (!isReady) return;
    _send([_Op.eqSetParam, _Op.eqPresetType, id, 0x00]);
    eqPresetId = id;
    notifyListeners();
    _later(300, () => _send([_Op.eqGetParam, _Op.eqPresetType]));
  }

  void setEqBands(List<int> bands) {
    if (!isReady || bands.isEmpty) return;
    // Custom values must go out under UNSPECIFIED (0xFF) to persist; 0xA0 is
    // a volatile preview the headphones drop on the next session.
    final slot = eqPresetId;
    final target = slot != null && slot >= 0xA1 && slot <= 0xA5 ? slot : _Op.eqUnspecified;
    _send([_Op.eqSetParam, _Op.eqPresetType, target, bands.length, ...bands.map((b) => b.clamp(0, 20))]);
    if (target == _Op.eqUnspecified) eqPresetId = _Op.eqCustom;
    eqBands = List.unmodifiable(bands);
    notifyListeners();
    _later(300, () => _send([_Op.eqGetParam, _Op.eqPresetType]));
  }

  /// Runs before the power-off command is sent (e.g. pausing media so it
  /// doesn't jump to the laptop speakers when the headphones drop).
  Future<void> Function()? beforePowerOff;

  Future<void> powerOff() async {
    if (!isReady) return;
    final hook = beforePowerOff;
    if (hook != null) await hook();
    _send([_Op.powerOff, 0x00, 0x01]);
  }

  // --- Bridge events ------------------------------------------------------
  void _onEvent(BridgeEvent e) {
    switch (e) {
      case ReachabilityEvent():
        _reachable = e.reachable;
        if (e.deviceName != null) deviceName = e.deviceName!;
        if (e.reachable && !_linkOpen) {
          _scheduleReconnect(const Duration(seconds: 1));
        } else if (!e.reachable && !_linkOpen) {
          phase = Phase.unavailable;
        }
        notifyListeners();
      case StatusEvent():
        _onStatus(e);
      case DataEvent():
        _onData(e.bytes);
    }
  }

  void _onStatus(StatusEvent e) {
    if (e.deviceName != null) deviceName = e.deviceName!;
    switch (e.state) {
      case LinkState.connecting:
        phase = Phase.connecting;
      case LinkState.connected:
        _resetSession();
        _linkOpen = true;
        _reachable = true;
        linkDetails = e.details;
        connectedAt = DateTime.now();
        phase = Phase.connecting; // until INIT completes
        _sendInit();
      case LinkState.disconnected:
      case LinkState.failed:
        _resetSession();
        failureReason = e.state == LinkState.failed ? e.reason : null;
        phase = _reachable ? Phase.idle : Phase.unavailable;
        _scheduleReconnect(reconnectDelay);
    }
    notifyListeners();
  }

  void _scheduleReconnect(Duration after) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(after, () {
      if (!_linkOpen) connect();
    });
  }

  void _resetSession() {
    for (final t in _sessionTimers) {
      t.cancel();
    }
    _sessionTimers.clear();
    _parser.reset();
    _linkOpen = false;
    _initialized = false;
    _awaitingInit = false;
    _seq = 0;
    _touchSlot = null;
    _touchIsList = false;
    _ncType = 0x02;
    _asmType = 0x01;
    _asmId = 0x00;
    connectedAt = null;
    txPackets = rxPackets = 0;
    modelName = firmwareVersion = audioCodec = null;
    featureSlots = const [];
    packetLog.clear();
    touchSensor = null;
    ncMode = null;
    speakToChat = null;
    battery = null;
    charging = false;
    eqPresets = const [];
    eqPresetId = null;
    eqBands = const [];
  }

  // --- Handshake ----------------------------------------------------------
  void _sendInit() {
    _awaitingInit = true;
    _send([_Op.initRequest, 0x00]);
    // Some firmware needs a second handshake before accepting SETs.
    _later(600, () {
      if (_awaitingInit) _send([0x06, 0x14, 0x01, 0x00, 0x00, 0x00, 0x00]);
    });
    // Complete anyway if no canonical reply arrives.
    _later(2000, () {
      if (_awaitingInit && !_initialized) _completeInit();
    });
  }

  void _completeInit() {
    if (_initialized) return;
    _initialized = true;
    _awaitingInit = false;
    phase = Phase.ready;
    notifyListeners();
    for (var i = 0; i < _Op.gsSlots.length; i++) {
      final slot = _Op.gsSlots[i];
      _later(300 + i * 400, () => _send([_Op.gsGetCapability, slot, 0x00]));
    }
    _later(1500, _requestNcasm);
    _later(1700, () => _send([_Op.systemGet, _Op.smartTalking]));
    _later(1900, () => _send([_Op.batteryGet, 0x00]));
    _later(2100, () => _send([_Op.eqGetCapability, _Op.eqPresetType, 0x00]));
    _later(2300, () => _send([_Op.eqGetParam, _Op.eqPresetType]));
    // Read-only device info (model / firmware). Unverified on some firmware;
    // if the headphones don't answer, the UI says "not reported".
    _later(2500, () => _send([_Op.deviceInfoGet, 0x01]));
    _later(2700, () => _send([_Op.deviceInfoGet, 0x02]));
    _later(2900, () => _send([_Op.codecGet, 0x00]));
  }

  // --- Sending ------------------------------------------------------------
  void _later(int ms, VoidCallback fn) {
    _sessionTimers.add(
      Timer(Duration(milliseconds: ms), () {
        if (!_disposed) fn();
      }),
    );
  }

  void _send(List<int> payload) {
    if (!_linkOpen) return;
    final packet = SonyPacket(SonyDataType.command1, _seq, payload);
    _seq ^= 1;
    _record(true, payload);
    _bridge.send(encodeSonyPacket(packet));
  }

  void _record(bool tx, List<int> payload) {
    tx ? txPackets++ : rxPackets++;
    packetLog.add(
      LogLine(DateTime.now(), tx, payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')),
    );
    if (packetLog.length > 300) packetLog.removeAt(0);
  }

  void _requestNcasm() => _send([_Op.ncasmGet, _Op.ncasmCombined]);

  void _sendNcasm(NcMode mode) {
    _send([
      _Op.ncasmSet,
      _Op.ncasmCombined,
      mode == NcMode.off ? 0x00 : 0x11,
      _ncType,
      mode == NcMode.noiseCancelling ? 0x02 : 0x00,
      _asmType,
      _asmId,
      mode == NcMode.ambient ? ambientLevel : 0,
    ]);
  }

  // --- Receiving ----------------------------------------------------------
  void _onData(Uint8List data) {
    for (final p in _parser.feed(data)) {
      if (p.dataType != SonyDataType.ack) {
        _bridge.send(encodeSonyPacket(SonyPacket(SonyDataType.ack, p.sequence ^ 1, const [])));
      }
      if (p.dataType != SonyDataType.ack) _record(false, p.payload);
      _interpret(p);
    }
  }

  void _interpret(SonyPacket p) {
    if (p.dataType != SonyDataType.command1 || p.payload.isEmpty) return;
    if (_awaitingInit) _completeInit();
    final b = p.payload;
    switch (b[0]) {
      case _Op.codecRet || _Op.codecNotify:
        if (b.length >= 3) {
          audioCodec = switch (b[2]) {
            0x00 => 'not negotiated',
            0x01 => 'SBC',
            0x02 => 'AAC',
            0x10 => 'LDAC',
            0x20 => 'aptX',
            0x21 => 'aptX HD',
            final v => 'unknown (0x${v.toRadixString(16)})',
          };
        }
      case _Op.deviceInfoRet:
        _parseDeviceInfo(b);
      case _Op.gsRetCapability:
        _parseGsCapability(b);
      case _Op.batteryRet || _Op.batteryNotify:
        if (b.length >= 4 && b[1] == 0x00) {
          battery = b[2];
          charging = b[3] == 0x01;
        }
      case _Op.eqRetCapability:
        _parseEqCapability(b);
      case _Op.eqRetParam || _Op.eqNotify:
        if (b.length >= 4 && b[1] == _Op.eqPresetType) {
          eqPresetId = b[2];
          final n = b[3];
          eqBands = 4 + n <= b.length ? List.unmodifiable(b.sublist(4, 4 + n)) : const [];
        }
      case _Op.ncasmRet || _Op.ncasmNotify:
        _parseNcasm(b);
      case _Op.systemRet || _Op.systemNotify:
        if (b.length >= 4 && b[1] == _Op.smartTalking) speakToChat = b[3] != 0;
      case _Op.touchRet:
        if (b.length >= 4 && b[1] == (_touchSlot ?? 0xFF)) touchSensor = b[3] != 0;
    }
    notifyListeners();
  }

  void _parseDeviceInfo(List<int> b) {
    // Best-effort: [05][type][len][ascii…]; tolerate variants.
    if (b.length < 3) return;
    var start = 2;
    if (b.length >= 4 && b[2] == b.length - 3) start = 3;
    final text = String.fromCharCodes(b.sublist(start).where((c) => c >= 32 && c < 127)).trim();
    if (text.isEmpty) return;
    if (b[1] == 0x01) modelName = text;
    if (b[1] == 0x02) firmwareVersion = text;
  }

  void _parseGsCapability(List<int> b) {
    // [D1][slot][nameFormat][nameLen][name…][descLen][desc…][settingType]
    if (b.length < 5) return;
    final slot = b[1], format = b[2], nameLen = b[3];
    if (b.length < 4 + nameLen + 1) return;
    final name = String.fromCharCodes(b.sublist(4, 4 + nameLen));
    final descLenIdx = 4 + nameLen;
    final descEnd = descLenIdx + 1 + b[descLenIdx];
    if (b.length <= descEnd) return;
    if (!featureSlots.any((f) => f.slot == slot)) {
      featureSlots = [
        ...featureSlots,
        FeatureSlot(
          slot,
          name,
          b[descEnd] == 1
              ? 'on/off'
              : b[descEnd] == 2
              ? 'list'
              : '?',
        ),
      ];
    }
    if (format == 0x02 && name == 'TOUCH_PANEL_SETTING') {
      _touchSlot = slot;
      _touchIsList = b[descEnd] == 2;
      _send([_Op.touchGet, slot]);
    }
  }

  void _parseNcasm(List<int> b) {
    // [op][type][effect][ncType][ncValue][asmType][asmId][asmLevel]
    if (b.length < 8 || b[1] != _Op.ncasmCombined) return;
    final effect = b[2], ncValue = b[4], asmLevel = b[7];
    _ncType = b[3];
    _asmType = b[5];
    _asmId = b[6];
    // The device reports 0 while NC/Off is active; keep the last real level.
    if (asmLevel > 0) ambientLevel = asmLevel;
    ncMode = effect == 0x00
        ? NcMode.off
        : ncValue != 0
        ? NcMode.noiseCancelling
        : asmLevel > 0
        ? NcMode.ambient
        : NcMode.off;
    ambientFocusOnVoice = _asmId == 0x01;
  }

  void _parseEqCapability(List<int> b) {
    // [51][type][bandCount][steps][presetCount] then per preset [id][nameLen][name…]
    if (b.length < 5 || b[1] != _Op.eqPresetType) return;
    final presets = <EqPreset>[];
    var i = 5;
    for (var n = 0; n < b[4]; n++) {
      if (i + 1 >= b.length) break;
      final id = b[i], len = b[i + 1], end = i + 2 + len;
      if (end > b.length) break;
      final name = len > 0 ? String.fromCharCodes(b.sublist(i + 2, end)) : '';
      presets.add(EqPreset(id, name.isNotEmpty ? name : eqFallbackName(id)));
      i = end;
    }
    // Keep the device's saved user slots (Custom 1/2 on the XM4). The bare
    // 0xA0 "Custom" is a volatile preview, so hide it when slots exist.
    if (presets.any((p) => p.id >= 0xA1 && p.id <= 0xA5)) {
      presets.removeWhere((p) => p.id == _Op.eqCustom);
    }
    presets.sort((a, b) => (a.id >= 0xA0 ? 1 : 0).compareTo(b.id >= 0xA0 ? 1 : 0));
    eqPresets = List.unmodifiable(presets);
  }

  static String eqFallbackName(int id) => switch (id) {
    0x00 => 'Off',
    0x01 => 'Rock',
    0x02 => 'Pop',
    0x03 => 'Jazz',
    0x04 => 'Dance',
    0x05 => 'EDM',
    0x06 => 'R&B / Hip-Hop',
    0x07 => 'Acoustic',
    0x10 => 'Bright',
    0x11 => 'Excited',
    0x12 => 'Mellow',
    0x13 => 'Relaxed',
    0x14 => 'Vocal',
    0x15 => 'Treble Boost',
    0x16 => 'Bass Boost',
    0x17 => 'Speech',
    0xA0 => 'Custom',
    >= 0xA1 && <= 0xA5 => 'Custom ${id - 0xA0}',
    _ => 'Preset ${id.toRadixString(16).toUpperCase()}',
  };

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    for (final t in _sessionTimers) {
      t.cancel();
    }
    _sub?.cancel();
    _bridge.disconnect();
    super.dispose();
  }
}
