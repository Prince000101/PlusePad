"""Tests for the shared QR connection payload (PC <-> phone)."""

import unittest

from pulsepad import qr_config


class TestQrConfig(unittest.TestCase):
    def test_build_udp_payload(self):
        payload = qr_config.build_payload("udp", "192.168.1.10", 5005, 5006)
        expected = "pulsepad|udp|192.168.1.10|5006|5005|5006|PulsePad"
        self.assertEqual(payload, expected)

    def test_build_tcp_payload(self):
        payload = qr_config.build_payload("tcp", "127.0.0.1", 5005, 5006)
        expected = "pulsepad|tcp|127.0.0.1|5005|5005|5006|PulsePad"
        self.assertEqual(payload, expected)

    def test_parse_roundtrip(self):
        payload = qr_config.build_payload("udp", "10.0.0.5", 5005, 5006,
                                          name="Workshop PC")
        parsed = qr_config.parse_payload(payload)
        self.assertEqual(parsed["mode"], "udp")
        self.assertEqual(parsed["host"], "10.0.0.5")
        self.assertEqual(parsed["connect_port"], 5006)  # udp -> udp_port
        self.assertEqual(parsed["tcp_port"], 5005)
        self.assertEqual(parsed["udp_port"], 5006)
        self.assertEqual(parsed["name"], "Workshop PC")

    def test_parse_accepts_ascii_prefix_case(self):
        payload = "PULSEPAD|tcp|192.168.0.2|5005|5005|5006|PulsePad"
        parsed = qr_config.parse_payload(payload)
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed["host"], "192.168.0.2")

    def test_parse_rejects_garbage(self):
        self.assertIsNone(qr_config.parse_payload("not-a-qr"))
        self.assertIsNone(qr_config.parse_payload(""))

    def test_parse_rejects_bad_host(self):
        self.assertIsNone(
            qr_config.parse_payload("pulsepad|udp|not-an-ip|5006|5005|5006"))

    def test_parse_rejects_bad_ports(self):
        self.assertIsNone(
            qr_config.parse_payload("pulsepad|udp|1.2.3.4|abc|5005|5006"))

    def test_parse_defaults_name(self):
        parsed = qr_config.parse_payload("pulsepad|udp|1.2.3.4|5006|5005|5006")
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed["name"], "PulsePad")


if __name__ == "__main__":
    unittest.main()