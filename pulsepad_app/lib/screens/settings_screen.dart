import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: Consumer<ConnectionManager>(
        builder: (context, manager, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              'Connection',
              [
                _buildInfoTile('Mode', manager.mode.name.toUpperCase()),
                _buildInfoTile('IP Address', manager.ipAddress.isEmpty ? 'Not set' : manager.ipAddress),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Controller',
              [
                _buildSliderTile('Dead Zone', 0.1, 0.0, 0.5, (v) {}),
                _buildSwitchTile('Vibration', true, (v) {}),
                _buildSliderTile('Sensitivity', 1.0, 0.5, 2.0, (v) {}),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Advanced',
              [
                _buildDropdownTile('Packet Rate', '120 Hz', ['60 Hz', '120 Hz', '240 Hz'], (v) {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value, style: const TextStyle(color: Colors.white54)),
    );
  }

  Widget _buildSliderTile(String label, double value, double min, double max, Function(double) onChanged) {
    return ListTile(
      title: Text(label),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        activeColor: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildSwitchTile(String label, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildDropdownTile(String label, String value, List<String> options, Function(String) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1E293B),
        underline: const SizedBox(),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}