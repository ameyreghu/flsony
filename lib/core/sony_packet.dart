import 'dart:typed_data';

/// Sony "Headphones Connect" framing (community reverse-engineered, see
/// github.com/Plutoberth/SonyHeadphonesClient).
///
/// Frame: 0x3E [dataType][seq][len:4 BE][payload][checksum] 0x3C
/// Any 0x3C/0x3D/0x3E inside the body is sent as 0x3D followed by (byte & 0xEF).
enum SonyDataType {
  ack(0x01),
  command1(0x0C),
  command1Response(0x0D);

  const SonyDataType(this.value);
  final int value;

  static SonyDataType? from(int v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

class SonyPacket {
  const SonyPacket(this.dataType, this.sequence, this.payload);
  final SonyDataType dataType;
  final int sequence;
  final List<int> payload;
}

const _start = 0x3E;
const _end = 0x3C;
const _escape = 0x3D;
const _escapeMask = 0xEF;

Uint8List encodeSonyPacket(SonyPacket p) {
  final len = p.payload.length;
  final body = <int>[
    p.dataType.value,
    p.sequence,
    (len >> 24) & 0xFF,
    (len >> 16) & 0xFF,
    (len >> 8) & 0xFF,
    len & 0xFF,
    ...p.payload,
  ];
  body.add(body.fold<int>(0, (a, b) => (a + b) & 0xFF));

  final out = <int>[_start];
  for (final b in body) {
    if (b == _start || b == _end || b == _escape) {
      out
        ..add(_escape)
        ..add(b & _escapeMask);
    } else {
      out.add(b);
    }
  }
  out.add(_end);
  return Uint8List.fromList(out);
}

class SonyFrameParser {
  bool _reading = false;
  bool _escapeNext = false;
  final List<int> _buffer = [];

  void reset() {
    _reading = false;
    _escapeNext = false;
    _buffer.clear();
  }

  List<SonyPacket> feed(List<int> data) {
    final packets = <SonyPacket>[];
    for (final byte in data) {
      if (!_reading) {
        if (byte == _start) {
          _reading = true;
          _escapeNext = false;
          _buffer.clear();
        }
        continue;
      }
      if (byte == _end) {
        final p = _decode(_buffer);
        if (p != null) packets.add(p);
        _reading = false;
      } else if (_escapeNext) {
        _buffer.add(byte | (~_escapeMask & 0xFF));
        _escapeNext = false;
      } else if (byte == _escape) {
        _escapeNext = true;
      } else if (byte == _start) {
        // Stray start marker: resync.
        _buffer.clear();
        _escapeNext = false;
      } else {
        _buffer.add(byte);
      }
    }
    return packets;
  }

  SonyPacket? _decode(List<int> body) {
    if (body.length < 7) return null;
    final len = (body[2] << 24) | (body[3] << 16) | (body[4] << 8) | body[5];
    if (body.length != 7 + len) return null;
    var sum = 0;
    for (var i = 0; i < 6 + len; i++) {
      sum = (sum + body[i]) & 0xFF;
    }
    if (sum != body[6 + len]) return null;
    final type = SonyDataType.from(body[0]) ?? SonyDataType.command1;
    return SonyPacket(type, body[1], List<int>.unmodifiable(body.sublist(6, 6 + len)));
  }
}
