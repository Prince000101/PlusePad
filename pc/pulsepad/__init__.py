"""PulsePad daemon package.

Exposes the protocol, virtual device and server layers as an importable unit so
the logic can be exercised headlessly (unit tests, CI) without a real uinput
device or physical /dev/uinput permissions.
"""

from . import protocol
from .virtual_device import VirtualGamepad
from .server import PulsePadServer

__all__ = ["protocol", "VirtualGamepad", "PulsePadServer"]
__version__ = "2.0.0"
