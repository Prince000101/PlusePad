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
  late AnimationController _pulseController;
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    // Wi-Fi is the default measure path; you can still type a PC IP below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final m = context.read<ConnectionManager>();
        m.setMode(ConnectionMode.wifi);
        _ipController.text = m.ipAddress;
      }
    });
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
                        const SizedBox(height: 28),
                        _buildConnectionOptions(),
                        const SizedBox(height: 22),
                        _buildConnectButton(),
                        const SizedBox(height: 14),
                        _buildStatus(),
                        const SizedBox(height: 20),
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                border: Border.all(
                  color: Color.lerp(AppTheme.hairline, AppTheme.accent, t)!,
                  width: 1.6,
                ),
              ),
              child: const Icon(Icons.gamepad, size: 56, color: AppTheme.accent),
            );
          },
        ),
        const SizedBox(height: 14),
        const Text('PulsePad', style: AppTheme.display),
        const SizedBox(height: 4),
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
          Row(
            children: [
              const Text('CONNECTION MODE', style: AppTheme.label),
              const Spacer(),
              Text(
                manager.mode == ConnectionMode.usb ? 'USB' : 'Wi-Fi',
                style: AppTheme.caption.copyWith(color: AppTheme.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildQrCard(manager),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  icon: Icons.wifi,
                  title: 'Wi-Fi',
                  subtitle: 'Auto • recommended',
                  isSelected: manager.mode == ConnectionMode.wifi,
                  onTap: () => manager.setMode(ConnectionMode.wifi),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeCard(
                  icon: Icons.usb,
                  title: 'USB',
                  subtitle: 'Cable • adb reverse',
                  isSelected: manager.mode == ConnectionMode.usb,
                  onTap: () => manager.setMode(ConnectionMode.usb),
                ),
              ),
            ],
          ),
          if (manager.mode == ConnectionMode.wifi) ...[
            const SizedBox(height: 12),
            _buildIpInput(manager),
          ],
        ],
      ),
    );
  }

  Widget _buildIpInput(ConnectionManager manager) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ipController,
            decoration: InputDecoration(
              hintText: 'PC IP  e.g. 192.168.1.100',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 14),
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
          icon: Icons.refresh,
          width: 52,
          height: 52,
          round: true,
          highlight: true,
          onTap: () => context.read<ConnectionManager>().discover(),
        ),
      ],
    );
  }

  Widget _buildQrCard(ConnectionManager manager) {
    return GestureDetector(
      onTap: () => _scanAndConnect(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.cardActive(radius: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentAt(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent, width: 1),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  color: AppTheme.accent, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SCAN PC QR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    manager.ipAddress.isEmpty
                        ? 'Wi-Fi auto-connect • no typing'
                        : 'Loaded ${manager.ipAddress}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
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
        padding: const EdgeInsets.all(12),
        decoration: isSelected ? AppTheme.cardActive() : AppTheme.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: isSelected ? AppTheme.accent : AppTheme.textSecondary),
                const Spacer(),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : AppTheme.hairline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 10, color: Color(0xFF081120))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                )),
            const SizedBox(height: 2),
            Text(subtitle, style: AppTheme.caption),
          ],
        ),
      ),
    );
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
        IconButton(
          icon: const Icon(Icons.settings, color: AppTheme.textMuted),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.gamepad, color: AppTheme.accent),
          tooltip: "Open controller (skip connect)",
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ControllerScreen()),
            );
          },
        ),
      ],
    );
  }

  void _handleConnect(BuildContext context, ConnectionManager manager) async {
    await _doConnect(context, manager);
  }

  /// Scan the PC QR and connect immediately on success.
  Future<void> _scanAndConnect(BuildContext context) async {
    final ok = await _openQrScanner(context);
    if (!ok || !context.mounted) return;
    await _doConnect(context, context.read<ConnectionManager>());
  }

  Future<bool> _openQrScanner(BuildContext context) async {
    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    ) ??
        false;
  }

  Future<void> _doConnect(BuildContext context, ConnectionManager manager) async {
    await manager.connect();
    if (manager.state == ConnectionStatus.connected && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControllerScreen()),
      );
    }
  }
}