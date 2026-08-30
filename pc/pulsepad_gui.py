#!/usr/bin/env python3
"""PulsePad PC GUI (Tkinter).

A small desktop window that lets you start and stop the PulsePad daemon and
watch live connection status.  The daemon runs *inside* this app's process, so
closing the window stops the background server completely -- no stray
processes left behind.

Run:
    python3 gui.py            (Linux / macOS)
    python  gui.py            (Windows)

No extra dependencies: uses Python's built-in Tkinter.
"""

import ipaddress
import socket
import sys
import threading
import time

try:
    import tkinter as tk
    from tkinter import ttk, scrolledtext
except ImportError:
    sys.exit("Tkinter is not available. Install it (e.g. apt install python3-tk).")

# Add the daemon package to the import path so we can run in-process.
HERE = __import__("os").path.dirname(__file__)
sys.path.insert(0, HERE)

from pulsepad.server import PulsePadServer   # noqa: E402
from pulsepad.virtual_device import VirtualGamepad  # noqa: E402
from pulsepad import qr_config  # noqa: E402

try:
    import qrcode  # pure Python, optional at runtime
except ImportError:
    qrcode = None


class PulsePadGUI:
    def __init__(self, root):
        self.root = root
        self.server = None
        self.pad = None
        self._log_target = "gui"   # route daemon prints into the GUI log
        self._status_thread = None

        root.title("PulsePad Control Center")
        root.geometry("640x620")
        root.protocol("WM_DELETE_WINDOW", self._on_close)

        # ---- toolbar ----
        bar = ttk.Frame(root, padding=(10, 8))
        bar.pack(fill="x")

        self.start_btn = ttk.Button(bar, text="▶ Start Daemon",
                                    command=self._start)
        self.start_btn.pack(side="left")
        self.stop_btn = ttk.Button(bar, text="■ Stop Daemon",
                                   command=self._stop, state="disabled")
        self.stop_btn.pack(side="left", padx=6)

        self.status_lbl = ttk.Label(bar, text="● Stopped", foreground="gray")
        self.status_lbl.pack(side="right")

        # ---- status grid ----
        info = ttk.LabelFrame(root, text="Connection status", padding=8)
        info.pack(fill="x", padx=10, pady=(0, 8))

        self.state_lbl = ttk.Label(info, text="Server:   off")
        self.state_lbl.grid(row=0, column=0, sticky="w")
        self.backend_lbl = ttk.Label(info, text="Gamepad:  -")
        self.backend_lbl.grid(row=1, column=0, sticky="w")
        self.clients_lbl = ttk.Label(info, text="Phone:    0 connected")
        self.clients_lbl.grid(row=0, column=1, sticky="w", padx=(24, 0))
        self.latency_lbl = ttk.Label(info, text="Latency:  -")
        self.latency_lbl.grid(row=1, column=1, sticky="w", padx=(24, 0))

        # local IP hint
        try:
            ip = self._local_ip()
        except Exception:
            ip = "unknown"
        ttk.Label(info, text=f"PC address (phone Wi-Fi): {ip}",
                  foreground="#666").grid(row=2, column=0, columnspan=2,
                                          sticky="w", pady=(6, 0))

        # ---- QR connect ----
        qr_frame = ttk.LabelFrame(root, text="Connect by QR (Wi-Fi)", padding=8)
        qr_frame.pack(fill="x", padx=10, pady=(0, 8))
        qr_row = ttk.Frame(qr_frame)
        qr_row.pack(fill="x")

        ttk.Label(
            qr_row,
            text="Scan this code with the PulsePad phone app to connect instantly:",
            foreground="#333").pack(side="left")
        self.qr_btn = ttk.Button(qr_row, text="Show QR",
                                 command=self._toggle_qr)
        self.qr_btn.pack(side="right")

        self.qr_canvas = tk.Canvas(qr_frame, width=300, height=300,
                                   bg="white", highlightthickness=0)
        self.qr_visible = False
        self._qr_payload = None

        # ---- log ----
        logf = ttk.LabelFrame(root, text="Log", padding=6)
        logf.pack(fill="both", expand=True, padx=10, pady=(0, 10))

        self.log = scrolledtext.ScrolledText(logf, state="disabled", height=14,
                                             font=("Monospace", 9))
        self.log.pack(fill="both", expand=True)

        self._update_status()
        threading.Thread(target=self._status_loop, daemon=True).start()

    # ------------------------------------------------------------------ #
    @staticmethod
    def _local_ip():
        # Preferred: the IP that can reach the internet (the "primary" NIC).
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
            finally:
                s.close()
        except OSError:
            pass
        # Offline LANs: resolve the hostname to a real LAN address.
        try:
            for addr in socket.gethostbyname_ex(socket.gethostname())[2]:
                if not addr.startswith("127."):
                    return addr
        except OSError:
            pass
        return "127.0.0.1"

    # ------------------------------------------------------------------ #
    def _toggle_qr(self):
        if self.qr_visible:
            self.qr_canvas.pack_forget()
            self.qr_visible = False
            self.qr_btn.config(text="Show QR")
            return
        payload = self._qr_payload or self._qr_payload_for()
        if not payload:
            return
        if qrcode is None:
            self.log_line("  ! 'qrcode' module not installed; cannot show QR")
            return
        self._draw_qr(payload)
        self.qr_canvas.pack(pady=(8, 0))
        self.qr_visible = True
        self.qr_btn.config(text="Hide QR")
        self.log_line(f"[qr] QR payload: {payload}")

    def _qr_payload_for(self):
        try:
            host = self._local_ip()
        except Exception:
            self.log_line("  ! cannot detect local IP for QR")
            return None
        if self.server is not None:
            tcp = self.server.tcp_port
            udp = self.server.udp_port
        else:
            tcp, udp = 5005, 5006
        self._qr_payload = qr_config.build_payload("udp", host, tcp, udp)
        return self._qr_payload

    def _draw_qr(self, payload):
        qr = qrcode.QRCode(border=1)
        qr.add_data(payload)
        qr.make(fit=True)
        matrix = qr.get_matrix()          # list[list[bool]] (no quiet zone)
        n = len(matrix)
        size = 300
        self.qr_canvas.delete("all")
        cell = size / float(n + 2)        # reserve 1-module quiet zone each side
        for r, row in enumerate(matrix):
            for c, dark in enumerate(row):
                if dark:
                    x0, y0 = (c + 1) * cell, (r + 1) * cell
                    x1, y1 = x0 + cell, y0 + cell
                    self.qr_canvas.create_rectangle(x0, y0, x1, y1,
                                                    fill="black", outline="")
        self.qr_canvas.config(width=size, height=size)

    # ------------------------------------------------------------------ #
    def log_line(self, msg):
        def _w():
            self.log.configure(state="normal")
            self.log.insert("end", msg + "\n")
            self.log.see("end")
            self.log.configure(state="disabled")
        self.root.after(0, _w)

    def _start(self):
        if self.server and self.server.running:
            return
        self.log_line("Starting PulsePad daemon...")
        try:
            # Auto-detect backend; on Linux without uinput perms it degrades
            # to null and prints a hint.  --no-x used if you just want networking.
            self.pad = VirtualGamepad(backend="auto")
            self.server = PulsePadServer(self.pad)
        except Exception as e:
            self.log_line(f"  ! failed to start: {e}")
            return

        # Route server/daemon prints into the GUI log.
        server = self.server
        orig_print = print

        def tee(*args, **k):
            orig_print(*args, **k)
            try:
                self.log_line("  " + " ".join(str(a) for a in args))
            except Exception:
                pass
        builtins_print_patch(tee)

        self.server.start()
        self.log_line(f"  backend: {self.backend_name()}")
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self._update_status()

    def _stop(self):
        if not self.server:
            return
        self.log_line("Stopping daemon...")
        try:
            self.server.stop()
        finally:
            try:
                if self.pad:
                    self.pad.close()
            except Exception:
                pass
            self.server = None
            self.pad = None
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self._update_status()

    # ------------------------------------------------------------------ #
    def backend_name(self):
        if not self.pad:
            return "-"
        b = getattr(self.pad, "backend", "auto")
        if not getattr(self.pad, "enabled", False):
            return f"{b} (unavailable)"
        return b

    def _update_status(self):
        running = bool(self.server and self.server.running)
        if running:
            self.status_lbl.config(text="● Running", foreground="#0a0")
            self.state_lbl.config(text="Server:   running")
        else:
            self.status_lbl.config(text="● Stopped", foreground="gray")
            self.state_lbl.config(text="Server:   off")

        self.backend_lbl.config(text="Gamepad:  " + self.backend_name())

        if running:
            n = len(list(getattr(self.server, "_tcp_clients", [])))
            self.clients_lbl.config(text=f"Phone:    {n} connected")
            lat = getattr(self.server, "latency_ms", 0) or 0
            self.latency_lbl.config(text=f"Latency:  {lat} ms")
        else:
            self.clients_lbl.config(text="Phone:    0 connected")
            self.latency_lbl.config(text="Latency:  -")

    def _status_loop(self):
        while True:
            time.sleep(0.5)
            try:
                self._update_status()
            except Exception:
                pass

    def _on_close(self):
        if self.server and self.server.running:
            try:
                self.server.stop()
            except Exception:
                pass
            try:
                if self.pad:
                    self.pad.close()
            except Exception:
                pass
        self.root.destroy()


_ORIG_PRINT = None


def builtins_print_patch(tee):
    global _ORIG_PRINT
    import builtins
    if _ORIG_PRINT is None:
        _ORIG_PRINT = builtins.print
    builtins.print = tee


def main():
    root = tk.Tk()
    try:
        ttk.Style().theme_use("clam")
    except Exception:
        pass
    PulsePadGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
