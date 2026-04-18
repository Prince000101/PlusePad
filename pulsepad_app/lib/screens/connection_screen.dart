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

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 40, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 40),
                      _buildConnectionOptions(),
                      const SizedBox(height: 32),
                      _buildConnectButton(),
                      const SizedBox(height: 16),
                      _buildStatus(),
                      const Spacer(),
                      _buildFooter(),
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

  Widget _buildLogo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3 * _pulseAnimation.value),
                    blurRadius: 30 * _pulseAnimation.value,
                    spreadRadius: 5 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: const Icon(
                Icons.gamepad,
                size: 70,
                color: Color(0xFF6366F1),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'PulsePad',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Turn your phone into a game controller',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionOptions() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONNECTION MODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            icon: Icons.usb,
            title: 'USB',
            subtitle: 'Low latency • Recommended',
            isSelected: manager.mode == ConnectionMode.usb,
            onTap: () => manager.setMode(ConnectionMode.usb),
          ),
          const SizedBox(height: 10),
          _buildModeCard(
            icon: Icons.wifi,
            title: 'Wi-Fi',
            subtitle: 'Wireless connection',
            isSelected: manager.mode == ConnectionMode.wifi,
            onTap: () => manager.setMode(ConnectionMode.wifi),
          ),
          if (manager.mode == ConnectionMode.wifi) ...[
            const SizedBox(height: 16),
            _buildIpInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF6366F1) : Colors.white54,
                size: 24,
              ),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.white30,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpInput() {
    return TextField(
      controller: _ipController,
      decoration: InputDecoration(
        hintText: '192.168.1.100',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.router, color: Colors.white54),
        suffixIcon: const Icon(Icons.edit, color: Colors.white30, size: 18),
      ),
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) => context.read<ConnectionManager>().setIpAddress(value),
    );
  }

  Widget _buildConnectButton() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) {
        final isConnecting = manager.state == ConnectionStatus.connecting;
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isConnecting ? null : () => _handleConnect(context, manager),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              disabledBackgroundColor: const Color(0xFF4F46E5).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isConnecting) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(Icons.power, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  isConnecting ? 'CONNECTING...' : 'CONNECT',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatus() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) {
        Color statusColor;
        String statusText;
        IconData statusIcon;
        
        switch (manager.state) {
          case ConnectionStatus.disconnected:
            statusColor = Colors.white.withOpacity(0.4);
            statusText = 'Not connected';
            statusIcon = Icons.circle_outlined;
            break;
          case ConnectionStatus.connecting:
            statusColor = const Color(0xFFF59E0B);
            statusText = 'Connecting...';
            statusIcon = Icons.sync;
            break;
          case ConnectionStatus.connected:
            statusColor = const Color(0xFF22C55E);
            statusText = 'Connected • Ready to play';
            statusIcon = Icons.check_circle;
            break;
          case ConnectionStatus.error:
            statusColor = const Color(0xFFEF4444);
            statusText = 'Connection failed';
            statusIcon = Icons.error;
            break;
        }
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(fontSize: 13, color: statusColor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white30),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  void _handleConnect(BuildContext context, ConnectionManager manager) async {
    await manager.connect();
    if (manager.state == ConnectionStatus.connected && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControllerScreen()),
      );
    }
  }
}