"""Tests for the PulsePad binary protocol layer (no hardware required)."""

import unittest

from pulsepad import protocol as P
from pulsepad.server import make_beacon, parse_beacon


class TestProtocol(unittest.TestCase):
    def test_gamepad_roundtrip(self):
        packet = P.encode_gamepad(
            buttons_lo=P.BTN_A | P.BTN_START | P.BTN_L1,
            buttons_hi=P.BTN_DPAD_UP | P.BTN_R2,
            lx=32767, ly=-32768, rx=0, ry=1000,
            l2=200, r2=10,
        )
        self.assertEqual(len(packet), P.GAMEPAD_SIZE)
        self.assertEqual(P.type_of(packet), P.TYPE_GAMEPAD)
        self.assertEqual(P.version_of(packet), P.PROTOCOL_VERSION)

        btn_lo, btn_hi, lx, ly, rx, ry, l2, r2 = P.decode_gamepad(packet)
        self.assertEqual(btn_lo, P.BTN_A | P.BTN_START | P.BTN_L1)
        self.assertEqual(btn_hi, P.BTN_DPAD_UP | P.BTN_R2)
        self.assertEqual(lx, 32767)
        self.assertEqual(ly, -32768)
        self.assertEqual(rx, 0)
        self.assertEqual(ry, 1000)
        self.assertEqual(l2, 200)
        self.assertEqual(r2, 10)

    def test_gamepad_short_packet_raises(self):
        with self.assertRaises(ValueError):
            P.decode_gamepad(b"\x11\x00")

    def test_pingpong_roundtrip(self):
        pong = P.encode_pong(123456789, seq=42)
        self.assertEqual(len(pong), P.PONG_SIZE)
        ts, seq = P.decode_pingpong(pong)
        self.assertEqual(ts, 123456789)
        self.assertEqual(seq, 42)

    def test_haptic_roundtrip(self):
        haptic = P.encode_haptic(duration_ms=250, intensity=0.8, motor=1)
        d, i, m = P.decode_haptic(haptic)
        self.assertEqual(d, 250)
        self.assertAlmostEqual(i, 0.8, places=1)
        self.assertEqual(m, 1)

    def test_haptic_clamps(self):
        haptic = P.encode_haptic(duration_ms=100000, intensity=5.0)
        d, i, _ = P.decode_haptic(haptic)
        self.assertLessEqual(d, 2550)
        self.assertLessEqual(i, 1.0)

    def test_float_to_i16_clamps(self):
        self.assertEqual(P.float_to_i16(1.0), 32767)
        self.assertEqual(P.float_to_i16(-1.0), -32768)
        self.assertEqual(P.float_to_i16(2.0), 32767)
        self.assertEqual(P.float_to_i16(0.0), 0)

    def test_hello(self):
        hello = P.encode_hello()
        self.assertEqual(P.type_of(hello), P.TYPE_HELLO)
        self.assertEqual(len(hello), 1)

    def test_mouse_roundtrip(self):
        packet = P.encode_mouse(-120, 300, 0b101)
        self.assertEqual(len(packet), P.MOUSE_SIZE)
        self.assertEqual(P.type_of(packet), P.TYPE_MOUSE)
        dx, dy, buttons = P.decode_mouse(packet)
        self.assertEqual((dx, dy, buttons), (-120, 300, 0b101))

    def test_mouse_short_packet_raises(self):
        with self.assertRaises(ValueError):
            P.decode_mouse(b"\x16\x00")

    def test_key_roundtrip(self):
        self.assertIn("W", P.KEYS)
        idx = P.KEYS.index("W")
        packet = P.encode_key(idx, 1)
        self.assertEqual(len(packet), P.KEY_SIZE)
        self.assertEqual(P.type_of(packet), P.TYPE_KEY)
        code, pressed = P.decode_key(packet)
        self.assertEqual((code, pressed), (idx, 1))

    def test_key_short_packet_raises(self):
        with self.assertRaises(ValueError):
            P.decode_key(b"\x17\x00")

    def test_unknown_type(self):
        packet = bytes([(P.PROTOCOL_VERSION << 4) | 0x0F])
        self.assertEqual(P.type_of(packet), 0x0F)


class TestBeacon(unittest.TestCase):
    def test_beacon_roundtrip(self):
        beacon = make_beacon("PulsePad", 5006, 5005)
        parsed = parse_beacon(beacon)
        self.assertIsNotNone(parsed)
        udp_port, tcp_port, name = parsed
        self.assertEqual((udp_port, tcp_port), (5006, 5005))
        self.assertEqual(name, "PulsePad")

    def test_beacon_invalid(self):
        self.assertIsNone(parse_beacon(b"garbage"))


if __name__ == "__main__":
    unittest.main()
