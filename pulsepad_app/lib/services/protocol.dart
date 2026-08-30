import 'dart:typed_data';

/// Byte-compatible Dart mirror of the PulsePad binary wire protocol
/// (see the Python `pulsepad/protocol.py`).
///
/// All packets share the lead byte:
///   bits 7..4 : protocol version
///   bits 3..0 : packet type
///
/// GAMEPAD (13 bytes):
///   [0]  header
///   [1]  buttons bitmask lo
///   [2]  buttons bitmask hi
///   [3:5] LX i16
///   [5:7] LY i16
///   [7:9] RX i16
///   [9:11]RY i16
///   [11] L2 u8 (0..255)
///   [12] R2 u8
///
/// PING / PONG (11 bytes): [0] header [1:9] i64 timestamp ms [9:11] u16 seq
/// HAPTIC (4 bytes): [0] header [1] duration/10ms [2] intensity 0..255 [3] motor
/// HELLO (1 byte):  [0] header

const int kProtocolVersion = 0x01;

const int kTypeGamepad = 0x01;
const int kTypePing = 0x02;
const int kTypePong = 0x03;
const int kTypeHaptic = 0x04;
const int kTypeHello = 0x05;

const int kGamepadSize = 13;
const int kPingSize = 11;
const int kPongSize = 11;
const int kHapticSize = 4;

// Button flags - low byte
const int kBtnA = 0x0001;
const int kBtnB = 0x0002;
const int kBtnX = 0x0004;
const int kBtnY = 0x0008;
const int kBtnL1 = 0x0010;
const int kBtnR1 = 0x0020;
const int kBtnSelect = 0x0040;
const int kBtnStart = 0x0080;

// Button flags - high byte
const int kBtnL2 = 0x0001;
const int kBtnR2 = 0x0002;
const int kBtnL3 = 0x0004;
const int kBtnR3 = 0x0008;
const int kBtnDpadUp = 0x0010;
const int kBtnDpadDown = 0x0020;
const int kBtnDpadLeft = 0x0040;
const int kBtnDpadRight = 0x0080;

const Map<String, int> kBtnLoNames = {
  'A': kBtnA, 'B': kBtnB, 'X': kBtnX, 'Y': kBtnY,
  'L1': kBtnL1, 'R1': kBtnR1, 'SELECT': kBtnSelect, 'START': kBtnStart,
};

const Map<String, int> kBtnHiNames = {
  'L2': kBtnL2, 'R2': kBtnR2, 'L3': kBtnL3, 'R3': kBtnR3,
  'DPAD_UP': kBtnDpadUp, 'DPAD_DOWN': kBtnDpadDown,
  'DPAD_LEFT': kBtnDpadLeft, 'DPAD_RIGHT': kBtnDpadRight,
};

int _header(int type) => (kProtocolVersion << 4) | type;

/// A decoded gamepad snapshot.
class GamepadState {
  final int buttonsLo;
  final int buttonsHi;
  final int lx, ly, rx, ry;
  final int l2, r2;

  GamepadState(this.buttonsLo, this.buttonsHi,
      this.lx, this.ly, this.rx, this.ry, this.l2, this.r2);

  bool isDown(int flag) => (buttonsLo & flag) != 0;
  bool isDownHi(int flag) => (buttonsHi & flag) != 0;

  double axisFloat(int v) => v / 32767.0;
}

/// Encode the full controller snapshot as a 13-byte packet.
Uint8List encodeGamepad({
  required int buttonsLo,
  required int buttonsHi,
  required int lx,
  required int ly,
  required int rx,
  required int ry,
  required int l2,
  required int r2,
}) {
  final b = ByteData(kGamepadSize);
  b.setUint8(0, _header(kTypeGamepad));
  b.setUint8(1, buttonsLo & 0xFF);
  b.setUint8(2, buttonsHi & 0xFF);
  b.setInt16(3, lx, Endian.little);
  b.setInt16(5, ly, Endian.little);
  b.setInt16(7, rx, Endian.little);
  b.setInt16(9, ry, Endian.little);
  b.setUint8(11, l2 & 0xFF);
  b.setUint8(12, r2 & 0xFF);
  return b.buffer.asUint8List();
}

GamepadState? decodeGamepad(Uint8List data) {
  if (data.length < kGamepadSize) return null;
  final b = ByteData.sublistView(data);
  return GamepadState(
    b.getUint8(1),
    b.getUint8(2),
    b.getInt16(3, Endian.little),
    b.getInt16(5, Endian.little),
    b.getInt16(7, Endian.little),
    b.getInt16(9, Endian.little),
    b.getUint8(11),
    b.getUint8(12),
  );
}

Uint8List encodePing(int timestampMs, [int seq = 0]) {
  final b = ByteData(kPingSize);
  b.setUint8(0, _header(kTypePing));
  b.setInt64(1, timestampMs, Endian.little);
  b.setUint16(9, seq & 0xFFFF, Endian.little);
  return b.buffer.asUint8List();
}

Uint8List encodePong(int timestampMs, [int seq = 0]) {
  final b = ByteData(kPongSize);
  b.setUint8(0, _header(kTypePong));
  b.setInt64(1, timestampMs, Endian.little);
  b.setUint16(9, seq & 0xFFFF, Endian.little);
  return b.buffer.asUint8List();
}

(int, int)? decodePingPong(Uint8List data) {
  if (data.length < kPingSize) return null;
  final b = ByteData.sublistView(data);
  return (b.getInt64(1, Endian.little), b.getUint16(9, Endian.little));
}

Uint8List encodeHaptic(int durationMs, double intensity, [int motor = 0]) {
  final d = (durationMs ~/ 10).clamp(0, 255);
  final i = (intensity.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
  final b = ByteData(kHapticSize);
  b.setUint8(0, _header(kTypeHaptic));
  b.setUint8(1, d);
  b.setUint8(2, i);
  b.setUint8(3, motor & 0x01);
  return b.buffer.asUint8List();
}

(int, double, int)? decodeHaptic(Uint8List data) {
  if (data.length < kHapticSize) return null;
  final b = ByteData.sublistView(data);
  return (
    b.getUint8(1) * 10,
    b.getUint8(2) / 255.0,
    b.getUint8(3) & 0x01,
  );
}

Uint8List encodeHello() => Uint8List.fromList([_header(kTypeHello)]);

int typeOf(Uint8List data) {
  if (data.isEmpty) return -1;
  return data[0] & 0x0F;
}

int versionOf(Uint8List data) {
  if (data.isEmpty) return 0;
  return (data[0] & 0xF0) >> 4;
}

int floatToI16(double v) {
  if (v <= -1.0) return -32768;
  v = v.clamp(-1.0, 1.0);
  return (v * 32767).round();
}
