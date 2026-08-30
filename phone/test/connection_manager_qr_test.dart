import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepad/models/packet.dart';
import 'package:pulsepad/services/connection_manager.dart';

void main() {
  group('ConnectionManager.applyQrPayload', () {
    test('applies a Wi-Fi payload (host, mode, ports)', () {
      final m = ConnectionManager();
      final ok = m.applyQrPayload(
          'pulsepad|udp|192.168.1.10|5006|5005|5006|PulsePad');
      expect(ok, isTrue);
      expect(m.mode, ConnectionMode.wifi);
      expect(m.ipAddress, '192.168.1.10');
      expect(m.qrTcpPort, 5005);
      expect(m.qrUdpPort, 5006);
      m.dispose();
    });

    test('applies a USB/tcp payload', () {
      final m = ConnectionManager();
      final ok = m.applyQrPayload(
          'pulsepad|tcp|127.0.0.1|5005|5005|5006|PulsePad');
      expect(ok, isTrue);
      expect(m.mode, ConnectionMode.usb);
      expect(m.ipAddress, '127.0.0.1');
      m.dispose();
    });

    test('rejects garbage and leaves settings untouched', () {
      final m = ConnectionManager();
      m.applyQrPayload('pulsepad|udp|10.0.0.5|5006|5005|5006|PulsePad');
      expect(m.applyQrPayload('not a qr'), isFalse);
      expect(m.applyQrPayload(''), isFalse);
      expect(m.applyQrPayload('pulsepad|ftp|1.2.3.4|1|2|3'), isFalse);
      // Still holds the previous good value after failures.
      expect(m.ipAddress, '10.0.0.5');
      m.dispose();
    });
  });
}