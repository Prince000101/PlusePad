import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/packet.dart';
import '../services/connection_manager.dart';

/// Full-screen QR scanner. Scans the QR code shown by the PC Control Center,
/// decodes the `pulsepad|...` payload and auto-fills the connection settings.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool get _isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  bool _handled = false;

  void _handleCode(Barcode? code) {
    if (code == null || code.rawValue == null || _handled) return;
    final result = parseQrPayload(code.rawValue!);
    final messenger = ScaffoldMessenger.of(context);
    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Not a valid PulsePad QR code'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    _handled = true;
    final mode = result.mode == 'tcp'
        ? ConnectionMode.usb
        : ConnectionMode.wifi;
    context.read<ConnectionManager>().applyQr(
          result.host,
          mode,
          result.tcpPort,
          result.udpPort,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Loaded ${result.host} (${mode == ConnectionMode.wifi ? "Wi-Fi" : "USB"})'),
        backgroundColor: const Color(0xFF22C55E),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow =
        Rect.fromCenter(center: Offset.zero, width: 250, height: 250);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Scan PC QR'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white),
      body: Stack(
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            scanWindow: _isLandscape
                ? Rect.fromCenter(
                    center: const Offset(0, 0),
                    width: 260,
                    height: 260)
                : scanWindow,
            errorBuilder: (context, error, child) => const Center(
              child: Text('Camera error',
                  style: TextStyle(color: Colors.white)),
            ),
            onDetect: (capture) {
              _handleCode(
                  capture.barcodes.isNotEmpty ? capture.barcodes.first : null);
            },
          ),
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point the camera at the QR code on the PC screen',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    backgroundColor: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
