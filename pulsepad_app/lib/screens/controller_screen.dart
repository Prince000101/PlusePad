import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../models/packet.dart';
import '../widgets/analog_stick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/shoulder_buttons.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> with SingleTickerProviderStateMixin {
  final Map<String, int> _buttons = {
    'A': 0, 'B': 0, 'X': 0, 'Y': 0,
    'L1': 0, 'R1': 0, 'L2': 0, 'R2': 0,
  };
  final Map<String, double> _axes = {'LX': 0, 'LY': 0, 'RX': 0, 'RY': 0};
  late AnimationController _pulseController;
  bool _isLandscape = false;
  bool _mouseControl = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _sendInput() {
    final packet = InputPacket(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      buttons: Map.from(_buttons),
      axes: Map.from(_axes),
    );
    context.read<ConnectionManager>().sendInput(packet);
  }

  void _onButtonPressed(String button) {
    setState(() => _buttons[button] = 1);
    _sendInput();
  }

  void _onButtonReleased(String button) {
    setState(() => _buttons[button] = 0);
    _sendInput();
  }

  void _onAxisChanged(String axis, double value) {
    setState(() => _axes[axis] = value);
    if (_mouseControl && (axis == 'LX' || axis == 'LY')) {
      if (value.abs() > 0.1) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
      }
    }
    _sendInput();
  }

  void _toggleLandscape() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: _buildGamepadLayout(),
        ),
        _buildControlBar(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildLeftControls()),
        Expanded(flex: 3, child: _buildRightControls()),
      ],
    );
  }

  Widget _buildLeftControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnalogStick(
            size: 140,
            onChanged: (x, y) {
              _onAxisChanged('LX', x);
              _onAxisChanged('LY', y);
            },
          ),
          const SizedBox(height: 24),
          ShoulderButtons(
            buttons: _buttons,
            onPressed: _onButtonPressed,
            onReleased: _onButtonReleased,
            horizontal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRightControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ActionButtons(
                buttons: _buttons,
                onPressed: _onButtonPressed,
                onReleased: _onButtonReleased,
              ),
              AnalogStick(
                size: 120,
                onChanged: (x, y) {
                  _onAxisChanged('RX', x);
                  _onAxisChanged('RY', y);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGamepadLayout() {
    return Column(
      children: [
        AnalogStick(
          onChanged: (x, y) {
            _onAxisChanged('LX', x);
            _onAxisChanged('LY', y);
          },
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ActionButtons(
                buttons: _buttons,
                onPressed: _onButtonPressed,
                onReleased: _onButtonReleased,
              ),
              const Icon(Icons.gamepad, size: 80, color: Colors.white12),
            ],
          ),
        ),
        ShoulderButtons(
          buttons: _buttons,
          onPressed: _onButtonPressed,
          onReleased: _onButtonReleased,
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
            onPressed: () {
              context.read<ConnectionManager>().disconnect();
              Navigator.pop(context);
            },
          ),
          Consumer<ConnectionManager>(
            builder: (context, manager, _) => Row(
              children: [
                Icon(
                  manager.mode == ConnectionMode.usb ? Icons.usb : Icons.wifi,
                  size: 14,
                  color: Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  manager.mode == ConnectionMode.usb ? 'USB' : 'Wi-Fi',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Spacer(),
          Consumer<ConnectionManager>(
            builder: (context, manager, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${manager.latency}ms',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.screen_rotation,
            label: 'Landscape',
            onTap: _toggleLandscape,
          ),
          _buildControlButton(
            icon: _mouseControl ? Icons.mouse : Icons.mouse_outlined,
            label: 'Mouse',
            isActive: _mouseControl,
            onTap: () => setState(() => _mouseControl = !_mouseControl),
          ),
          _buildControlButton(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: const Color(0xFF6366F1), width: 1) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? const Color(0xFF6366F1) : Colors.white54),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF6366F1) : Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}