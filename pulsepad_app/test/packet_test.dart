import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepad/models/packet.dart';

void main() {
  group('parseQrPayload', () {
    test('parses a udp payload', () {
      final p = parseQrPayload('pulsepad|udp|192.168.1.10|5006|5005|5006|PulsePad');
      expect(p, isNotNull);
      expect(p!.mode, 'udp');
      expect(p.host, '192.168.1.10');
      expect(p.connectPort, 5006);
      expect(p.tcpPort, 5005);
      expect(p.udpPort, 5006);
      expect(p.name, 'PulsePad');
    });

    test('parses a tcp payload', () {
      final p = parseQrPayload('pulsepad|tcp|127.0.0.1|5005|5005|5006|PulsePad');
      expect(p, isNotNull);
      expect(p!.mode, 'tcp');
      expect(p.connectPort, 5005);
    });

    test('accepts uppercase prefix and extra whitespace', () {
      final p = parseQrPayload('  PULSEPAD|udp|10.0.0.5|5006|5005|5006|Workshop PC ');
      expect(p, isNotNull);
      expect(p!.host, '10.0.0.5');
      expect(p.name, 'Workshop PC');
    });

    test('defaults name when omitted', () {
      final p = parseQrPayload('pulsepad|udp|1.2.3.4|5006|5005|5006');
      expect(p, isNotNull);
      expect(p!.name, 'PulsePad');
    });

    test('rejects garbage', () {
      expect(parseQrPayload('hello world'), isNull);
      expect(parseQrPayload(''), isNull);
      expect(parseQrPayload('pulsepad|ftp|1.2.3.4|5006|5005|5006'), isNull);
    });

    test('rejects bad ports', () {
      expect(parseQrPayload('pulsepad|udp|1.2.3.4|abc|5005|5006'), isNull);
    });
  });
}