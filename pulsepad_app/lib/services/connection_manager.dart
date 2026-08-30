import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/controller_state.dart';
import '../models/packet.dart';
import 'protocol.dart' as p;

/// Phone <-> PC transport for PulsePad, covering USB (TCP via adb reverse)
/// and Wi-Fi (UDP streaming) modes with zero-touch auto-discovery.
///
/// Latency-first design:
///  * Binary, self-contained state packets (never JSON) keep bytes and CPU low
///    and make the link loss-tolerant.  Every gamepad packet is a full snapshot
///    so a dropped packet is simply superseded by the next one.
///  * UI state changes are coalesced and flushed at a steady high rate, so a
///    burst of touch events collapses into one packet per tick without adding
///    latency.
///  * Latency is measured with real PING/PONG round trips.
///  * Wi-Fi mode auto-discovers the PC via UDP broadcast; USB mode tunnels over
///    adb reverse so no IP is ever needed.
///  * Timeouts + automatic reconnection keep long sessions alive.
class ConnectionManager extends ChangeNotifier {
  ConnectionMode _mode = ConnectionMode.usb;
  ConnectionStatus _state = ConnectionStatus.disconnected;
  ControllerLayout _layout = ControllerLayout.gamepad;
  String _typedIp = '';

  // Ports supplied by a scanned QR code (default -1 = use standard 5005/5006).
  int _qrUdpPort = -1;
  int _qrTcpPort = -1;

  // Transports
  Socket? _tcp;
  RawDatagramSocket? _udp;
  final List<DiscoveredServer> _discovered = [];

  // Controller state + coalescing
  final ControllerState controller = ControllerState();
  final Queue<Uint8List> _queue = Queue();
  bool _flushScheduled = false;
  static const _flushInterval = Duration(milliseconds: 4); // 250 Hz steady

  // Latency (real PING/PONG)
  int _latency = 0;
  int _pingSeq = 0;
  Timer? _pingTimer;
  DateTime? _pendingPingAt;
  int _pendingPingSeq = -1;

  // Reconnect / stats
  Timer? _reconnectTimer;
  bool _autoReconnect = false;
  Timer? _statsTimer;

  // UI tunables
  double deadZone = 0.12;
  double sensitivity = 1.0;

  // Inbound
  void Function(int durationMs, double intensity, int motor)? onHaptic;

  ConnectionMode get mode => _mode;
  ConnectionStatus get state => _state;
  ControllerLayout get layout => _layout;
  String get ipAddress => _typedIp;
  int get latency => _latency;
  List<DiscoveredServer> get discovered => List.unmodifiable(_discovered);

  void setMode(ConnectionMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setLayout(ControllerLayout layout) {
    _layout = layout;
    notifyListeners();
  }

  void setIpAddress(String ip) {
    _typedIp = ip.trim();
    notifyListeners();
  }

  /// Apply settings decoded from a scanned QR code.
  void applyQr(String host, ConnectionMode mode, int tcpPort, int udpPort) {
    _typedIp = host.trim();
    _mode = mode;
    _qrTcpPort = tcpPort;
    _qrUdpPort = udpPort;
    notifyListeners();
  }

  int get qrUdpPort => _qrUdpPort;
  int get qrTcpPort => _qrTcpPort;

  // ------------------------------------------------------------------ //
  // Discovery (hassle-free Wi-Fi setup)
  // ------------------------------------------------------------------ //
  /// Broadcast HELLO to the discovery port and collect beacons for a short
  /// window.  Populates [discovered].
  Future<List<DiscoveredServer>> discover(
      {Duration window = const Duration(seconds: 2)}) async {
    _discovered.clear();
    notifyListeners();

    late RawDatagramSocket sock;
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.broadcastEnabled = true;
    } catch (e) {
      debugPrint('discovery bind failed: $e');
      return discovered;
    }

    sock.listen((event) {
      if (event == RawSocketEvent.read) {
        final dm = sock.receive();
        if (dm == null) return;
        final data = dm.data;
        if (data.length >= 8 && data[0] == 0x50 && data[1] == 0x50 &&
            data[2] == 0x42 && data[3] == 0x31) {
          // Beacon: "PPB1" + udp_port(2,big) + tcp_port(2,big) + len + name
          final bd = ByteData.sublistView(data);
          final udpPort = bd.getUint16(4, Endian.big);
          final tcpPort = bd.getUint16(6, Endian.big);
          final n = data[8];
          final name = String.fromCharCodes(data.sublist(9, 9 + n));
          _addDiscovered(dm.address.address, udpPort, tcpPort, name);
        }
      }
    });

    // Broadcast HELLO on the subnet broadcast address.
    final hello = p.encodeHello();
    try {
      sock.send(hello, InternetAddress('255.255.255.255'), 54321);
    } catch (e) {
      debugPrint('discovery broadcast: $e');
    }

    await Future<void>.delayed(window);
    sock.close();
    notifyListeners();
    return discovered;
  }

  void _addDiscovered(String host, int udpPort, int tcpPort, String name) {
    _discovered.removeWhere((s) => s.host == host);
    _discovered.add(DiscoveredServer(host, udpPort, tcpPort, name));
    notifyListeners();
  }

  // ------------------------------------------------------------------ //
  // Connect
  // ------------------------------------------------------------------ //
  Future<void> connect() async {
    if (_state == ConnectionStatus.connecting) return;
    await disconnect(notify: false);
    _state = ConnectionStatus.connecting;
    notifyListeners();

    try {
      if (_mode == ConnectionMode.usb) {
        await _connectUsb();
      } else {
        await _connectWifi();
      }
      _state = ConnectionStatus.connected;
      _startLatencyLoop();
    } catch (e) {
      debugPrint('connect failed: $e');
      _state = ConnectionStatus.error;
      _scheduleReconnect();
    }
    notifyListeners();
  }

  Future<void> _connectUsb() async {
    // adb reverse tcp:5005 tcp:5005   (run once on the PC)
    // forwards the PHONE's localhost:5005 to the PC daemon's localhost:5005,
    // so the app simply connects to its own loopback -- no IP required and the
    // lowest possible latency path.
    const host = '127.0.0.1';
    const port = 5005;
    final sock = await Socket.connect(host, _qrTcpPort > 0 ? _qrTcpPort : port,
        timeout: const Duration(seconds: 5));
    sock.setOption(SocketOption.tcpNoDelay, true);
    _tcp = sock;
    _startTcpReader(sock);
  }

  Future<void> _connectWifi() async {
    if (_typedIp.isEmpty && _discovered.isEmpty) {
      // Try discovery first so the app is fully zero-config.
      await discover(window: const Duration(milliseconds: 1200));
    }
    if (_typedIp.isEmpty && _discovered.isEmpty) {
      throw StateError('No PC found. Enter its IP or run discovery.');
    }
    final target = _udpTarget;
    if (target == null) {
      throw StateError('No PC found.');
    }

    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        .timeout(const Duration(seconds: 5));
    sock.broadcastEnabled = true;
    _udp = sock;
    sock.listen(_onUdpPacket);

    // Announce ourselves so the daemon knows our source address.
    sock.send(p.encodeHello(), target.addr, target.port);

    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      notifyListeners();
    });
  }

  // ------------------------------------------------------------------ //
  // Inbound
  // ------------------------------------------------------------------ //
  final List<int> _tcpBuffer = [];

  void _startTcpReader(Socket sock) {
    _tcpBuffer.clear();
    sock.listen(_onTcpData,
        onError: (_) => _onTransportLost(),
        onDone: _onTransportLost,
        cancelOnError: true);
  }

  void _onTcpData(Uint8List data) {
    _tcpBuffer.addAll(data);
    while (_tcpBuffer.isNotEmpty) {
      final ptype = _tcpBuffer[0] & 0x0F;
      int? size;
      switch (ptype) {
        case p.kTypePing:
        case p.kTypePong:
          size = p.kPingSize;
          break;
        case p.kTypeHaptic:
          size = p.kHapticSize;
          break;
        default:
          _tcpBuffer.removeAt(0);
          continue;
      }
      if (_tcpBuffer.length < size) break;
      final raw = Uint8List.fromList(_tcpBuffer.sublist(0, size));
      _tcpBuffer.removeRange(0, size);
      _handleInbound(raw);
    }
  }

  void _onUdpPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dm = _udp?.receive();
    if (dm == null || dm.data.isEmpty) return;
    final t = dm.data[0] & 0x0F;
    if (t == p.kTypeHello || t == p.kTypeGamepad) {
      // Not expected inbound on the phone, ignore.
      return;
    }
    _handleInbound(dm.data);
  }

  void _handleInbound(Uint8List raw) {
    final t = p.typeOf(raw);
    switch (t) {
      case p.kTypePong:
        final decoded = p.decodePingPong(raw);
        if (decoded != null) {
          final (ts, seq) = decoded;
          if (seq == _pendingPingSeq && _pendingPingAt != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            _latency = math.max(0, now - _pendingPingAt!.millisecondsSinceEpoch);
            _pendingPingAt = null;
            notifyListeners();
          }
        }
        break;
      case p.kTypeHaptic:
        final h = p.decodeHaptic(raw);
        if (h != null) onHaptic?.call(h.$1, h.$2, h.$3);
        break;
      case p.kTypePing:
        final decoded = p.decodePingPong(raw);
        if (decoded != null) {
          final (ts, seq) = decoded;
          _send(p.encodePong(DateTime.now().millisecondsSinceEpoch, seq));
        }
        break;
    }
  }

  // ------------------------------------------------------------------ //
  // Sending (coalesced)
  // ------------------------------------------------------------------ //
  /// Enqueue the latest snapshot from the UI; it is flushed at the next tick.
  void pushState() {
    if (_state != ConnectionStatus.connected) return;
    _queue.add(controller.encode());
    if (_queue.length > 8) _queue.removeFirst();
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushScheduled || _state != ConnectionStatus.connected) return;
    _flushScheduled = true;
    Future.delayed(_flushInterval, _flush);
  }

  void _flush() {
    _flushScheduled = false;
    if (_queue.isEmpty) return;
    final latest = _queue.last;
    _queue.clear();
    _send(latest);
  }

  void _send(Uint8List data) {
    if (_mode == ConnectionMode.usb) {
      _tcp?.add(data);
      return;
    }
    final target = _udpTarget;
    if (target != null && _udp != null) {
      try {
        _udp!.send(data, target.addr, target.port);
      } catch (e) {
        debugPrint('udp send: $e');
      }
    }
  }

  _UdpTarget? get _udpTarget {
    if (_typedIp.isNotEmpty) {
      return _UdpTarget(InternetAddress(_typedIp),
          _qrUdpPort > 0 ? _qrUdpPort : 5006);
    }
    if (_discovered.isNotEmpty) {
      final s = _discovered.first;
      return _UdpTarget(InternetAddress(s.host), s.udpPort);
    }
    return null;
  }

  // ------------------------------------------------------------------ //
  // Latency
  // ------------------------------------------------------------------ //
  void _startLatencyLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sendPing());
    _sendPing();
  }

  void _sendPing() {
    if (_state != ConnectionStatus.connected) return;
    _pendingPingAt = DateTime.now();
    _pendingPingSeq = _pingSeq++;
    _send(p.encodePing(_pendingPingAt!.millisecondsSinceEpoch, _pendingPingSeq));
  }

  // ------------------------------------------------------------------ //
  // Reconnect / teardown
  // ------------------------------------------------------------------ //
  void _onTransportLost() {
    if (_state != ConnectionStatus.connected) return;
    _state = ConnectionStatus.disconnected;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_autoReconnect) connect();
    });
  }

  void enableAutoReconnect() {
    _autoReconnect = true;
    _scheduleReconnect();
  }

  Future<void> disconnect({bool notify = true}) async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _statsTimer?.cancel();
    _tcp?.destroy();
    _tcp = null;
    _udp?.close();
    _udp = null;
    _queue.clear();
    _flushScheduled = false;
    controller.reset();
    _state = ConnectionStatus.disconnected;
    _latency = 0;
    _pendingPingAt = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    disconnect(notify: false);
    super.dispose();
  }
}

class _UdpTarget {
  final InternetAddress addr;
  final int port;
  _UdpTarget(this.addr, this.port);
}
