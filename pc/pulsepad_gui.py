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
import math
import socket
import sys
import threading
import time
import queue

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
from pulsepad import protocol as protocol  # noqa: E402

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
        self._ui_q = queue.Queue()
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

        # Simulated phone: streams a fake controller over UDP so you can test
        # the whole pipeline (client count, latency, virtual gamepad) without
        # touching a real phone.  Sees input in any gamepad tester.
        self.sim_btn = ttk.Button(bar, text="▶ Simulate Phone",
                                  command=self._toggle_sim, state="disabled")
        self.sim_btn.pack(side="left", padx=6)
        self._sim_stop = None

        # One-time Linux uinput permission fix so the virtual gamepad works
        # without any manual terminal work on locked-down machines.
        self.enable_btn = ttk.Button(bar, text="⚠ Enable Gamepad",
                                     command=self._enable_gamepad)
        self.enable_btn.pack(side="left", padx=6)
        self._enable_running = False

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
        self.root.after(100, self._pump_ui)
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
        # Thread-safe: executed on the main loop via _pump_ui (called from
        # daemon threads too, thanks to the builtins.print tee).
        self._post_ui(lambda: self._log_line_now(msg))

    def _log_line_now(self, msg):
        self.log.configure(state="normal")
        self.log.insert("end", msg + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def _post_ui(self, fn):
        self._ui_q.put(fn)

    def _pump_ui(self):
        # Main thread only (re-scheduled by root.after). Executes UI updates
        # posted from any worker thread.
        try:
            while True:
                fn = self._ui_q.get_nowait()
                try:
                    fn()
                except Exception:
                    pass
        except queue.Empty:
            pass
        self.root.after(100, self._pump_ui)

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
        self._finish_start()

    def _finish_start(self):
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
        if self.pad and getattr(self.pad, "permission_denied", False):
            self.log_line("  ! virtual gamepad needs one-time permission. "
                          "Click 'Enable Gamepad' to fix it automatically.")
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.sim_btn.config(state="normal")
        self._update_status()

    # ------------------------------------------------------------------ #
    # One-time Linux uinput permission fix (no manual terminal work).
    # Installs a persistent udev rule so the virtual gamepad works on any
    # Linux box and survives reboots, using the OS's normal & convenient
    # privilege prompt (pkexec/polkit first, then sudo).
    # ------------------------------------------------------------------ #
    def _enable_gamepad(self):
        import subprocess
        if self._enable_running:
            return
        if sys.platform.startswith("win"):
            self.log_line("  ! Gamepad is already enabled on Windows backend.")
            return
        if sys.platform.startswith("darwin"):
            self.log_line("  ! macOS has no uinput yet; gamepad backend is "
                          "network-only on this OS.")
            return
        self._enable_running = True
        self.enable_btn.config(state="disabled", text="⏳ Enabling...")
        threading.Thread(target=self._do_enable, args=(subprocess,),
                         daemon=True).start()

    def _do_enable(self, subprocess):
        rule = ('KERNEL=="uinput", GROUP="input", MODE="0666"\n'
                'KERNEL=="uhid", GROUP="input", MODE="0666"\n')
        script = (
            "mkdir -p /etc/udev/rules.d && "
            "printf '%s' " + _shell_quote(rule) + " > /etc/udev/rules.d/99-uinput.rules && "
            "udevadm control --reload-rules; "
            "udevadm trigger; "
            "chmod 666 /dev/uinput 2>/dev/null; "
            "chmod 666 /dev/uhid 2>/dev/null; "
            "true"
        )
        try:
            cmds = self._privileged_commands(script)
            if not cmds:
                self._log_async("  ! Need a privileged launcher to enable the "
                                "gamepad. Install polkit (pkexec) or sudo.")
                return
            self._log_async("  requesting one-time system permission "
                            "(once; never needed again on this PC)...")
            last_err = "no privileged launcher output"
            for cmd in cmds:
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True)
                out, _ = proc.communicate(timeout=120)
                if proc.returncode == 0:
                    self._log_async("  ✓ uinput access granted. Restarting gamepad...")
                    self._recreate_after_enable()
                    return
                last_err = (out or "no output").strip()
            self._log_async("  ! Enable failed: " + last_err)
        except FileNotFoundError:
            self._log_async("  ! No privileged launcher found (need 'pkexec' or "
                            "'sudo'). Install polkit or run manually.")
        except Exception as e:
            self._log_async(f"  ! Enable error: {e}")
        finally:
            self._enable_running = False
            self._post_ui(lambda:
                self.enable_btn.config(state="normal", text="⚠ Enable Gamepad"))

    def _privileged_commands(self, script):
        # Prefer polkit (nice desktop dialog); try sudo when it is unavailable.
        cmds = []
        if self._which("pkexec"):
            cmds.append(["pkexec", "bash", "-c", script])
        if self._which("sudo"):
            cmds.append(["bash", "-c", "sudo -S bash -c " + _shell_quote(script)])
        return cmds

    @staticmethod
    def _which(exe):
        import shutil
        return shutil.which(exe)

    def _recreate_after_enable(self):
        # The user may have the daemon running with a null device. Rebuild the
        # gamepad now that perms are fixed and reconnect.
        def _rebuild():
            was_running = bool(self.server and self.server.running)
            try:
                if was_running:
                    self.server.stop()
                    self.server = None
                if self.pad:
                    try:
                        self.pad.close()
                    except Exception:
                        pass
                self.pad = VirtualGamepad(backend="auto")
                if not self.pad.enabled:
                    self._log_async(
                        "  ! Still could not open /dev/uinput after enabling: "
                        + (self.pad.last_error or "unknown"))
                    self._post_ui(self._update_status)
                    return
                if was_running:
                    self.server = PulsePadServer(self.pad)
                    self.server.start()
                    self._log_async("  ✓ Virtual gamepad enabled and running! "
                                    "Reconnect your phone and press buttons.")
                    self._post_ui(self._controls_running)
                else:
                    # Daemon was never started; just refresh the gamepad line.
                    self._log_async("  ✓ Virtual gamepad ready. Click "
                                    "'Start Daemon' to use it.")
                    self._post_ui(self._update_status)
            except Exception as e:
                self._log_async(f"  ! restart error: {e}")
        threading.Thread(target=_rebuild, daemon=True).start()

    def _controls_running(self):
        # Main thread only. Reflect "daemon running" on the toolbar buttons.
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.sim_btn.config(state="normal")
        self._update_status()

    def _log_async(self, msg):
        self._post_ui(lambda: self.log_line(msg))

    def _stop(self):
        if not self.server:
            return
        if self._sim_stop:
            self._sim_stop.set()
            self._sim_stop = None
            self.sim_btn.config(text="▶ Simulate Phone")
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
        self.sim_btn.config(state="disabled")
        self._update_status()

    # ------------------------------------------------------------------ #
    # Simulated phone (live test without a device)
    # ------------------------------------------------------------------ #
    def _toggle_sim(self):
        if self._sim_stop:
            self._sim_stop.set()
            self._sim_stop = None
            self.sim_btn.config(text="▶ Simulate Phone")
            self.log_line("[sim] simulated phone stopped")
            return
        if not (self.server and self.server.running):
            self.log_line("  ! start the daemon first")
            return
        self._sim_stop = threading.Event()
        self.sim_btn.config(text="■ Simulate Off")
        threading.Thread(target=self._sim_loop,
                         args=(self._sim_stop,), daemon=True).start()
        self.log_line("[sim] simulated phone streaming to the daemon "
                      "(open a gamepad tester to see input)")

    def _sim_loop(self, stop):
        # Behaves exactly like the phone app over UDP: announces with HELLO,
        # then streams full-state GAMEPAD snapshots and PINGs.  This drives
        # client_count, the latency display and the virtual gamepad.
        target = ("127.0.0.1", self.server.udp_port)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.sendto(protocol.encode_hello(), target)
            t0 = time.time()
            seq = 0
            last_ping = 0.0
            while not stop.is_set():
                now = time.time()
                t = (now - t0) * 2.0
                # Rotating left stick + A held + B pulses.
                lx = int(math.sin(t) * 32767)
                ly = int(math.cos(t) * 32767)
                btn = protocol.BTN_A | (protocol.BTN_B if int(now * 4) % 2 else 0)
                s.sendto(protocol.encode_gamepad(
                    btn & 0xFF, (btn >> 8) & 0xFF, lx, ly, 0, 0, 0, 0), target)
                if now - last_ping > 0.5:
                    last_ping = now
                    s.sendto(protocol.encode_ping(int(now * 1000), seq), target)
                seq += 1
                stop.wait(0.01)
        except OSError as e:
            self.log_line(f"  ! sim socket error: {e}")
        finally:
            try:
                # Recenter the stick so the pad returns to neutral.
                s.sendto(protocol.encode_gamepad(0, 0, 0, 0, 0, 0, 0, 0), target)
            except OSError:
                pass
            s.close()

    # ------------------------------------------------------------------ #
    def backend_name(self):
        if not self.pad:
            return "-"
        b = getattr(self.pad, "backend", "auto")
        if getattr(self.pad, "permission_denied", False):
            return "linux (needs Enable, see button ↑)"
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
            tcp, udp = self.server.transport_counts
            if udp and tcp:
                label = f"Phone:    {tcp + udp} connected (USB {tcp} / Wi-Fi {udp})"
            elif udp:
                label = f"Phone:    {udp} connected (Wi-Fi)"
            elif tcp:
                label = f"Phone:    {tcp} connected (USB)"
            else:
                label = "Phone:    0 connected"
            self.clients_lbl.config(text=label)
            lat = getattr(self.server, "latency_ms", 0) or 0
            self.latency_lbl.config(text=f"Latency:  {lat} ms")
        else:
            self.clients_lbl.config(text="Phone:    0 connected")
            self.latency_lbl.config(text="Latency:  -")

    def _status_loop(self):
        while True:
            time.sleep(0.5)
            try:
                self._post_ui(self._update_status)
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


def _shell_quote(s):
    """Single-quote a string for safe use inside a `sh -c` command line."""
    return "'" + s.replace("'", "'\\''") + "'"


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
