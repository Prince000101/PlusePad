/// Wire / UI enums shared across PulsePad.
library;

enum ConnectionMode { usb, wifi }

enum ConnectionStatus { disconnected, connecting, connected, error }

enum ControllerLayout { gamepad, custom }

/// Descriptor returned by the PC discovery beacon so the phone can connect
/// without typing an IP address.
class DiscoveredServer {
  final String host;
  final int udpPort;
  final int tcpPort;
  final String name;

  DiscoveredServer(this.host, this.udpPort, this.tcpPort, this.name);
}

/// Decoded QR connection payload (mirrors `pulsepad/qr_config.py`).
class QrPayload {
  final String mode; // 'tcp' | 'udp'
  final String host;
  final int connectPort;
  final int tcpPort;
  final int udpPort;
  final String name;

  QrPayload(this.mode, this.host, this.connectPort, this.tcpPort, this.udpPort,
      this.name);
}

/// Parse a `pulsepad|<mode>|<host>|<connect>|<tcp>|<udp>|<name>` QR payload.
/// Returns null if the string is not a valid PulsePad QR code.
QrPayload? parseQrPayload(String raw) {
  final s = raw.trim();
  if (!s.toLowerCase().startsWith('pulsepad')) return null;
  final parts = s.split('|');
  if (parts.length < 6) return null;
  final mode = parts[1];
  if (mode != 'tcp' && mode != 'udp') return null;
  final host = parts[2];
  if (host.isEmpty) return null;
  final connect = int.tryParse(parts[3]);
  final tcp = int.tryParse(parts[4]);
  final udp = int.tryParse(parts[5]);
  if (connect == null || tcp == null || udp == null) return null;
  final name = parts.length > 6 ? parts[6] : 'PulsePad';
  return QrPayload(mode, host, connect, tcp, udp, name);
}
