/// Wire / UI enums shared across PulsePad.
library;

enum ConnectionMode { usb, wifi }

enum ConnectionStatus { disconnected, connecting, connected, error }

enum ControllerLayout { gamepad, psp, ps5, mouse, keyboard }

/// Descriptor returned by the PC discovery beacon so the phone can connect
/// without typing an IP address.
class DiscoveredServer {
  final String host;
  final int udpPort;
  final int tcpPort;
  final String name;

  DiscoveredServer(this.host, this.udpPort, this.tcpPort, this.name);
}
