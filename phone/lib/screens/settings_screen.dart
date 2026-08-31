import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/packet.dart';
import '../services/connection_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Background(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Settings'),
        ),
        body: Consumer<ConnectionManager>(
        builder: (context, manager, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Connection', [
              _infoTile('Mode', manager.mode.name.toUpperCase()),
              _infoTile('IP Address',
                  manager.ipAddress.isEmpty ? 'Auto / Not set' : manager.ipAddress),
              _infoTile('Latency',
                  manager.state == ConnectionStatus.disconnected
                      ? '--'
                      : '${manager.latency} ms'),
            ]),
            const SizedBox(height: 24),
            _section('Controller', [
              _sliderTile('Dead Zone',
                  manager.deadZone, 0.0, 0.5, (v) {
                setState(() => manager.deadZone = v.abs());
              }),
              _sliderTile('Sensitivity',
                  manager.sensitivity, 0.5, 2.0, (v) {
                setState(() => manager.sensitivity = v);
              }),
            ]),
            const SizedBox(height: 24),
            _section('Connection Guide', [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'USB:  run  adb reverse tcp:5005 tcp:5005  on the PC once.\n\n'
                  'Wi-Fi: press the radar button to auto-find your PC, or type '
                  'its IP address. Both must be on the same network.\n\n'
                  'On the PC, start the daemon with sudo.',
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                ),
              ),
            ]),
          ],
        ),
      ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentB,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.glass(radius: 16, blur: 14),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value, style: const TextStyle(color: Colors.white54)),
    );
  }

  Widget _sliderTile(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return ListTile(
      title: Text(label),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        activeColor: AppTheme.accentA,
      ),
    );
  }
}
