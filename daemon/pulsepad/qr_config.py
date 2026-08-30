"""Shared QR connection payload.

The PC Control Center shows a QR code encoding how the phone should connect;
the phone app scans it and auto-fills the host/ports/mode.  Keeping the format
here lets both sides stay in sync.

Format (pipe-delimited, ASCII only so it survives any QR encoder):
    pulsepad|<mode>|<host>|<connectPort>|<tcpPort>|<udpPort>|<name>
where:
    mode        = "tcp" (USB/adb) or "udp" (Wi-Fi)
    connectPort = the port to connect to for that mode (tcp -> tcpPort,
                  udp -> udpPort)
"""

import ipaddress

PREFIX = "pulsepad"


def build_payload(mode, host, tcp_port, udp_port, name="PulsePad"):
    """Return the QR payload string for the given connection parameters."""
    mode = "tcp" if mode == "tcp" else "udp"
    connect_port = tcp_port if mode == "tcp" else udp_port
    return "|".join(
        str(x) for x in (PREFIX, mode, host, connect_port, tcp_port, udp_port, name)
    )


def parse_payload(payload):
    """Parse a QR payload string into a dict, or None if malformed."""
    if not payload:
        return None
    payload = payload.strip()
    if not payload.lower().startswith(PREFIX):
        return None
    parts = payload.split("|")
    if len(parts) < 6:
        return None
    try:
        tbl = {"mode": parts[1], "host": parts[2],
               "connect_port": int(parts[3]),
               "tcp_port": int(parts[4]),
               "udp_port": int(parts[5])}
    except ValueError:
        return None
    tbl["name"] = parts[6] if len(parts) > 6 else "PulsePad"
    # sanity-check the host
    try:
        ipaddress.ip_address(tbl["host"])
    except ValueError:
        return None
    return tbl
