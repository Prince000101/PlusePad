import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/gamepad_button.dart';
import 'controller_screen.dart';
import 'settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../models/packet.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  bool _scanning = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
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
      backgroundColor: AppTheme.bg,
      body: Background(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                    child: Column(
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 36),
                        _buildConnectionOptions(),
                        const SizedBox(height: 28),
                        _buildConnectButton(),
                        const SizedBox(height: 14),
                        _buildStatus(),
                        const SizedBox(height: 28),
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
          animation: _pulseController,
          builder: (context, child) {
            final t = _pulseController.value;
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                border: Border.all(
                  color: Color.lerp(AppTheme.hairline, AppTheme.accent, t)!,
                  width: 1.6,
                ),
              ),
              child: const Icon(Icons.gamepad, size: 68, color: AppTheme.accent),
            );
          },
        ),
        const SizedBox(height: 18),
        const Text('PulsePad', style: AppTheme.display),
        const SizedBox(height: 6),
        const Text('Turn your phone into a game controller',
            style: TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildConnectionOptions() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONNECTION MODE', style: AppTheme.label),
          const SizedBox(height: 10),
          _buildModeCard(
            icon: Icons.usb,
            title: 'USB',
            subtitle: 'Low latency • Recommended',
            isSelected: manager.mode == ConnectionMode.usb,
            onTap: () => manager.setMode(ConnectionMode.usb),
          ),
          const SizedBox(height: 8),
          _buildModeCard(
            icon: Icons.wifi,
            title: 'Wi-Fi',
            subtitle: 'Wireless connection',
            isSelected: manager.mode == ConnectionMode.wifi,
            onTap: () => manager.setMode(ConnectionMode.wifi),
          ),
          if (manager.mode == ConnectionMode.wifi) ...[
            const SizedBox(height: 14),
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: isSelected
            ? AppTheme.cardActive()
            : AppTheme.card(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentAt(0.16)
                    : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.hairline,
                    width: 1),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.caption),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.accent : AppTheme.hairline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Color(0xFF081120))
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
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                        borderSide:
                            const BorderSide(color: AppTheme.accent, width: 1.4),
                      ),
                      prefixIcon:
                          const Icon(Icons.router, color: AppTheme.textSecondary),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (value) =>
                        context.read<ConnectionManager>().setIpAddress(value),
                  ),
                ),
                const SizedBox(width: 10),
                GamepadButton(
                  label: '',
                  icon: _scanning ? null : Icons.radar,
                  width: 52,
                  height: 52,
                  round: true,
                  highlight: !_scanning,
                  onTap: _scanning ? null : () => _scanForPc(context),
                ),
              ],
            ),
            if (manager.discovered.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FOUND', style: AppTheme.label),
                    const SizedBox(height: 4),
                    ...manager.discovered.map((s) => InkWell(
                          onTap: () {
                            _ipController.text = s.host;
                            context
                                .read<ConnectionManager>()
                                .setIpAddress(s.host);
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.desktop_mac,
                                    color: AppTheme.green, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${s.name}  •  ${s.host}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
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
          child: GamepadButton(
            label: isConnecting ? 'CONNECTING...' : 'CONNECT',
            icon: isConnecting ? Icons.sync : Icons.power,
            width: double.infinity,
            height: 56,
            fontSize: 15,
            highlight: !isConnecting,
            onTap: isConnecting ? null : () => _handleConnect(context, manager),
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
            statusColor = AppTheme.textMuted;
            statusText = 'Not connected';
            statusIcon = Icons.circle_outlined;
            break;
          case ConnectionStatus.connecting:
            statusColor = AppTheme.amber;
            statusText = 'Connecting...';
            statusIcon = Icons.sync;
            break;
          case ConnectionStatus.connected:
            statusColor = AppTheme.green;
            statusText = 'Connected • Ready to play';
            statusIcon = Icons.check_circle;
            break;
          case ConnectionStatus.error:
            statusColor = AppTheme.red;
            statusText = 'Connection failed';
            statusIcon = Icons.error;
            break;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, size: 15, color: statusColor),
            const SizedBox(width: 7),
            Text(statusText, style: TextStyle(fontSize: 13, color: statusColor)),
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
          icon: const Icon(Icons.qr_code_scanner, color: AppTheme.green),
          label: const Text(
            'Scan QR',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: AppTheme.textMuted),
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