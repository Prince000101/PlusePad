import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/packet.dart';

class ConnectionManager extends ChangeNotifier {
  ConnectionMode _mode = ConnectionMode.usb;
  ConnectionState _state = ConnectionState.disconnected;
  Socket? _socket;
  String _ipAddress = '';
  int _latency = 0;
  int _lastTimestamp = 0;
  Timer? _heartbeatTimer;
  Timer? _latencyTimer;

  ConnectionMode get mode => _mode;
  ConnectionState get state => _state;
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
    _state = ConnectionState.connecting;
    notifyListeners();

    try {
      if (_mode == ConnectionMode.usb) {
        await _connectUsb();
      } else {
        await _connectWifi();
      }
      _state = ConnectionState.connected;
      _startHeartbeat();
    } catch (e) {
      _state = ConnectionState.error;
    }
    notifyListeners();
  }

  Future<void> _connectUsb() async {
    _socket = await Socket.connect('127.0.0.1', 5005);
  }

  Future<void> _connectWifi() async {
    if (_ipAddress.isEmpty) {
      throw Exception('IP address not set');
    }
    _socket = await Socket.connect(_ipAddress, 5006);
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
    if (_socket == null || _state != ConnectionState.connected) return;
    _lastTimestamp = packet.timestamp;
    _socket!.write(jsonEncode(packet.toJson()));
  }

  void _sendPacket(Map<String, dynamic> data) {
    if (_socket == null || _state != ConnectionState.connected) return;
    _socket!.write(jsonEncode(data));
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _latencyTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _state = ConnectionState.disconnected;
    _latency = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}