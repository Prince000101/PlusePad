import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepad/models/packet.dart';
import 'package:pulsepad/services/connection_manager.dart';
import 'package:pulsepad/services/protocol.dart' as p;

/// Integration tests for the Wi-Fi/UDP connect handshake against a real
/// loopback UDP server acting as the PC daemon. Proves the phone only reports
/// "Connected" when the PC actually answers, and that gamepad state streams.
void main() {
  test('UDP connect completes handshake (beacon/PONG) and streams state',
      () async {
    final server =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final manager = ConnectionManager();
    manager.applyQrPayload(
        'pulsepad|udp|127.0.0.1|$port|$port|$port|FakePC');

    final gotGamepad = Completer<Uint8List>();
    server.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dm = server.receive();
      if (dm == null) return;
      final t = dm.data[0] & 0x0F;
      switch (t) {
        case p.kTypePing:
          final decoded = p.decodePingPong(dm.data);
          if (decoded != null) {
            server.send(p.encodePong(24, decoded.$2), dm.address, dm.port);
          }
          break;
        case p.kTypeGamepad:
          if (!gotGamepad.isCompleted) gotGamepad.complete(dm.data);
          break;
      }
    });

    await manager.connect();
    expect(manager.state, ConnectionStatus.connected,
        reason: 'handshake must succeed when the PC replies');
    expect(manager.latency, greaterThan(0),
        reason: 'real PING/PONG should set latency');

    manager.controller.setButton('A', true);
    manager.pushState();
    final pkt = await gotGamepad.future.timeout(const Duration(seconds: 3));
    expect(p.typeOf(pkt), p.kTypeGamepad);
    expect(pkt[1] & p.kBtnA, p.kBtnA);

    await manager.disconnect();
    server.close();
  });

  test('UDP connect reports error when no PC answers (no phantom Connected)',
      () async {
    final server =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    server.close(); // nothing listening here now

    final manager = ConnectionManager();
    manager.applyQrPayload(
        'pulsepad|udp|127.0.0.1|$port|$port|$port|Ghost');

    await manager.connect();
    expect(manager.state, ConnectionStatus.error,
        reason: 'must NOT report connected to a dead PC');
    await manager.disconnect();
  });
}