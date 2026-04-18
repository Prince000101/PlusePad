import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/packet.dart';

class ConnectionManager extends ChangeNotifier {
  ConnectionMode _mode = ConnectionMode.usb;
  ConnectionStatus _state = ConnectionStatus.disconnected;
  Socket? _socket;
  String _ipAddress = '';
  int _latency = 0;
  int _lastTimestamp = 0;
  Timer? _heartbeatTimer;
  Timer? _latencyTimer;
  String _serverIp = '';

  ConnectionMode get mode => _mode;
  ConnectionStatus get state => _state;
  String get ipAddress => _ipAddress;
  int get latency => _latency;

  void setMode(ConnectionMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setIpAddress(String ip) {
    _ipAddress = ip;
    notifyListeners();
  }

  Future<void> connect() async {
    _state = ConnectionStatus.connecting;
    notifyListeners();

    try {
      if (_mode == ConnectionMode.usb) {
        await _connectUsb();
      } else {
        await _connectWifi();
      }
      _state = ConnectionStatus.connected;
      _startHeartbeat();
    } catch (e) {
      debugPrint('Connection error: $e');
      _state = ConnectionStatus.error;
      notifyListeners();
    }
  }

  Future<void> _connectUsb() async {
    _socket = await Socket.connect('127.0.0.1', 5005);

    _socket!.listen((data) {
      final response = utf8.decode(data);
      debugPrint('Received: $response');
    });
  }

  Future<void> _connectWifi() async {
    if (_ipAddress.isEmpty) {
      throw Exception('IP address not set');
    }
    Socket.connect(_ipAddress, 5006).then((socket) {
      _socket = socket;
      _socket!.listen((data) {
        debugPrint('Received: ${utf8.decode(data)}');
      });
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _latencyTimer?.cancel();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sendPacket({'type': 'HEARTBEAT', 'timestamp': DateTime.now().millisecondsSinceEpoch});
    });

    _latencyTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _latency = now - _lastTimestamp;
      notifyListeners();
    });
  }

  Future<void> sendInput(InputPacket packet) async {
    if (_socket == null || _state != ConnectionStatus.connected) {
      return;
    }
    _lastTimestamp = packet.timestamp;
    try {
      final data = jsonEncode(packet.toJson()) + '\n';
      _socket!.write(data);
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  void _sendPacket(Map<String, dynamic> data) {
    if (_socket == null || _state != ConnectionStatus.connected) return;
    try {
      final packetData = jsonEncode(data) + '\n';
      _socket!.write(packetData);
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _latencyTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _state = ConnectionStatus.disconnected;
    _latency = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}