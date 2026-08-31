import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../models/packet.dart';
import '../services/connection_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/analog_stick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/shoulder_buttons.dart';
import '../widgets/dpad.dart';
import 'settings_screen.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with TickerProviderStateMixin {
  ControllerLayout _currentLayout = ControllerLayout.gamepad;
  bool _isLandscape = false;
  bool _dpadMode = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionManager>().enableAutoReconnect();
    });
    _bindHaptic();
  }

  void _bindHaptic() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionManager>().onHaptic = (dur, intensity, motor) {
        Vibration.vibrate(duration: dur);
      };
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  ConnectionManager _cm() => context.read<ConnectionManager>();

  // ------------------------------- inputs ------------------------------ //
  void _setButton(String name, bool pressed) {
    final cm = _cm();
    if (cm.controller.setButton(name, pressed)) cm.pushState();
  }

  void _setAxis(String name, double v) {
    final cm = _cm();
    // Apply sensitivity to the analog value before scaling.
    v = (v * cm.sensitivity).clamp(-1.0, 1.0);
    if (cm.controller.setAxis(name, v)) cm.pushState();
  }

  void _toggleLandscape() {
    setState(() => _isLandscape = !_isLandscape);
    SystemChrome.setPreferredOrientations(_isLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Background(
        child: SafeArea(
          child: _isLandscape
              ? _buildLandscapeLayout()
              : _buildPortraitLayout(),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildCurrentLayout()),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildCurrentLayout() {
    switch (_currentLayout) {
      case ControllerLayout.psp:
        return _buildPSPLayout();
      case ControllerLayout.ps5:
        return _buildPS5Layout();
      case ControllerLayout.mouse:
        return _buildMouseLayout();
      case ControllerLayout.keyboard:
        return _buildKeyboardLayout();
      case ControllerLayout.gamepad:
      default:
        return _buildGamepadLayout();
    }
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Container(
          width: 210,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _dpadMode ? DPad(onChanged: _dpad, size: 120)
                        : AnalogStick(
                            size: 130,
                            onChanged: (x, y) {
                              _setAxis('LX', x);
                              _setAxis('LY', y);
                            }),
              const Spacer(),
              ShoulderButtons(
                onPressed: (b) => _setButton(b, true),
                onReleased: (b) => _setButton(b, false),
                horizontal: true,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ActionButtons(
                      onPressed: (b) => _setButton(b, true),
                      onReleased: (b) => _setButton(b, false),
                    ),
                    _buildVerticalCenterButtons(),
                    AnalogStick(
                      size: 110,
                      onChanged: (x, y) {
                        _setAxis('RX', x);
                        _setAxis('RY', y);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _dpad(String dir, bool pressed) => _setButton(dir, pressed);

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: const Border(bottom: BorderSide(color: AppTheme.hairline)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentA.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () {
              context.read<ConnectionManager>().disconnect();
              Navigator.pop(context);
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.4), width: 1),
            ),
            child: Consumer<ConnectionManager>(
              builder: (context, manager, _) => Row(
                children: [
                  Icon(manager.mode == ConnectionMode.usb
                      ? Icons.usb
                      : Icons.wifi,
                      size: 14, color: const Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Text(manager.mode == ConnectionMode.usb ? 'USB' : 'Wi-Fi',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const Spacer(),
          Consumer<ConnectionManager>(
            builder: (context, manager, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getLatencyColor(manager.latency).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _getLatencyColor(manager.latency).withOpacity(0.4),
                    width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.speed, size: 14,
                      color: _getLatencyColor(manager.latency)),
                  const SizedBox(width: 6),
                  Text('${manager.latency}ms',
                      style: TextStyle(
                          fontSize: 12,
                          color: _getLatencyColor(manager.latency),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamepadLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dpadMode
                  ? DPad(onChanged: _dpad)
                  : AnalogStick(
                      size: 160,
                      onChanged: (x, y) {
                        _setAxis('LX', x);
                        _setAxis('LY', y);
                      }),
              AnalogStick(
                size: 120,
                onChanged: (x, y) {
                  _setAxis('RX', x);
                  _setAxis('RY', y);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildVerticalCenterButtons(),
                ActionButtons(
                  onPressed: (b) => _setButton(b, true),
                  onReleased: (b) => _setButton(b, false),
                ),
              ],
            ),
          ),
          ShoulderButtons(
            onPressed: (b) => _setButton(b, true),
            onReleased: (b) => _setButton(b, false),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalCenterButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCenterButton('SELECT'),
        const SizedBox(height: 8),
        _buildCenterButton('START'),
        const SizedBox(height: 8),
        _buildCenterButton('L3'),
        const SizedBox(height: 8),
        _buildCenterButton('R3'),
      ],
    );
  }

  Widget _buildPSPLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DPad(onChanged: _dpad, size: 130),
                ActionButtons(
                  onPressed: (b) => _setButton(b, true),
                  onReleased: (b) => _setButton(b, false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildVerticalCenterButtonsRow(),
          const SizedBox(height: 16),
          AnalogStick(
            size: 130,
            onChanged: (x, y) {
              _setAxis('RX', x);
              _setAxis('RY', y);
            },
          ),
          const SizedBox(height: 12),
          ShoulderButtons(
            onPressed: (b) => _setButton(b, true),
            onReleased: (b) => _setButton(b, false),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalCenterButtonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCenterButton('SELECT'),
        _buildCenterButton('START'),
        _buildCenterButton('L3'),
        _buildCenterButton('R3'),
      ],
    );
  }

  Widget _buildPS5Layout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dpadMode
                    ? DPad(onChanged: _dpad, size: 120)
                    : AnalogStick(
                        size: 110,
                        onChanged: (x, y) {
                          _setAxis('LX', x);
                          _setAxis('LY', y);
                        }),
                ActionButtons(
                  onPressed: (b) => _setButton(b, true),
                  onReleased: (b) => _setButton(b, false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildVerticalCenterButtonsRow(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AnalogStick(
                size: 110,
                onChanged: (x, y) {
                  _setAxis('LX', x);
                  _setAxis('LY', y);
                },
              ),
              AnalogStick(
                size: 110,
                onChanged: (x, y) {
                  _setAxis('RX', x);
                  _setAxis('RY', y);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShoulderButtons(
            onPressed: (b) => _setButton(b, true),
            onReleased: (b) => _setButton(b, false),
          ),
        ],
      ),
    );
  }

  Widget _buildMouseLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                // Mouse is not yet in the binary protocol scope; keep touch
                // pad for future expansion but no-op for now.
              },
              child: Container(
                decoration: AppTheme.glass(radius: 24),
                child: const Center(
                  child: Text('Touchpad Area',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCenterButton('SELECT'),
              _buildCenterButton('START'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardLayout() {
    final keys = ['W', 'A', 'S', 'D', 'SPACE', 'SHIFT', 'CTRL', 'ENTER', 'ESC'];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: keys.map(_buildKeyboardKey).toList(),
      ),
    );
  }

  Widget _buildKeyboardKey(String key) {
    return GestureDetector(
      onTapDown: (_) => _setButton(key, true),
      onTapUp: (_) => _setButton(key, false),
      child: Container(
        width: 70, height: 70,
        decoration: AppTheme.glass(radius: 14),
        child: Center(
          child: Text(key,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCenterButton(String label) {
    return GestureDetector(
      onTapDown: (_) => _setButton(label, true),
      onTapUp: (_) => _setButton(label, false),
      onTapCancel: () => _setButton(label, false),
      child: Container(
        width: 62,
        height: 36,
        decoration: AppTheme.glass(radius: 18),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: const Border(top: BorderSide(color: AppTheme.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlChip(
                icon: Icons.screen_rotation, label: 'Landscape',
                isActive: _isLandscape, onTap: _toggleLandscape),
            _buildControlChip(
                icon: Icons.gamepad, label: 'Gamepad',
                isActive: _currentLayout == ControllerLayout.gamepad,
                onTap: () => setState(() => _currentLayout = ControllerLayout.gamepad)),
            _buildLayoutChip(ControllerLayout.psp, 'PSP', Icons.videogame_asset),
            _buildLayoutChip(ControllerLayout.ps5, 'PS5', Icons.sports_esports),
            _buildControlChip(
                icon: Icons.grid_on,
                label: _dpadMode ? 'Stick' : 'D-Pad',
                isActive: _dpadMode,
                onTap: () => setState(() => _dpadMode = !_dpadMode)),
            Builder(builder: (context) {
              return _buildControlChip(
                  icon: Icons.settings, label: 'Settings', isActive: false,
                  onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutChip(ControllerLayout layout, String label, IconData icon) {
    return _buildControlChip(
      icon: icon,
      label: label,
      isActive: _currentLayout == layout,
      onTap: () => setState(() => _currentLayout = layout),
    );
  }

  Widget _buildControlChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentA.withOpacity(0.22)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive ? AppTheme.accentB : AppTheme.hairline,
              width: 1.2),
          boxShadow: isActive ? AppTheme.glow(AppTheme.accentA, opacity: 0.45) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22,
                color: isActive ? AppTheme.accentB : Colors.white54),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isActive ? AppTheme.accentB : Colors.white54,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Color _getLatencyColor(int latency) {
    if (latency < 10) return const Color(0xFF22C55E);
    if (latency < 30) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
