import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/packet.dart';
import '../services/connection_manager.dart';
import '../theme/app_theme.dart';

/// Full-screen QR scanner. Scans the QR code shown by the PC Control Center,
/// decodes the `pulsepad|...` payload and auto-fills the connection settings.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCode(Barcode? code) {
    if (code == null || code.rawValue == null || _handled) return;
    final manager = context.read<ConnectionManager>();
    final messenger = ScaffoldMessenger.of(context);
    if (!manager.applyQrPayload(code.rawValue!)) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Not a valid PulsePad QR code'),
            backgroundColor: AppTheme.red),
      );
      return;
    }

    _handled = true;
    final isWifi = manager.mode == ConnectionMode.wifi;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Loaded ${manager.ipAddress} (${isWifi ? "Wi-Fi" : "USB"})'),
        backgroundColor: AppTheme.green,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
          title: const Text('Scan PC QR',
              style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: AppTheme.bg,
          foregroundColor: AppTheme.textPrimary),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            errorBuilder: (context, error, child) => const Center(
              child: Text('Camera error',
                  style: TextStyle(color: AppTheme.textPrimary)),
            ),
            onDetect: (capture) {
              _handleCode(
                  capture.barcodes.isNotEmpty ? capture.barcodes.first : null);
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.accent.withAlpha(190), width: 2),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentAt(0.2),
                    blurRadius: 26,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point the camera at the QR code on the PC screen',
                style: TextStyle(
                    color: AppTheme.textPrimary.withAlpha(230),
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