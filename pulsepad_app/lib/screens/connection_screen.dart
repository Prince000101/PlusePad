import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import 'controller_screen.dart';
import 'settings_screen.dart';
import '../models/packet.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.gamepad, size: 80, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'PulsePad',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Turn your phone into a game controller',
                        style: TextStyle(fontSize: 14, color: Colors.white54),
                      ),
                      const SizedBox(height: 48),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Connection Mode',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Consumer<ConnectionManager>(
                        builder: (context, manager, _) => Column(
                          children: [
                            _buildModeOption(
                              manager,
                              ConnectionMode.usb,
                              'USB',
                              'Low latency, recommended',
                            ),
                            const SizedBox(height: 10),
                            _buildModeOption(
                              manager,
                              ConnectionMode.wifi,
                              'Wi-Fi',
                              'Wireless connection',
                            ),
                            if (manager.mode == ConnectionMode.wifi) ...[
                              const SizedBox(height: 16),
                              _buildIpInput(manager),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Consumer<ConnectionManager>(
                          builder: (context, manager, _) => ElevatedButton(
                            onPressed: manager.state == ConnectionStatus.connecting
                                ? null
                                : () => _handleConnect(context, manager),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              manager.state == ConnectionStatus.connecting
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
                      const SizedBox(height: 12),
                      Consumer<ConnectionManager>(
                        builder: (context, manager, _) => Text(
                          _getStatusText(manager),
                          style: TextStyle(
                            color: manager.state == ConnectionStatus.error
                                ? Colors.red
                                : Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white54),
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
          },
        ),
      ),
    );
  }

  Widget _buildModeOption(ConnectionManager manager, ConnectionMode mode, String title, String subtitle) {
    final isSelected = manager.mode == mode;
    return GestureDetector(
      onTap: () => manager.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF1E293B),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildIpInput(ConnectionManager manager) {
    return TextField(
      controller: _ipController,
      decoration: InputDecoration(
        hintText: 'Enter PC IP address',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.router, color: Colors.white54),
      ),
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) => manager.setIpAddress(value),
    );
  }

  void _handleConnect(BuildContext context, ConnectionManager manager) async {
    if (manager.mode == ConnectionMode.wifi && manager.ipAddress.isEmpty) {
      _ipController.text = manager.ipAddress;
    }
    await manager.connect();
    if (manager.state == ConnectionStatus.connected && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControllerScreen()),
      );
    }
  }

  String _getStatusText(ConnectionManager manager) {
    switch (manager.state) {
      case ConnectionStatus.disconnected:
        return 'Not connected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.error:
        return 'Connection failed';
    }
  }
}