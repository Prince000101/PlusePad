import 'dart:typed_data';

import '../services/protocol.dart' as p;

/// Mutable controller state and its binary encoding.
///
/// The wire format is a full, self-contained snapshot (see
/// `pulsepad/services/protocol.dart`).  Because every packet carries the whole
/// state, the phone can send at a high rate over lossy UDP and the PC is always
/// tracking the latest state -- there is no "missed delta" problem.
class ControllerState {
  int buttonsLo = 0;
  int buttonsHi = 0;

  // Raw axis values, already scaled to i16 range (-32768..32767).
  int lx = 0, ly = 0, rx = 0, ry = 0;
  // Raw analog triggers 0..255.
  int l2 = 0, r2 = 0;

  /// Set a named gamepad button (A/B/X/Y/L1/R1/SELECT/START in lo,
  /// L2/R2/L3/R3/DPAD_* in hi).  Returns true if the value changed.
  bool setButton(String name, bool pressed) {
    final lo = p.kBtnLoNames[name];
    if (lo != null) {
      final next = pressed ? buttonsLo | lo : buttonsLo & ~lo;
      if (next == buttonsLo) return false;
      buttonsLo = next;
      return true;
    }
    final hi = p.kBtnHiNames[name];
    if (hi != null) {
      final next = pressed ? buttonsHi | hi : buttonsHi & ~hi;
      if (next == buttonsHi) return false;
      buttonsHi = next;
      return true;
    }
    return false;
  }

  /// Set an axis by name (LX/LY/RX/RY) from a -1..1 float.
  bool setAxis(String name, double v) {
    final raw = p.floatToI16(v);
    switch (name) {
      case 'LX':
        if (raw == lx) return false;
        lx = raw;
        return true;
      case 'LY':
        if (raw == ly) return false;
        ly = raw;
        return true;
      case 'RX':
        if (raw == rx) return false;
        rx = raw;
        return true;
      case 'RY':
        if (raw == ry) return false;
        ry = raw;
        return true;
    }
    return false;
  }

  /// Set an analog trigger (L2/R2) from a 0..1 float (scaled to 0..255).
  bool setTrigger(String name, double v) {
    final raw = (v.clamp(0.0, 1.0) * 255).round();
    if (name == 'L2') {
      if (raw == l2) return false;
      l2 = raw;
      return true;
    }
    if (name == 'R2') {
      if (raw == r2) return false;
      r2 = raw;
      return true;
    }
    return false;
  }

  void reset() {
    buttonsLo = 0;
    buttonsHi = 0;
    lx = ly = rx = ry = 0;
    l2 = r2 = 0;
  }

  Uint8List encode() => p.encodeGamepad(
        buttonsLo: buttonsLo,
        buttonsHi: buttonsHi,
        lx: lx,
        ly: ly,
        rx: rx,
        ry: ry,
        l2: l2,
        r2: r2,
      );
}
