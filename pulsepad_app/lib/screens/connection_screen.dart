import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import 'controller_screen.dart';
import 'settings_screen.dart';
import '../models/packet.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.gamepad, size: 100, color: Color(0xFF6366F1)),
              const SizedBox(height: 16),
              const Text(
                'PulsePad',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              const Text(
                'Connection Mode',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Consumer<ConnectionManager>(
                builder: (context, manager, _) => Column(
                  children: [
                    _buildModeOption(
                      context,
                      manager,
                      ConnectionMode.usb,
                      'USB (Recommended)',
                      'Sub-5ms latency via ADB',
                    ),
                    const SizedBox(height: 12),
                    _buildModeOption(
                      context,
                      manager,
                      ConnectionMode.wifi,
                      'Wi-Fi',
                      'Up to 15ms latency',
                    ),
                    if (manager.mode == ConnectionMode.wifi) ...[
                      const SizedBox(height: 16),
                      _buildIpInput(context, manager),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Consumer<ConnectionManager>(
                  builder: (context, manager, _) => ElevatedButton(
                    onPressed: manager.state == ConnectionState.connecting
                        ? null
                        : () => _handleConnect(context, manager),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      manager.state == ConnectionState.connecting
                          ? 'Connecting...'
                          : 'CONNECT',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<ConnectionManager>(
                builder: (context, manager, _) => Text(
                  _getStatusText(manager),
                  style: TextStyle(
                    color: manager.state == ConnectionState.error
                        ? Colors.red
                        : Colors.white54,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    ConnectionManager manager,
    ConnectionMode mode,
    String title,
    String subtitle,
  ) {
    final isSelected = manager.mode == mode;
    return GestureDetector(
      onTap: () => manager.setMode(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode == ConnectionMode.usb ? Icons.usb : Icons.wifi,
              color: isSelected ? const Color(0xFF6366F1) : Colors.white54,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  Widget _buildIpInput(BuildContext context, ConnectionManager manager) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Enter PC IP address',
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.router),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => manager.setIpAddress(value),
    );
  }

  void _handleConnect(BuildContext context, ConnectionManager manager) async {
    await manager.connect();
    if (manager.state == ConnectionState.connected && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControllerScreen()),
      );
    }
  }

  String _getStatusText(ConnectionManager manager) {
    switch (manager.state) {
      case ConnectionState.disconnected:
        return 'Not connected';
      case ConnectionState.connecting:
        return 'Establishing connection...';
      case ConnectionState.connected:
        return 'Ready to play';
      case ConnectionState.error:
        return 'Connection failed';
    }
  }
}