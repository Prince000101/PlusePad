# PulsePad — Logic Guide

How the whole system works: wire protocol, PC daemon, virtual device, phone app,
latency model, and known limits. Source of truth: `pc/pulsepad/protocol.py` (PC)
and `phone/lib/services/protocol.dart` (phone) — keep both byte-identical.

---

## 1. Topology

```
┌──────────────────┐   USB (TCP:5005, adb reverse)   ┌───────────────────┐
│   Phone app      │ ───────────────────────────────►│   PC daemon       │
│   (Flutter)      │   Wi-Fi (UDP:5006)              │   (pulsedad)      │
└──────┬───────────┘   discovery (UDP:54321)         └─────────┬─────────┘
       │                                                       │ uinput payload
       │  13-byte full-state snapshots                         ▼
       └────────────────────────────────────────►  virtual device (VirtualGamepad)
                                                     (Steam, PCSX2, PPSSPP, …)
```

Two transports, same protocol:
- **USB**: TCP `localhost:5005`, set up with `adb reverse tcp:5005 tcp:5005`. Reliable, ordered, lowest latency.
- **Wi-Fi**: UDP `:5006`. Unreliable, but the snapshot protocol makes drops harmless (see §2.1).

The phone is always the **sender** of input; the PC only replies with
PING/PONG (latency) and HAPTIC (rumble).

---

## 2. Wire protocol

Every packet starts with one header byte: high nibble = protocol version (1),
low nibble = packet type. Multi-byte numbers are little-endian.

### 2.1 Design rule — snapshots, not deltas

Every GAMEPAD packet is a full snapshot of the controller.  If a UDP packet
is lost, the next one is already complete, so no delta reconciliation is
needed and drops are cheap.

(Exceptions: MOUSE is a *relative* delta, because mouse state is accumulated
on the PC side; KEY is a press/release event, not a state image.)

### 2.2 Packets

| Type | Byte | Size | Payload |
|------|-----:|-----:|---------|
| GAMEPAD | 0x01 | 13 | btn_lo u8, btn_hi u8, LX, LY, RX, RY (i16 −32768..32767), L2, R2 (u8 0..255) |
| PING    | 0x02 | 11 | timestamp ms (i64), seq (u16) |
| PONG    | 0x03 | 11 | echoes PING's timestamp + seq |
| HAPTIC  | 0x04 | 4  | duration_10ms u8, intensity u8, motor u8 |
| HELLO   | 0x05 | 1  | empty; the "find me" discovery request |
| MOUSE   | 0x06 | 6  | dx i16, dy i16, buttons u8 |
| KEY     | 0x07 | 3  | keycode u8, pressed u8 |

### 2.3 Button bitmasks

btn_lo: `A=0x01 B=0x02 X=0x04 Y=0x08 L1=0x10 R1=0x20 SELECT=0x40 START=0x80`
btn_hi: `L2=0x01 R2=0x02 L3=0x04 R3=0x08 DPAD_UP=0x10 DPAD_DOWN=0x20 DPAD_LEFT=0x40 DPAD_RIGHT=0x80`

(Hi-byte split was introduced so 8 face buttons + 8 hi buttons fit in two bytes;
`X`/`Y` no longer collide with `BTN_THUMBL`.)

### 2.4 MOUSE buttons

`buttons` u8: `1=LEFT 2=RIGHT 4=MIDDLE`. dx/dy are **relative** deltas; PC
applies + accumulates them via uinput `REL_X`/`REL_Y`.

### 2.5 Virtual-keyboard table (`KEYS`)

The shared key table — index in the list *is* the wire keycode. Order is a
`contract`: it must stay identical in `protocol.py` and `protocol.dart` (a unit
test cross-checks the count/order).

```
0:UP  1:DOWN  2:LEFT  3:RIGHT  4:W  5:A  6:S  7:D
8:SPACE  9:SHIFT  10:CTRL  11:ENTER  12:ESC  13:TAB  14:BACKSPACE  15:CAPS
```

### 2.6 Discovery beacon

```
"PPB1" | udp_port u16 BE | tcp_port u16 BE | name_len u8 | name…
```

- PC: `server.py:make_beacon()` — replies to a phone's HELLO on UDP
  `255.255.255.255:54321` via unicast.
- Phone: sends HELLO to the broadcast address, collects beacon replies in a 1.2 s
  window, lists them under "FOUND".

---

## 3. PC daemon (`pc/pulsepad/server.py`)

### 3.1 Sockets & threads

- `DISCOVERY_ADDR=255.255.255.255`, `DISCOVERY_PORT=54321`, `UDP_PORT=5006`, `TCP_PORT=5005`.
- Three listener threads:
  1. **TCP** — `accept()` (0.5 s timeout) → per-client thread; used for USB.
  2. **UDP** — `recvfrom()` on 5006; peers tracked by `(addr, seq)`.
  3. **Discovery** — disco port; answers HELLO/beacons.
- `stop()` joins all three listener threads (and their children) with a
  timeout — the 0.5 s socket timeouts guarantee the threads exit and the ports
  are free for an immediate restart (regression test covers this race).
- `verify_device_socket()` — pre-validates `device.compat` before dispatch.

### 3.2 Client accounting & pruning

- A **client** = any peer that sends a GAMEPAD packet (phone or Simulate).
- Peers are pruned after a few seconds of silence (`_reap_stale_peers`), so a
  phone that vanishes doesn't ghost-lock the virtual pad.
- Broadcast packets are dropped silently except PING (so two phones can share
  one PC).

### 3.3 Dispatch

- `GAMEPAD` → `device.accept_gamepad(...)`.
- `MOUSE` → `device.apply_mouse(dx, dy, buttons)` (logged in `/tmp/pulsepad_input.log`).
- `KEY` → `device.apply_key(keycode, pressed)`.
- `PING` → echo `PONG` back so the phone can measure RTT.
- Malformed/unknown packets → dropped with a log line (never crash).
- `parse_beacon`, packet-size guards, and protocol-version checks live here.

---

## 4. Virtual device (`pc/pulsepad/virtual_device.py`)

### 4.1 Uinput mapping

| Input | uinput code |
|-------|-------------|
| A/B/X/Y            | BTN_A / BTN_B / BTN_X / BTN_Y |
| L1/R1              | BTN_TL / BTN_TR |
| L2/R2              | ABS_Z / ABS_RZ (analog 0–255) **and** BTN_TL2 / BTN_TR2 (digital edge) |
| SELECT/START       | BTN_SELECT / BTN_START |
| L3/R3              | BTN_THUMBL / BTN_THUMBR |
| D-pad              | ABS_HAT0X / ABS_HAT0Y |
| Sticks             | ABS_X / ABS_Y / ABS_RX / ABS_RY (−32768..32767) |
| Mouse              | REL_X / REL_Y, BTN_LEFT / BTN_RIGHT / BTN_MIDDLE |
| Keyboard           | Linux key codes (KEY_UP…KEY_CAPS, 16 keys max) |

Backends: `LinuxVirtualGamepad` (uinput), `WindowsVirtualGamepad` (ViGEm),
`NullVirtualGamepad` (headless/no-root testing). macOS runs the daemon but has
no virtual pad yet.

### 4.2 Change-only sending

The device caches the last emitted state per key/axis and **only emits on
change** (with digital/analog hysteresis where relevant). This keeps `/proc`
and the game fast — a 250 Hz phone doesn't drown the bus with identical frames.

### 4.3 Why the lo/hi button split happened

uinput's `BTN_THUMBL` bits and gamepad X/Y must not collide; face buttons live
in the lo byte, triggers/L3/R3/d-pad in the hi byte, so `X`/`Y` never falsely
toggle THUMBL/THUMBR.

---

## 5. PC GUI (`pc/pulsepad_gui.py`)

- **Tkinter is single-threaded** — the daemon threads must not touch widgets.
  All UI updates go through a queue: `_post_ui(fn)` enqueues, a
  `_pump_ui(…, _controls_running)` periodic Tk `after` drains it. Guarded by a
  `_controls_running` flag so no UI mutation happens after `mainloop` exits.
- **Enable Gamepad** flow: try the current user with a preflight uinput probe →
  try `pkexec` → fall back to `sudo` (multi-candidate). Writes a udev rule for
  `/dev/uinput` (`scripts/setup_linux_input.sh`); macOS path is stubbed.
- **USB (cable)** button: runs `adb reverse tcp:<port> tcp:<port>` and checks
  `adb reverse --list` for confirmation (wired path setup).
- **Show QR** renders the shared `qr_config.py` payload (host + ports + mode);
  the phone scans it to auto-fill connection fields.
- **Help** tab documents the Wi-Fi and USB steps inside the app.
- **Close window = stop server** (threads joined, ports released, device
  detached).

---

## 6. Phone app (`phone/lib/`)

### 6.1 Connection flows (`services/connection_manager.dart`)

State machine: `disconnected → connecting → connected (+ error)`.
- **USB**: `Socket.connect('127.0.0.1', 5005)` (ad-hoc TCP, adb reverse).
- **Wi-Fi**: bind a UDP socket; send HELLO + PING to the target; wait for the
  PONG (ack) with `ack.future.timeout(3 s)` before reporting "connected".  If
  no PC answers, connect fails instead of a phantom "Connected".
- **QR**: decode payload → fills ip/ports/mode.
- **Auto-reconnect**: if TCP drops, `_reconnectTimer` (2 s) retries while
  `autoReconnect` is on. UDP has no client-side liveness loop (see §8).
- `setMode` / `setIpAddress` / `disconnect` all tear down sockets cleanly
  (`destroy()`, pong counter reset).

### 6.2 Send pipeline

- `Timer.periodic(4 ms)` = **250 Hz** coalescing loop: every tick it takes the
  *current* full state and encodes one 13-byte GAMEPAD snapshot. Much faster
  than per-widget events and immune to bursts.
- Sticks → `float_to_i16` clamp/round; deadzones applied **in the widgets**
  (`AnalogStick` has a built-in 0.12 deadzone), sensitivity via manager.
- Mouse senders use `encodeMouse(dx, dy, buttons)` (relative); keyboard uses
  `encodeKey(keycode, pressed)` from the shared `kKeys` table.
- `_send` is fully try/catch-guarded: a closed socket or a garbage typed IP
  (`InternetAddress.tryParse → null`) just logs and drops the packet — it can
  never crash an input handler or the 4 ms timer.

### 6.3 Receive pipeline

- `800 ms` stats timer — refreshes `sentCount`, latency, connection status.
- `1 s` PING timer → `_sendPing()`; PONG round-trip updates the latency pill.
- HAPTIC packets → rumble via the vibration plugin.
- MOUSE/KEY layout entries use real `GestureDetector` tracks (live touchpad +
  `onTapCancel` for key release) so drags/releases never stick.

### 6.4 Layouts & custom layout

- Presets: Gamepad (Playstation-style) plus My Custom (in `controller_screen.dart`).
- The default layout uses shoulder bumper clutter-free zones, with large
  SELECT/START/L3/R3 pills and press feedback (`AnimatedScale` + accent
  flash).
- `LayoutStore` (shared_preferences) persists a user's `CustomLayout`
  (JSON-encoded control slots) locally; `layout_editor_screen.dart` edits it.
  Each slot is typed (`pad:A`, `key:W`, `mouse:LMB`), so a gamepad `A` never
  collides with keyboard `A`.

---

## 7. Latency model

Where a packet's journey takes time:

| Stage | Typical |
|-------|---------|
| Touch event → widget (Flutter) | sub-ms |
| 4 ms coalescing tick | ≤ 4 ms |
| encode + send (USB / Wi-Fi) | ~0 / ~0.5–3 ms |
| transport | 1–5 ms USB, 5–15 ms Wi-Fi |
| PC dispatch → uinput | ~1 ms |

So a control reaches the OS in roughly **2–8 ms (USB)** / **8–20 ms (Wi-Fi)**.
PING/PONG reports the true RTT in the UI so you can see it yourself.

---

## 8. Limits & known constraints

- **macOS**: no virtual gamepad backend — network/server only.
- **Windows**: virtual pad requires ViGEmBus driver + `vigem-client` package.
- **Linux**: virtual pad needs `/dev/uinput` (udev rule or `sudo`); without it
  use `--no-virtual-device` (server/discovery still work).
- **No auth/encryption**: plaintext UDP/TCP on the LAN. Fine for home use;
  treat as "trusted network only".
- **UDP has no client-side liveness detection**: if the PC dies, the TCP path
  auto-reconnects, but a Wi-Fi connection can appear "connected" until the next
  send fails. Hearing loss detection is a known gap.
- **One touch per analog stick** (single-pointer pan).
- **Touchpads are pointed: multi-touch and wheel-scroll** aren't implemented
  (REL_WHEEL is a future protocol type).
- **16-key virtual keyboard** covers movement + common keys only.
- **L2/R2 digital + analog coexist**: `BTN_TL2/TR2` fire on any analog value > 0.
- **Peer cap**: TCP accepts multiple clients; UDP prunes silent peers after a
  few seconds. Broadcast GAMEPAD is dropped (only PING is answered) — one PC,
  one main pad.
- **Phone app needs the Flutter SDK to build/test** — the protocol mirrors in
  `protocol.dart` and `protocol.py` must stay byte-identical, verified by unit
  tests on both sides.

---

## 9. Testing

```bash
# PC — 38 unit tests (real loopback sockets, no root needed)
cd pc && python3 -m unittest discover -s tests

# Phone
cd phone && flutter analyze && flutter test
```

What the PC suite covers: packet encode/decode round-trips, hi/lo button split,
virtual-device event emission (real uinput on this machine), server dispatch
(GAMEPAD/MOUSE/KEY/PING/PONG), discovery beacon, peer pruning, haptic decode,
the daemon stop/start port-release race, and the simulated-phone end-to-end
path over both transports.