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
import os
import queue
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
from pulsepad import protocol as P  # noqa: E402

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
        root.geometry("700x940")
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

        # ---- tester (Notebook: Gamepad / Keyboard) ----
        test_frame = ttk.LabelFrame(
            root, text="Tester — mirrors your phone controller",
            padding=8)
        test_frame.pack(fill="x", padx=10, pady=(0, 8))
        self._tester_nb = ttk.Notebook(test_frame)
        self._tester_nb.pack()

        _game_tab = ttk.Frame(self._tester_nb)
        self.tester_canvas = tk.Canvas(_game_tab, width=620, height=344,
                                       bg="#141419", highlightthickness=0)
        self.tester_canvas.pack(padx=4, pady=4)
        self._tester_nb.add(_game_tab, text="Gamepad")

        _kb_tab = ttk.Frame(self._tester_nb)
        self.key_canvas = tk.Canvas(_kb_tab, width=620, height=344,
                                    bg="#141419", highlightthickness=0)
        self.key_canvas.pack(padx=4, pady=4)
        self._tester_nb.add(_kb_tab, text="Keyboard")

        self._tester_ids = {}
        self._key_ids = {}
        self._tester_state = (0, 0, 0, 0, 0, 0, 0, 0)
        self._tester_keys = set()
        self._tester_dirty = False
        self._build_tester()
        self._build_keys()

        # ---- log ----
        logf = ttk.LabelFrame(root, text="Log", padding=6)
        logf.pack(fill="both", expand=True, padx=10, pady=(0, 10))

        self.log = scrolledtext.ScrolledText(logf, state="disabled", height=8,
                                             font=("Monospace", 9))
        self.log.pack(fill="both", expand=True)

        self._update_status()
        self.root.after(100, self._pump_ui)
        self.root.after(33, self._tester_tick)
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
    # Gamepad tester: a default PS2 controller model that mimics the live
    # gamepad state streamed by the phone (buttons light up in PS2 colors,
    # analog sticks move, triggers fill).
    # ------------------------------------------------------------------ #
    _T_IDLE = "#2a2a32"
    _T_EDGE = "#3e3e48"
    _T_LIT = "#63b6ff"
    _T_ARM = "#3a3a42"
    _T_BODY = "#232329"
    _T_RIM = "#3a3a44"
    _T_STICK = "#26262c"
    _T_LABEL = "#5a5a66"
    _T_BRAND = "#4a4a55"
    _PS_COLORS = {"t": "#35c24c", "c": "#3a7bd5",
                  "o": "#e8484c", "s": "#e8578f"}

    @staticmethod
    def _round_rect(canvas, x0, y0, x1, y1, r, **kw):
        # Smooth polygon approximating a rounded rectangle.
        pts = [(x0 + r, y0), (x1 - r, y0), (x1, y0), (x1, y0 + r),
               (x1, y1 - r), (x1, y1), (x1 - r, y1), (x0 + r, y1),
               (x0, y1), (x0, y1 - r), (x0, y0 + r), (x0, y0)]
        return canvas.create_polygon(pts, smooth=True, splinesteps=24, **kw)

    def _build_tester(self):
        c = self.tester_canvas
        ids = self._tester_ids
        C = self.__class__

        # Body.
        ids["body"] = self._round_rect(c, 36, 46, 584, 330, 26,
                                       fill=C._T_BODY, outline=C._T_RIM, width=1)

        # Shoulder pills (L2 outer, L1 inner, mirrored R).
        for name, x0, x1 in (("L2", 34, 112), ("L1", 130, 208),
                             ("R1", 412, 490), ("R2", 508, 586)):
            ids[name] = self._round_rect(c, x0, 12, x1, 34, 10,
                                         fill=C._T_IDLE, outline=C._T_EDGE,
                                         width=1)
            ids[name + "_lbl"] = c.create_text(
                (x0 + x1) / 2, 23, text=name, fill=C._T_LABEL,
                font=("TkDefaultFont", 9), width=0)
        # L2/R2 analog fill bars (rise with trigger value).
        ids["L2f"] = c.create_rectangle(37, 32, 109, 32, fill=C._T_LIT,
                                        outline="")
        ids["R2f"] = c.create_rectangle(511, 32, 583, 32, fill=C._T_LIT,
                                        outline="")

        # D-pad cross (left).
        ids["d_v"] = c.create_rectangle(133, 78, 163, 162, fill=C._T_ARM,
                                        outline="")
        ids["d_h"] = c.create_rectangle(106, 105, 190, 135, fill=C._T_ARM,
                                        outline="")
        for name, x0, y0, x1, y1 in (("d_up", 133, 63, 163, 93),
                                     ("d_down", 133, 147, 163, 177),
                                     ("d_left", 91, 105, 121, 135),
                                     ("d_right", 175, 105, 205, 135)):
            ids[name] = c.create_oval(x0, y0, x1, y1, fill=C._T_ARM,
                                      outline="")

        # Face buttons (PS2 diamond, symbols in PS2 colors).
        faces = [("t", 472, 78), ("o", 514, 120),
                 ("c", 472, 162), ("s", 430, 120)]
        for key, fx, fy in faces:
            ids[key] = c.create_oval(fx - 19, fy - 19, fx + 19, fy + 19,
                                     fill=C._T_IDLE, outline=C._T_EDGE,
                                     width=1)
            ps = C._PS_COLORS[key]
            if key == "t":
                ids[key + "_sym"] = c.create_polygon(
                    [(fx, fy - 8), (fx - 8, fy + 7), (fx + 8, fy + 7)],
                    fill="", outline=ps, width=3)
            elif key == "o":
                ids[key + "_sym"] = c.create_oval(fx - 8, fy - 8, fx + 8, fy + 8,
                                                  fill="",
                                                  outline=ps, width=3)
            elif key == "c":
                ids[key + "_sym"] = c.create_line(
                    fx - 8, fy, fx + 8, fy, width=3, fill=ps)
                ids[key + "_sym2"] = c.create_line(
                    fx, fy - 8, fx, fy + 8, width=3, fill=ps)
            else:
                ids[key + "_sym"] = c.create_rectangle(fx - 7, fy - 7, fx + 7,
                                                       fy + 7, fill="",
                                                       outline=ps, width=3)

        # SELECT / START pills (center).
        ids["sel"] = self._round_rect(c, 284, 136, 322, 152, 8,
                                      fill=C._T_IDLE, outline=C._T_EDGE,
                                      width=1)
        ids["sel_lbl"] = c.create_text(303, 144, text="SELECT",
                                       fill=C._T_LABEL, font=("TkDefaultFont", 7))
        ids["start"] = self._round_rect(c, 326, 136, 364, 152, 8,
                                        fill=C._T_IDLE, outline=C._T_EDGE,
                                        width=1)
        ids["start_lbl"] = c.create_text(345, 144, text="START",
                                         fill=C._T_LABEL,
                                         font=("TkDefaultFont", 7))

        # Brand text.
        ids["brand"] = c.create_text(310, 196, text="PULSE PAD",
                                     fill=C._T_BRAND, font=("TkDefaultFont", 10, "bold"))
        # Live axes readout.
        ids["readout"] = c.create_text(310, 300, text="", fill="#3f3f48",
                                       font=("Monospace", 8))

        # Analog sticks (base ring drawn static, cap + press dot move).
        for key, sx, sy in (("l", 148, 238), ("r", 472, 238)):
            ids[key + "base"] = c.create_oval(sx - 38, sy - 38, sx + 38, sy + 38,
                                              fill=C._T_STICK, outline=C._T_RIM,
                                              width=2)
            ids[key + "cap"] = c.create_oval(sx - 22, sy - 22, sx + 22, sy + 22,
                                             fill="#4a4a54",
                                             outline="#5a5a66", width=2)
            ids[key + "dot"] = c.create_oval(sx - 5, sy - 5, sx + 5, sy + 5,
                                             fill=C._T_LIT, outline="",
                                             state="hidden")

    def _on_server_state(self, btn_lo, btn_hi, lx, ly, rx, ry, l2, r2):
        # Called from the daemon thread on every received gamepad snapshot.
        self._tester_state = (btn_lo & 0xFFFF, btn_hi & 0xFFFF,
                              int(lx), int(ly), int(rx), int(ry), int(l2), int(r2))
        self._tester_dirty = True

    def _on_server_key(self, keycode, pressed):
        # Called from the daemon thread on virtual-keyboard press/release.
        try:
            name = P.KEYS[keycode]
        except IndexError:
            return
        if pressed:
            self._tester_keys.add(name)
        else:
            self._tester_keys.discard(name)
        self._tester_dirty = True

    def _reset_tester(self):
        self._tester_state = (0, 0, 0, 0, 0, 0, 0, 0)
        self._tester_keys.clear()
        self._tester_dirty = True

    def _tester_tick(self):
        if self._tester_dirty:
            self._tester_dirty = False
            try:
                self._redraw_tester()
            except Exception:
                pass
            try:
                self._redraw_keys()
            except Exception:
                pass
        self.root.after(33, self._tester_tick)

    def _redraw_tester(self):
        from pulsepad import protocol as P
        c = self.tester_canvas
        ids = self._tester_ids
        lo, hi, lx, ly, rx, ry, l2v, r2v = self._tester_state

        def lit(flag):
            return bool((lo | hi) & flag)

        # Shoulder buttons.
        for name, flag in (("L1", P.BTN_L1), ("R1", P.BTN_R1)):
            on = lit(flag)
            c.itemconfig(ids[name], fill=self._T_LIT if on else self._T_IDLE,
                         outline="#ffffff" if on else self._T_EDGE)
            c.itemconfig(ids[name + "_lbl"], fill="#ffffff" if on else self._T_LABEL)
        for name, flag in (("L2", P.BTN_L2), ("R2", P.BTN_R2)):
            on = lit(flag)
            c.itemconfig(ids[name], fill=self._T_LIT if on else self._T_IDLE,
                         outline="#ffffff" if on else self._T_EDGE)
            c.itemconfig(ids[name + "_lbl"], fill="#ffffff" if on else self._T_LABEL)
        # Trigger fill bars.
        for name, val, x0, x1, b in (("L2f", l2v, 40, 106, 31),
                                     ("R2f", r2v, 514, 580, 31)):
            h = int(max(0, min(255, val)) / 255.0 * b)
            c.coords(ids[name], x0, 32 - h, x1, 32)
            c.itemconfig(ids[name], fill=self._T_LIT if h else "")

        # D-pad arms + caps.
        for name, flag in (("d_up", P.BTN_DPAD_UP), ("d_down", P.BTN_DPAD_DOWN),
                           ("d_left", P.BTN_DPAD_LEFT),
                           ("d_right", P.BTN_DPAD_RIGHT)):
            on = lit(flag)
            c.itemconfig(ids[name],
                         fill=self._T_LIT if on else self._T_ARM,
                         outline="#ffffff" if on else "")

        # Face buttons (PS2 colors).
        for key, flag in (("t", P.BTN_Y), ("o", P.BTN_B),
                          ("c", P.BTN_A), ("s", P.BTN_X)):
            on = lit(flag)
            c.itemconfig(ids[key],
                         fill=self._PS_COLORS[key] if on else self._T_IDLE,
                         outline="#ffffff" if on else self._T_EDGE,
                         width=2 if on else 1)
            c.itemconfig(ids[key + "_sym"],
                         fill="#ffffff" if on else "",
                         outline="#ffffff" if on else self._PS_COLORS[key])
            sym2 = ids.get(key + "_sym2")
            if sym2 is not None:
                c.itemconfig(sym2,
                             fill="#ffffff" if on else "",
                             outline="#ffffff" if on else self._PS_COLORS[key])

        # SELECT / START.
        for name, flag in (("sel", P.BTN_SELECT), ("start", P.BTN_START)):
            on = lit(flag)
            c.itemconfig(ids[name], fill=self._T_LIT if on else self._T_IDLE,
                         outline="#ffffff" if on else self._T_EDGE)
            c.itemconfig(ids[name + "_lbl"],
                         fill="#ffffff" if on else self._T_LABEL)

        # Analog sticks: move caps by axis, show press dot on L3/R3.
        for key, sx, sy, ax, ay, press in (("l", 148, 238, lx, ly, P.BTN_L3),
                                           ("r", 472, 238, rx, ry, P.BTN_R3)):
            off = 13.0
            nx = sx + max(-1.0, min(1.0, ax / 32767.0)) * off
            ny = sy + max(-1.0, min(1.0, ay / 32767.0)) * off
            c.coords(ids[key + "cap"], nx - 22, ny - 22, nx + 22, ny + 22)
            c.coords(ids[key + "dot"], nx - 5, ny - 5, nx + 5, ny + 5)
            c.itemconfig(ids[key + "dot"], state="normal" if lit(press) else "hidden")

        # Axes readout.
        c.itemconfig(ids["readout"], text="LX %+0.2f LY %+0.2f  "
                                          "RX %+0.2f RY %+0.2f  L2 %3d R2 %3d"
                     % (lx / 32767.0, ly / 32767.0, rx / 32767.0,
                        ry / 32767.0, l2v % 256, r2v % 256))

    # ------------------------------------------------------------------ #
    # Keyboard mirror: same virtual-keyboard layout as the phone screen
    # (top row + WASD/arrow clusters + wide SPACE). Keys light live as the
    # phone sends TYPE_KEY press/release packets.
    # ------------------------------------------------------------------ #
    _K_TOP = ["ESC", "TAB", "CAPS", "SHIFT", "CTRL", "ENTER", "BACKSPACE"]
    _K_CLUSTERS = [
        {"W": (0, 0), "D": (1, 0), "A": (0, 1), "S": (1, 1)},
        {"UP": (0, 0), "RIGHT": (1, 0), "LEFT": (0, 1), "DOWN": (1, 1)},
    ]

    @staticmethod
    def _key_rect(c, x0, y0, x1, y1, label, font=9):
        return (PulsePadGUI._round_rect(c, x0, y0, x1, y1, 8,
                                        fill=PulsePadGUI._T_IDLE,
                                        outline=PulsePadGUI._T_EDGE, width=1),
                c.create_text((x0 + x1) / 2, (y0 + y1) / 2, text=label,
                              fill=PulsePadGUI._T_LABEL,
                              font=("TkDefaultFont", font)))

    def _build_keys(self):
        c = self.key_canvas
        ids = self._key_ids
        # Top row.
        key_x = 12
        top_defs = [("ESC", 52), ("TAB", 52), ("CAPS", 96), ("SHIFT", 96),
                    ("CTRL", 78), ("ENTER", 78), ("BACKSPACE", 92)]
        for name, w in top_defs:
            body, lbl = self._key_rect(c, key_x, 18, key_x + w, 52, name)
            ids[name] = (body, lbl)
            key_x += w + 10
        # Clusters.
        clust_y0 = 64
        for i, layout in enumerate(self._K_CLUSTERS):
            x0 = 16 + i * 310
            c.create_oval(x0 + 128, clust_y0 + 34, x0 + 154,
                          clust_y0 + 60, fill=self._T_BODY, outline="")
            for key, (cx, cy) in layout.items():
                kx = x0 + cx * 78
                ky = clust_y0 + cy * 78
                body, lbl = self._key_rect(c, kx, ky, kx + 66, ky + 66, key,
                                           font=10 if len(key) == 1 else 8)
                ids[key] = (body, lbl)
        # Space bar.
        body, lbl = self._key_rect(c, 210, 212, 410, 258, "SPACE", font=12)
        ids["SPACE"] = (body, lbl)

    def _redraw_keys(self):
        c = self.key_canvas
        ids = self._key_ids
        for (body, lbl), name in ((v, k) for k, v in ids.items()):
            on = name in self._tester_keys
            c.itemconfig(body, fill=self._T_LIT if on else self._T_IDLE,
                         outline="#ffffff" if on else self._T_EDGE,
                         width=1)
            c.itemconfig(lbl, fill="#ffffff" if on else self._T_LABEL)

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
            self.server = PulsePadServer(self.pad,
                                         on_state=self._on_server_state,
                                         on_key=self._on_server_key)
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
                'KERNEL=="uhid", GROUP="input", MODE="0666"\n'
                'KERNEL=="event*", SUBSYSTEM=="input", '
                'ATTRS{name}=="PulsePad*", MODE="0666", OPTIONS+="nowatch"\n'
                'KERNEL=="js*", SUBSYSTEM=="input", '
                'ATTRS{name}=="PulsePad*", MODE="0666", OPTIONS+="nowatch"\n')
        script = (
            "mkdir -p /etc/udev/rules.d && "
            "printf '%s' " + _shell_quote(rule) +
            " > /etc/udev/rules.d/99-uinput.rules && "
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

    def _auto_ensure_input(self):
        # Called automatically at startup: on first run on Linux the release
        # app installs the udev rules itself (one pkexec/sudo prompt) so a
        # double-clicked binary works with no manual terminal steps.  Skips
        # silently once the rules are present, and never overlaps a manual
        # 'Enable Gamepad' click.
        import subprocess
        if not sys.platform.startswith("linux") or self._enable_running:
            return
        rules_file = "/etc/udev/rules.d/99-uinput.rules"
        try:
            with open(rules_file) as f:
                if "PulsePad" in f.read():
                    return  # already configured
        except OSError:
            pass
        self._log_async("  first run: checking virtual-gamepad permission...")
        self._enable_running = True  # guard: overlaps `_do_enable`'s finally
        threading.Thread(target=self._do_enable, args=(subprocess,),
                         daemon=True).start()

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
                    self.server = PulsePadServer(self.pad,
                                                 on_state=self._on_server_state,
                                                 on_key=self._on_server_key)
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
        self._update_status()

    def _log_async(self, msg):
        self._post_ui(lambda: self.log_line(msg))

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
        self._reset_tester()
        self._update_status()

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
    gui = PulsePadGUI(root)
    gui._auto_ensure_input()
    root.mainloop()


if __name__ == "__main__":
    main()
