import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../theme/app_theme.dart';
import 'controller_screen.dart';
import 'settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../models/packet.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  bool _scanning = false;
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
      body: Background(
        child: SafeArea(
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
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentB.withOpacity(0.25),
                    AppTheme.accentA.withOpacity(0.08),
                  ],
                ),
                border: Border.all(
                    color: AppTheme.accentB.withOpacity(_pulseAnimation.value),
                    width: 2),
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
                color: AppTheme.accentB,
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
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentA.withOpacity(0.30),
                    AppTheme.accentA.withOpacity(0.12),
                  ],
                ),
                border: Border.all(color: AppTheme.accentB, width: 1.5),
                boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.35),
              )
            : AppTheme.glass(radius: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentA.withOpacity(0.30)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected ? AppTheme.accentB : AppTheme.hairline,
                    width: 1),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.accentB : Colors.white54,
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
                color: isSelected ? AppTheme.accentA : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.accentB : Colors.white30,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? AppTheme.glow(AppTheme.accentA, opacity: 0.6, blur: 8)
                    : null,
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
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      hintText: '192.168.1.100',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.accentA, width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.router, color: Colors.white54),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) =>
                        context.read<ConnectionManager>().setIpAddress(value),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.4),
                  ),
                  child: IconButton(
                    tooltip: 'Find PC automatically',
                    onPressed: _scanning ? null : () => _scanForPc(context),
                    icon: _scanning
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.radar, color: Colors.white),
                  ),
                ),
              ],
            ),
            if (manager.discovered.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.glass(radius: 14, blur: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FOUND',
                        style: TextStyle(
                            fontSize: 11, letterSpacing: 1,
                            color: Colors.white.withOpacity(0.4))),
                    const SizedBox(height: 6),
                    ...manager.discovered.map((s) => InkWell(
                          onTap: () {
                            _ipController.text = s.host;
                            context.read<ConnectionManager>().setIpAddress(s.host);
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.desktop_mac,
                                    color: Color(0xFF22C55E), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${s.name}  •  ${s.host}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const Icon(Icons.touch_app,
                                    size: 16, color: Colors.white30),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _scanForPc(BuildContext context) async {
    setState(() => _scanning = true);
    try {
      await context.read<ConnectionManager>().discover();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan failed: $e')));
      }
    }
    if (mounted) setState(() => _scanning = false);
  }

  Widget _buildConnectButton() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) {
        final isConnecting = manager.state == ConnectionStatus.connecting;
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isConnecting
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x668F98F9), Color(0x666366F1)])
                  : AppTheme.accentGradient,
              boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.5),
            ),
            child: ElevatedButton(
              onPressed: isConnecting ? null : () => _handleConnect(context, manager),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
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
        TextButton.icon(
          onPressed: _openQrScanner,
          icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF22C55E)),
          label: const Text(
            'Scan QR',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
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

  Future<void> _openQrScanner() async {
    final manager = context.read<ConnectionManager>();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    _ipController.text = manager.ipAddress;
    setState(() {});
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