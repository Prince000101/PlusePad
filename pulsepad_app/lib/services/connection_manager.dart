import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/packet.dart';

class ConnectionManager extends ChangeNotifier {
  ConnectionMode _mode = ConnectionMode.usb;
  ConnectionStatus _state = ConnectionStatus.disconnected;
  ControllerLayout _layout = ControllerLayout.gamepad;
  Socket? _socket;
  String _ipAddress = '';
  int _latency = 0;
  int _lastTimestamp = 0;
  Timer? _heartbeatTimer;
  Timer? _latencyTimer;

  ConnectionMode get mode => _mode;
  ConnectionStatus get state => _state;
  ControllerLayout get layout => _layout;
  String get ipAddress => _ipAddress;
  int get latency => _latency;

  void setMode(ConnectionMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setLayout(ControllerLayout layout) {
    _layout = layout;
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
        _socket = await Socket.connect('127.0.0.1', 5005);
      } else {
        if (_ipAddress.isEmpty) throw Exception('IP address not set');
        _socket = await Socket.connect(_ipAddress, 5006);
      }
      _state = ConnectionStatus.connected;
      _startHeartbeat();
    } catch (e) {
      _state = ConnectionStatus.error;
    }
    notifyListeners();
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

  Future<void> sendGamepad(GamepadPacket packet) async {
    _sendPacket(packet.toJson());
  }

  Future<void> sendMouse(MousePacket packet) async {
    _sendPacket(packet.toJson());
  }

  Future<void> sendKeyboard(KeyboardPacket packet) async {
    _sendPacket(packet.toJson());
  }

  void _sendPacket(Map<String, dynamic> data) {
    if (_socket == null || _state != ConnectionStatus.connected) return;
    _lastTimestamp = data['timestamp'] ?? 0;
    try {
      _socket!.write(jsonEncode(data) + '\n');
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