import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/control_slot.dart';

/// Loads and persists the user's custom controller layout locally on the
/// phone (local-only, no PC sync).
class LayoutStore extends ChangeNotifier {
  static const _key = 'pulsepad.custom_layout.v1';

  CustomLayout? _layout;
  CustomLayout? get layout => _layout;

  bool get hasCustom => _layout != null && _layout!.slots.isNotEmpty;

  /// Load the saved layout from disk. Safe to call on app start.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    _layout = CustomLayout.decode(raw);
    notifyListeners();
  }

  /// Persist (and keep in memory) the given layout. Returns true on success.
  Future<bool> save(CustomLayout layout) async {
    _layout = layout;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key, layout.encode());
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    _layout = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
