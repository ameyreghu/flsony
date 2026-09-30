import 'package:flsony/core/sony_packet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encode then parse round-trips, including bytes that need escaping', () {
    const payload = [0x68, 0x3C, 0x3D, 0x3E, 0x00, 0xFF];
    final framed = encodeSonyPacket(const SonyPacket(SonyDataType.command1, 1, payload));

    expect(framed.first, 0x3E);
    expect(framed.last, 0x3C);
    // Markers must not appear unescaped inside the body.
    expect(framed.sublist(1, framed.length - 1).where((b) => b == 0x3E || b == 0x3C), isEmpty);

    final packets = SonyFrameParser().feed(framed);
    expect(packets, hasLength(1));
    expect(packets.single.dataType, SonyDataType.command1);
    expect(packets.single.sequence, 1);
    expect(packets.single.payload, payload);
  });

  test('parser reassembles frames split across reads and ignores bad checksums', () {
    final framed = encodeSonyPacket(const SonyPacket(SonyDataType.ack, 0, []));
    final parser = SonyFrameParser();
    expect(parser.feed(framed.sublist(0, 4)), isEmpty);
    expect(parser.feed(framed.sublist(4)), hasLength(1));

    final corrupt = List<int>.of(framed)..[framed.length - 2] ^= 0x01;
    expect(parser.feed(corrupt), isEmpty);
  });
}
