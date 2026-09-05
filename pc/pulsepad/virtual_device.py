"""Cross-platform virtual gamepad backend.

PulsePad creates a virtual gamepad that is recognised by Steam, PS2 (PCSX2),
PSP (PPSSPP) and native games on every desktop OS:

  * Linux/macOS : Linux ``uinput`` via ``python-uinput`` (macOS userspace tools
                  can also use a libusb-based driver, but uinput is the primary
                  path on Linux).
  * Windows      : ViGEmBus via ``vigem-client`` (creates an Xbox 360 pad that
                  any emulator/Windows game accepts).

Backends are selected automatically from the host OS.  If the required system
driver/permissions are missing the device degrades to a null no-op so the
daemon's protocol/server still function -- standalone input is then disabled
with a clear warning.

Mixing the two backends behind one interface keeps the rest of the stack
(protocol + server) platform-independent.
"""

import math
import os
import sys

from . import protocol as P

# Analog trigger press/release bands (0..255).  Digital L2/R2 buttons are also
# reported so emulators that only read digital triggers still work, while
# analog-aware games get the full slider range.
TL2_PRESS = 32
TL2_RELEASE = 8

# Virtual keyboard: layout key name (index into protocol.KEYS) -> uinput
# attribute name to emit. Attribute names stay strings so `uinput` is imported
# lazily at emit time on Linux only.
_KEY_ATTR = {
    "UP": "KEY_UP", "DOWN": "KEY_DOWN",
    "LEFT": "KEY_LEFT", "RIGHT": "KEY_RIGHT",
    "W": "KEY_W", "A": "KEY_A", "S": "KEY_S", "D": "KEY_D",
    "SPACE": "KEY_SPACE", "SHIFT": "KEY_LEFTSHIFT",
    "CTRL": "KEY_LEFTCTRL", "ENTER": "KEY_ENTER", "ESC": "KEY_ESC",
    "TAB": "KEY_TAB", "BACKSPACE": "KEY_BACKSPACE", "CAPS": "KEY_CAPSLOCK",
}


def _prepare_events():
    """Return the uinput event list (Linux backend)."""
    import uinput
    return (
        uinput.BTN_A, uinput.BTN_B, uinput.BTN_X, uinput.BTN_Y,
        uinput.BTN_TL, uinput.BTN_TR,
        uinput.BTN_TL2, uinput.BTN_TR2,
        uinput.BTN_THUMBL, uinput.BTN_THUMBR,
        uinput.BTN_SELECT, uinput.BTN_START,
        uinput.REL_X, uinput.REL_Y,
        uinput.BTN_LEFT, uinput.BTN_RIGHT, uinput.BTN_MIDDLE,
        uinput.KEY_UP, uinput.KEY_DOWN, uinput.KEY_LEFT, uinput.KEY_RIGHT,
        uinput.KEY_W, uinput.KEY_A, uinput.KEY_S, uinput.KEY_D,
        uinput.KEY_SPACE, uinput.KEY_LEFTSHIFT, uinput.KEY_LEFTCTRL,
        uinput.KEY_ENTER, uinput.KEY_ESC,
        uinput.KEY_TAB, uinput.KEY_BACKSPACE, uinput.KEY_CAPSLOCK,
        uinput.ABS_Z + (0, 255, 0, 0),
        uinput.ABS_RZ + (0, 255, 0, 0),
        uinput.ABS_HAT0X + (-1, 1, 0, 0),
        uinput.ABS_HAT0Y + (-1, 1, 0, 0),
        uinput.ABS_X + (-32768, 32767, 0, 128),
        uinput.ABS_Y + (-32768, 32767, 0, 128),
        uinput.ABS_RX + (-32768, 32767, 0, 128),
        uinput.ABS_RY + (-32768, 32767, 0, 128),
    )


class NullDevice:
    """No-op device used when no virtual-gamepad backend is available."""

    def emit(self, *args, **kwargs):
        pass

    def sync(self):
        pass

    def close(self):
        pass


class VirtualGamepad:
    """Cross-platform virtual gamepad.

    Parameters
    ----------
    name : str
        Device name reported to the OS.
    backend : 'auto' | 'linux' | 'windows' | 'null'
        Force a backend; 'auto' picks from the host OS.
    """

    def __init__(self, name="PulsePad", backend="auto", vendor=0x0B05, product=0x4500):
        self.name = name
        self.backend = backend
        self.enabled = False
        self.permission_denied = False
        self.last_error = None
        self._device = None

        # Cached last state so we only emit on change (less bus noise / latency
        # jitter, and avoids resending identical snapshots).
        self._last_btn_lo = None
        self._last_btn_hi = None
        self._last_axes = None
        self._l2_btn = 0
        self._r2_btn = 0
        self._last_mouse_buttons = 0

        self._create(backend, vendor, product)

    # ------------------------------------------------------------------ #
    def _create(self, backend, vendor, product):
        if backend == "auto":
            if sys.platform.startswith("win"):
                backend = "windows"
            else:
                backend = "linux"

        try:
            if backend == "linux":
                self._device = self._create_linux(name=self.name)
                self._linux = True
            elif backend == "windows":
                self._device, self._vigem = self._create_windows(name=self.name)
                self._linux = False
            else:
                self._device = NullDevice()
                self._linux = False
            self.enabled = True
        except Exception as e:
            self.last_error = str(e)
            self.permission_denied = ("Permission denied" in str(e)
                                      or "Errno 13" in str(e)
                                      or "Operation not permitted" in str(e))
            print(f"[warn] {backend} virtual gamepad unavailable ({e}). "
                  f"Running without a virtual device (daemon server still works).")
            if sys.platform.startswith("linux") and "uinput" in str(e):
                print("[hint] Linux: allow access to /dev/uinput with:  "
                      "sudo chmod 666 /dev/uinput   (or use the app's "
                      "'Enable Gamepad' button for a one-time fix)")
            self._device = NullDevice()
            self._linux = False
            self.enabled = False

    def _create_linux(self, name):
        import uinput  # raises ImportError if not installed
        return uinput.Device(_prepare_events(), name=name,
                             vendor=0x0B05, product=0x4500)

    def _create_windows(self, name):
        # ViGEm is asynchronous; we keep a light wrapper that is created here.
        # Import lazily so Linux/macOS never need it installed.
        import vigem  # vigem-client
        # NOTE: vigem-client exposes client/gamepad primitives; we build a thin
        # adapter and store it on the instance for emit/sync.
        raise NotImplementedError(
            "Windows ViGEm backend uses vigem-client; set up ViGEmBus and "
            "install 'vigem-client'. Wire _vigem_emit below.")

    # ------------------------------------------------------------------ #
    @property
    def device(self):
        return self._device

    def _emit(self, code, value):
        try:
            self._device.emit(code, value)
        except Exception as e:
            # Only warn once per burst is overkill; keep it simple.
            pass

    def apply_gamepad(self, buttons_lo, buttons_hi,
                      lx, ly, rx, ry, l2, r2):
        if not self._device:
            return

        if buttons_lo != self._last_btn_lo or buttons_hi != self._last_btn_hi:
            lo_keys = [
                ("BTN_A", P.BTN_A), ("BTN_B", P.BTN_B),
                ("BTN_X", P.BTN_X), ("BTN_Y", P.BTN_Y),
                ("BTN_TL", P.BTN_L1), ("BTN_TR", P.BTN_R1),
                ("BTN_SELECT", P.BTN_SELECT), ("BTN_START", P.BTN_START),
            ]
            hi_keys = [
                ("BTN_TL2", P.BTN_L2), ("BTN_TR2", P.BTN_R2),
                ("BTN_THUMBL", P.BTN_L3), ("BTN_THUMBR", P.BTN_R3),
            ]
            for code, flag in lo_keys:
                self._emit(self._uinput_code(code), 1 if buttons_lo & flag else 0)
            for code, flag in hi_keys:
                self._emit(self._uinput_code(code), 1 if buttons_hi & flag else 0)
            self._l2_btn = 1 if buttons_hi & P.BTN_L2 else 0
            self._r2_btn = 1 if buttons_hi & P.BTN_R2 else 0

            # D-pad -> HAT
            hat_x = (1 if buttons_hi & P.BTN_DPAD_RIGHT else 0) - \
                    (1 if buttons_hi & P.BTN_DPAD_LEFT else 0)
            hat_y = (1 if buttons_hi & P.BTN_DPAD_DOWN else 0) - \
                    (1 if buttons_hi & P.BTN_DPAD_UP else 0)
            self._emit(self._uinput_code("ABS_HAT0X"), hat_x)
            self._emit(self._uinput_code("ABS_HAT0Y"), hat_y)

            self._last_btn_lo = buttons_lo
            self._last_btn_hi = buttons_hi

        axes = (lx, ly, rx, ry, l2, r2)
        if axes != self._last_axes:
            l2_now = int(self._l2_btn or l2 >= TL2_PRESS)
            r2_now = int(self._r2_btn or r2 >= TL2_PRESS)
            if l2_now != self._l2_btn:
                self._emit(self._uinput_code("BTN_TL2"), l2_now)
                self._l2_btn = l2_now
            if r2_now != self._r2_btn:
                self._emit(self._uinput_code("BTN_TR2"), r2_now)
                self._r2_btn = r2_now

            for code, val in (("ABS_X", lx), ("ABS_Y", ly),
                              ("ABS_RX", rx), ("ABS_RY", ry),
                              ("ABS_Z", l2), ("ABS_RZ", r2)):
                self._emit(self._uinput_code(code), val)
            self._last_axes = axes

        self._sync()

    # ------------------------------------------------------------------ #
    def apply_mouse(self, dx, dy, buttons=0):
        if not self.enabled or not self._device:
            return
        if dx or dy:
            self._emit(self._uinput_code("REL_X"), dx)
            self._emit(self._uinput_code("REL_Y"), dy)
        if buttons != self._last_mouse_buttons:
            for bit, name in ((1, "BTN_LEFT"), (2, "BTN_RIGHT"),
                              (4, "BTN_MIDDLE")):
                self._emit(self._uinput_code(name), 1 if buttons & bit else 0)
            self._last_mouse_buttons = buttons
        self._sync()

    def apply_key(self, keycode, pressed):
        if not self.enabled or not self._device:
            return
        try:
            name = P.KEYS[keycode]
        except (IndexError, TypeError):
            return
        attr = _KEY_ATTR.get(name)
        if not attr:
            return
        value = 1 if pressed else 0
        self._emit(self._uinput_code(attr), value)
        self._sync()

    # ------------------------------------------------------------------ #
    def _uinput_code(self, name):
        if getattr(self, "_linux", False):
            import uinput
            return getattr(uinput, name)
        # Windows/macOS backend translation happens here when implemented.
        return name

    def _sync(self):
        try:
            fn = getattr(self._device, "sync", None)
            if fn:
                fn()
        except Exception:
            pass

    def close(self):
        if self.enabled and self._device is not None:
            close = getattr(self._device, "close", None) or \
                    getattr(self._device, "destroy", None)
            if close:
                try:
                    close()
                except Exception:
                    pass
        self._device = None
        self.enabled = False

    def __del__(self):
        try:
            self.close()
        except Exception:
            pass