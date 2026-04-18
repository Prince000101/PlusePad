import 'package:flutter/material.dart';
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

class _ControllerScreenState extends State<ControllerScreen> {
  final Map<String, int> _buttons = {
    'A': 0, 'B': 0, 'X': 0, 'Y': 0,
    'L1': 0, 'R1': 0, 'L2': 0, 'R2': 0,
  };
  final Map<String, double> _axes = {'LX': 0, 'LY': 0, 'RX': 0, 'RY': 0};

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
    _sendInput();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<ConnectionManager>().disconnect();
            Navigator.pop(context);
          },
        ),
        title: Consumer<ConnectionManager>(
          builder: (context, manager, _) => Row(
            children: [
              Icon(
                manager.mode == ConnectionMode.usb ? Icons.usb : Icons.wifi,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                manager.mode == ConnectionMode.usb ? 'USB Connected' : 'Wi-Fi Connected',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          Consumer<ConnectionManager>(
            builder: (context, manager, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${manager.latency}ms',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: AnalogStick(
                  onChanged: (x, y) {
                    _onAxisChanged('LX', x);
                    _onAxisChanged('LY', y);
                  },
                ),
              ),
              Expanded(
                flex: 1,
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
          ),
        ),
      ),
    );
  }
}