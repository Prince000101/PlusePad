"""PulsePad binary wire protocol.

Designed for ultra-low latency and correctness over lossy transport:

* Every GAMEPAD packet is a *self-contained snapshot* of the full controller
  state.  Because UDP may drop packets, sender and receiver never have to
  reconcile "missed deltas" -- the latest snapshot always reflects the full
  state, so a dropped packet is simply superseded by the next one.

* Packets are fixed, tiny, and endian-independent (byte-oriented).

Layout
------
Byte offsets :

  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  | Ver | Type   |  BtnLo (bitmask)   |  BtnHi (bitmask) ...     |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

GAMEPAD packet (type 0x01), 13 bytes:
  [0]   byte : 0x01 (version) << 4 | 0x01 (type)
  [1]   byte : button bitmask low
  [2]   byte : button bitmask high
  [3:5] i16  : LX  (-32768..32767)
  [5:7] i16  : LY
  [7:9] i16  : RX
  [9:11]i16  : RY
  [11]  byte : L2  (0..255)
  [12]  byte : R2  (0..255)

PING  packet (type 0x02), 9 bytes:  [0] ver<<4|type  [1:7] i64 timestamp ms  [7:9] seq
PONG  packet (type 0x03), 9 bytes (same layout as PING) -- echoes server time.
HAPTIC packet (type 0x04), 4 bytes: [0] ver<<4|type [1] duration_10ms [2] intensity 0-255 [3] motor 0-1
"""

import struct

PROTOCOL_VERSION = 0x1
PROTOCOL_MASK = 0x0F
TYPE_MASK = 0x0F

# Packet types
TYPE_GAMEPAD = 0x01
TYPE_PING = 0x02
TYPE_PONG = 0x03
TYPE_HAPTIC = 0x04
TYPE_HELLO = 0x05  # client -> server identification / discovery request

# Button flags (BtnLo)
BTN_A = 0x0001
BTN_B = 0x0002
BTN_X = 0x0004
BTN_Y = 0x0008
BTN_L1 = 0x0010
BTN_R1 = 0x0020
BTN_SELECT = 0x0040
BTN_START = 0x0080
# Button flags (BtnHi)
BTN_L2 = 0x0001
BTN_R2 = 0x0002
BTN_L3 = 0x0004
BTN_R3 = 0x0008
BTN_DPAD_UP = 0x0010
BTN_DPAD_DOWN = 0x0020
BTN_DPAD_LEFT = 0x0040
BTN_DPAD_RIGHT = 0x0080

GAMEPAD_SIZE = 13
PING_SIZE = 11
PONG_SIZE = 11
HAPTIC_SIZE = 4

# Axis / trigger mapping keys (used by the virtual device layer)
AXIS_LX = "LX"
AXIS_LY = "LY"
AXIS_RX = "RX"
AXIS_RY = "RY"
TRIGGER_L2 = "L2"
TRIGGER_R2 = "R2"

BTN_NAMES_LO = {
    "A": BTN_A,
    "B": BTN_B,
    "X": BTN_X,
    "Y": BTN_Y,
    "L1": BTN_L1,
    "R1": BTN_R1,
    "SELECT": BTN_SELECT,
    "START": BTN_START,
}
BTN_NAMES_HI = {
    "L2": BTN_L2,
    "R2": BTN_R2,
    "L3": BTN_L3,
    "R3": BTN_R3,
    "DPAD_UP": BTN_DPAD_UP,
    "DPAD_DOWN": BTN_DPAD_DOWN,
    "DPAD_LEFT": BTN_DPAD_LEFT,
    "DPAD_RIGHT": BTN_DPAD_RIGHT,
}


def _header(pkt_type: int) -> bytes:
    return bytes([(PROTOCOL_VERSION << 4) | pkt_type])


def encode_gamepad(buttons_lo: int, buttons_hi: int,
                   lx: int, ly: int, rx: int, ry: int,
                   l2: int, r2: int) -> bytes:
    """Encode a full controller snapshot as a 13-byte packet.

    Axes are raw i16 (-32768..32767), triggers raw 0..255.  The caller is
    responsible for clamping/rounding.
    """
    return struct.pack("<BBBhhhhBB",
                       (PROTOCOL_VERSION << 4) | TYPE_GAMEPAD,
                       buttons_lo & 0xFF, buttons_hi & 0xFF,
                       lx, ly, rx, ry, l2 & 0xFF, r2 & 0xFF)


def decode_gamepad(data: bytes):
    """Decode a GAMEPAD packet -> (buttons_lo, buttons_hi, lx, ly, rx, ry, l2, r2)."""
    if len(data) < GAMEPAD_SIZE:
        raise ValueError(f"GAMEPAD packet too short: {len(data)} < {GAMEPAD_SIZE}")
    _, btn_lo, btn_hi, lx, ly, rx, ry, l2, r2 = struct.unpack_from(
        "<BBBhhhhBB", data, 0)
    return btn_lo, btn_hi, lx, ly, rx, ry, l2, r2


def encode_ping(timestamp_ms: int, seq: int = 0) -> bytes:
    return struct.pack("<BQH", (PROTOCOL_VERSION << 4) | TYPE_PING,
                       timestamp_ms, seq & 0xFFFF)


def encode_pong(timestamp_ms: int, seq: int = 0) -> bytes:
    return struct.pack("<BQH", (PROTOCOL_VERSION << 4) | TYPE_PONG,
                       timestamp_ms, seq & 0xFFFF)


def decode_pingpong(data: bytes):
    """Decode PING/PONG -> (timestamp_ms, seq)."""
    if len(data) < PING_SIZE:
        raise ValueError("PING/PONG packet too short")
    _, ts, seq = struct.unpack_from("<BQH", data, 0)
    return ts, seq


def encode_haptic(duration_ms: int, intensity: float, motor: int = 0) -> bytes:
    d = max(0, min(2550, int(duration_ms // 10))) & 0xFF
    i = max(0, min(1.0, intensity))
    return struct.pack("<BBBB", (PROTOCOL_VERSION << 4) | TYPE_HAPTIC,
                       d, int(i * 255), motor & 0x01)


def decode_haptic(data: bytes):
    """Decode HAPTIC -> (duration_ms, intensity 0..1, motor)."""
    if len(data) < HAPTIC_SIZE:
        raise ValueError("HAPTIC packet too short")
    _, d, i, motor = struct.unpack_from("<BBBB", data, 0)
    return d * 10, i / 255.0, motor


def encode_hello() -> bytes:
    return bytes([(PROTOCOL_VERSION << 4) | TYPE_HELLO])


def type_of(data: bytes) -> int:
    if not data:
        raise ValueError("empty packet")
    return data[0] & TYPE_MASK


def version_of(data: bytes) -> int:
    if not data:
        raise ValueError("empty packet")
    return (data[0] & 0xF0) >> 4


def float_to_i16(v: float) -> int:
    if v <= -1.0:
        return -32768
    v = max(-1.0, min(1.0, v))
    return int(round(v * 32767))


def i16_to_float(v: int) -> float:
    return v / 32767.0
