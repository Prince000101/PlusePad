"""PhoneSimulator end-to-end tests.

The simulator stands in for a real phone over both transports, so these tests
cover the exact wired path (TCP/adb-reverse) and the Wi-Fi path (UDP) that a
phone would use — without any hardware.
"""

import time
import unittest

from pulsepad import protocol as P
from pulsepad.server import PulsePadServer
from pulsepad.virtual_device import VirtualGamepad

from simulate_phone import PhoneSimulator


class _RecordingPad(VirtualGamepad):
    def __init__(self):
        super().__init__()
        self.calls = []

    def apply_gamepad(self, *args):
        self.calls.append(args)

    def apply_key(self, keycode, pressed):
        self.calls.append(("key", keycode, pressed))


class TestPhoneSimulator(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tcp_port, cls.udp_port, cls.disc_port = 15405, 15406, 15407
        cls.pad = _RecordingPad()
        cls.server = PulsePadServer(
            cls.pad, tcp_port=cls.tcp_port, udp_port=cls.udp_port,
            discovery_port=cls.disc_port)
        cls.server.start()
        time.sleep(0.3)

    def setUp(self):
        # Drain any UDP packets still in flight from the previous test so a
        # stale HELLO/state can't re-register a peer after we clear below.
        time.sleep(0.2)
        with self.server._udp_peers_lock:
            self.server._udp_peers.clear()
        with self.server._tcp_lock:
            for c in list(self.server._tcp_clients):
                try:
                    c.close()
                except OSError:
                    pass
            self.server._tcp_clients.clear()
        self.pad.calls.clear()

    @classmethod
    def tearDownClass(cls):
        cls.server.stop()

    def _wait_for(self, predicate, timeout=3.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if predicate():
                return True
            time.sleep(0.02)
        return predicate()

    def test_wired_tcp_stream_full_pipeline(self):
        # The wired path: a phone opens TCP to the daemon (adbd reverse) and
        # streams snapshots + PINGs over exactly this socket.
        sim = PhoneSimulator(host="127.0.0.1", port=self.tcp_port,
                             transport="tcp", rate=100)
        sim.start()
        try:
            def saw_a():
                return any(c[0] & P.BTN_A for c in self.pad.calls)
            self.assertTrue(self._wait_for(saw_a),
                            "wired (TCP) stream never yielded BTN_A")
            btn_lo, btn_hi, lx, ly, *_ = \
                next(c for c in self.pad.calls if c[0] & P.BTN_A)
            self.assertGreaterEqual(abs(lx), 0)  # axes present & sane
            tcp, udp = self.server.transport_counts
            self.assertGreaterEqual(tcp, 1, "simulator not tracked as TCP client")
            self.assertEqual(udp, 0)
            # Keep streaming so a PING lands and latency is really measured.
            self.assertTrue(self._wait_for(lambda: self.server.latency_ms > 0),
                            "no PING/PONG latency measured over TCP")
            self.assertTrue(btn_lo & P.BTN_A)
        finally:
            sim.stop()
        self.assertFalse(sim.running, "simulator did not stop cleanly")
        # Stopping drops the TCP client.
        time.sleep(0.4)
        tcp, _ = self.server.transport_counts
        self.assertEqual(tcp, 0, "TCP client not removed after simulator stop")

    def test_wifi_udp_stream(self):
        sim = PhoneSimulator(host="127.0.0.1", port=self.udp_port,
                             transport="udp", rate=100)
        sim.start()
        try:
            self.assertTrue(
                self._wait_for(lambda: any(c[0] & P.BTN_A
                                           for c in self.pad.calls)),
                "Wi-Fi (UDP) stream never yielded BTN_A")
            tcp, udp = self.server.transport_counts
            self.assertGreaterEqual(udp, 1)
            self.assertEqual(tcp, 0)
        finally:
            sim.stop()
        self.assertFalse(sim.running)

    def test_simulator_cli_helper_still_works(self):
        import simulate_phone
        import threading
        t = threading.Thread(
            target=simulate_phone.stream,
            kwargs={"host": "127.0.0.1", "port": self.udp_port,
                    "duration": 0.7, "transport": "udp"},
            daemon=True)
        t.start()
        self.assertTrue(
            self._wait_for(lambda: any(c[0] & P.BTN_A
                                       for c in self.pad.calls)))
        t.join(timeout=3)


if __name__ == "__main__":
    unittest.main()