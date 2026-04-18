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

class _ControllerScreenState extends State<ControllerScreen> with TickerProviderStateMixin {
  final Map<String, int> _buttons = {
    'A': 0, 'B': 0, 'X': 0, 'Y': 0,
    'L1': 0, 'R1': 0, 'L2': 0, 'R2': 0,
    'START': 0, 'SELECT': 0,
  };
  final Map<String, double> _axes = {'LX': 0, 'LY': 0, 'RX': 0, 'RY': 0};
  ControllerLayout _currentLayout = ControllerLayout.gamepad;
  bool _isLandscape = false;
  bool _mouseControl = false;
  bool _dpadMode = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _sendGamepadInput() {
    final packet = GamepadPacket(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      buttons: Map.from(_buttons),
      axes: Map.from(_axes),
    );
    context.read<ConnectionManager>().sendGamepad(packet);
  }

  void _sendMouseInput(double dx, double dy, Map<String, int> buttons) {
    final packet = MousePacket(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      dx: dx,
      dy: dy,
      buttons: buttons,
    );
    context.read<ConnectionManager>().sendMouse(packet);
  }

  void _sendKeyboardInput(String key, int state) {
    final packet = KeyboardPacket(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      key: key,
      state: state,
    );
    context.read<ConnectionManager>().sendKeyboard(packet);
  }

  void _onButtonPressed(String button) {
    setState(() => _buttons[button] = 1);
    _sendGamepadInput();
  }

  void _onButtonReleased(String button) {
    setState(() => _buttons[button] = 0);
    _sendGamepadInput();
  }

  void _onAxisChanged(String axis, double value) {
    setState(() => _axes[axis] = value);
    _sendGamepadInput();
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
      body: SafeArea(
        child: _isLandscape 
          ? _buildLandscapeLayout() 
          : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _buildCurrentLayout(),
        ),
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
          width: 200,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              AnalogStick(
                size: 120,
                onChanged: (x, y) {
                  _onAxisChanged('LX', x);
                  _onAxisChanged('LY', y);
                },
              ),
              const Spacer(),
              ShoulderButtons(
                buttons: _buttons,
                onPressed: _onButtonPressed,
                onReleased: _onButtonReleased,
                horizontal: true,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
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
                      size: 100,
                      onChanged: (x, y) {
                        _onAxisChanged('RX', x);
                        _onAxisChanged('RY', y);
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
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
              color: const Color(0xFF22C55E).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Consumer<ConnectionManager>(
              builder: (context, manager, _) => Row(
                children: [
                  Icon(
                    manager.mode == ConnectionMode.usb ? Icons.usb : Icons.wifi,
                    size: 14,
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    manager.mode == ConnectionMode.usb ? 'USB' : 'Wi-Fi',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Consumer<ConnectionManager>(
            builder: (context, manager, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getLatencyColor(manager.latency).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${manager.latency}ms',
                style: TextStyle(
                  fontSize: 12,
                  color: _getLatencyColor(manager.latency),
                  fontWeight: FontWeight.bold,
                ),
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
          AnalogStick(
            size: 180,
            onChanged: (x, y) {
              _onAxisChanged('LX', x);
              _onAxisChanged('LY', y);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ActionButtons(
                  buttons: _buttons,
                  onPressed: _onButtonPressed,
                  onReleased: _onButtonReleased,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCenterButton('SELECT', 'SELECT'),
                    const SizedBox(height: 8),
                    _buildCenterButton('START', 'START'),
                  ],
                ),
              ],
            ),
          ),
          ShoulderButtons(
            buttons: _buttons,
            onPressed: _onButtonPressed,
            onReleased: _onButtonReleased,
          ),
        ],
      ),
    );
  }

  Widget _buildPSPLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // PSP D-Pad (simulated with a small stick or custom buttons)
                AnalogStick(
                  size: 120,
                  onChanged: (x, y) {
                    _onAxisChanged('LX', x);
                    _onAxisChanged('LY', y);
                  },
                ),
                ActionButtons(
                  buttons: _buttons,
                  onPressed: _onButtonPressed,
                  onReleased: _onButtonReleased,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnalogStick(
            size: 140,
            onChanged: (x, y) {
              _onAxisChanged('RX', x);
              _onAxisChanged('RY', y);
            },
          ),
          const SizedBox(height: 20),
          ShoulderButtons(
            buttons: _buttons,
            onPressed: _onButtonPressed,
            onReleased: _onButtonReleased,
          ),
        ],
      ),
    );
  }

  Widget _buildPS5Layout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // PS5 D-pad
                AnalogStick(
                  size: 100,
                  onChanged: (x, y) {
                    _onAxisChanged('LX', x);
                    _onAxisChanged('LY', y);
                  },
                ),
                // PS5 Face buttons
                ActionButtons(
                  buttons: _buttons,
                  onPressed: _onButtonPressed,
                  onReleased: _onButtonReleased,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AnalogStick(
                size: 120,
                onChanged: (x, y) {
                  _onAxisChanged('LX', x);
                  _onAxisChanged('LY', y);
                },
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
          const SizedBox(height: 20),
          ShoulderButtons(
            buttons: _buttons,
            onPressed: _onButtonPressed,
            onReleased: _onButtonReleased,
          ),
        ],
      ),
    );
  }

  Widget _buildMouseLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                _sendMouseInput(details.delta.dx / 100, details.delta.dy / 100, {
                  'LEFT': 0,
                  'RIGHT': 0,
                  'MIDDLE': 0,
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Center(
                  child: Text(
                    'Touchpad Area',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMouseButton('LEFT'),
              _buildMouseButton('MIDDLE'),
              _buildMouseButton('RIGHT'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMouseButton(String label) {
    return GestureDetector(
      onTapDown: (_) => _sendMouseInput(0, 0, {label: 1}),
      onTapUp: (_) => _sendMouseInput(0, 0, {label: 0}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
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
        children: keys.map((key) => _buildKeyboardKey(key)).toList(),
      ),
    );
  }

  Widget _buildKeyboardKey(String key) {
    return GestureDetector(
      onTapDown: (_) => _sendKeyboardInput(key, 1),
      onTapUp: (_) => _sendKeyboardInput(key, 0),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Text(
            key,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(String label, String display) {
    final isPressed = _buttons[label] == 1;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(label),
      onTapUp: (_) => _onButtonReleased(label),
      onTapCancel: () => _onButtonReleased(label),
      child: Container(
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFF334155),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            display,
            style: TextStyle(
              fontSize: 10,
              color: isPressed ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlChip(
              icon: Icons.screen_rotation,
              label: 'Landscape',
              isActive: _isLandscape,
              onTap: _toggleLandscape,
            ),
            _buildLayoutChip(ControllerLayout.gamepad, 'Gamepad', Icons.gamepad),
            _buildLayoutChip(ControllerLayout.psp, 'PSP', Icons.videogame_asset),
            _buildLayoutChip(ControllerLayout.ps5, 'PS5', Icons.sports_esports),
            _buildLayoutChip(ControllerLayout.mouse, 'Mouse', Icons.mouse),
            _buildLayoutChip(ControllerLayout.keyboard, 'Keyboard', Icons.keyboard),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutChip(ControllerLayout layout, String label, IconData icon) {
    final isActive = _currentLayout == layout;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _buildControlChip(
        icon: icon,
        label: label,
        isActive: isActive,
        onTap: () => setState(() => _currentLayout = layout),
      ),
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
          color: isActive ? const Color(0xFF6366F1).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFF6366F1) : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? const Color(0xFF6366F1) : Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
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