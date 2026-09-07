import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_info.dart';
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
          title: const Text('Settings',
              style: TextStyle(color: AppTheme.textPrimary)),
        ),
        body: Consumer<ConnectionManager>(
          builder: (context, manager, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('CONNECTION', [
                _infoTile('Mode', manager.mode.name.toUpperCase()),
                _infoTile(
                    'IP Address',
                    manager.ipAddress.isEmpty
                        ? 'Auto / Not set'
                        : manager.ipAddress),
                _infoTile(
                    'Latency',
                    manager.state == ConnectionStatus.disconnected
                        ? '--'
                        : '${manager.latency} ms'),
                _switchTile('Auto-reconnect', manager.autoReconnect, (v) {
                  setState(() => manager.autoReconnect = v);
                }),
              ]),
              const SizedBox(height: 20),
              _section('CONTROLLER', [
                _sliderTile(
                  'Dead Zone',
                  '${(manager.deadZone * 100).round()}%',
                  manager.deadZone,
                  0.0,
                  0.5,
                  (v) => setState(() => manager.deadZone = v.abs()),
                ),
                _dividerTile(),
                _sliderTile(
                  'Sensitivity',
                  '${manager.sensitivity.toStringAsFixed(2)}×',
                  manager.sensitivity,
                  0.5,
                  2.0,
                  (v) => setState(() => manager.sensitivity = v),
                ),
                _dividerTile(),
                _switchTile('Button Feedback', manager.buttonFeedback, (v) {
                  setState(() => manager.buttonFeedback = v);
                }),
              ]),
              const SizedBox(height: 20),
              _section('CONNECTION GUIDE', [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'USB: run  adb reverse tcp:5005 tcp:5005  on the PC once.\n\n'
                    'Wi-Fi: press the radar button to auto-find your PC, or '
                    'type its IP. Both must be on the same network.\n\n'
                    'Start the daemon on the PC with sudo.',
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _section('ABOUT', [
                _infoTile('Version', kAppVersion),
                _infoTile('Protocol', 'PulsePad • v1'),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: AppTheme.label),
        ),
        Container(
          decoration: AppTheme.card(),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _dividerTile() => const Divider(
      height: 1, thickness: 1, color: AppTheme.hairline, indent: 16, endIndent: 16);

  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(label, style: AppTheme.bodySecondary),
      trailing: Text(value, style: AppTheme.caption),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(label, style: AppTheme.bodySecondary),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accent,
        activeTrackColor: AppTheme.accentAt(0.4),
      ),
    );
  }

  Widget _sliderTile(String label, String readout, double value, double min,
      double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTheme.bodySecondary),
              const Spacer(),
              Text(readout, style: AppTheme.label.copyWith(color: AppTheme.accent)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.surfaceAlt,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accentAt(0.2),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}