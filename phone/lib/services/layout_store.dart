import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/control_slot.dart';

/// Loads and persists the user's custom controller layouts locally on the
/// phone (local-only, no PC sync).
///
/// Storage is a single v2 envelope: `{'active': <layout id>, 'layouts': [...]}`.
/// The legacy single-layout v1 blob is migrated into v2 on first load and its
/// plain action strings (`'A'`, `'W'`, `'LMB'`) are normalised to the
/// namespaced wire format (`pad:A`, `key:W`, `mouse:LMB`).
class LayoutStore extends ChangeNotifier {
  static const _key = 'pulsepad.custom_layouts.v2';
  static const _v1Key = 'pulsepad.custom_layout.v1';

  final List<CustomLayout> _layouts = [];
  String? _activeId;

  /// All saved layouts, newest last.
  List<CustomLayout> get layouts => List.unmodifiable(_layouts);

  /// The currently active custom layout, or null when none exists.
  CustomLayout? get active {
    if (_activeId == null) return null;
    for (final l in _layouts) {
      if (l.id == _activeId) return l;
    }
    return _layouts.isEmpty ? null : _layouts.first;
  }

  bool get hasCustom => active != null;

  /// Load saved layouts from disk (v2, migrating v1). Safe to call at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      if (_decodeEnvelope(raw)) {
        notifyListeners();
        return;
      }
    }
    // Legacy single-layout v1 blob -> migrate.
    final v1 = prefs.getString(_v1Key);
    if (v1 != null) {
      final layout = CustomLayout.decode(v1);
      if (layout != null) {
        _layouts
          ..clear()
          ..add(_normalized(layout));
        _activeId = layout.id;
        await _persistWith(prefs);
        await prefs.remove(_v1Key);
      }
    }
    notifyListeners();
  }

  /// Upsert (or insert) [layout], make it the active one, persist.
  Future<bool> save(CustomLayout layout) async {
    final i = _layouts.indexWhere((l) => l.id == layout.id);
    if (i >= 0) {
      _layouts[i] = layout;
    } else {
      _layouts.add(layout);
    }
    _activeId = layout.id;
    notifyListeners();
    return _persist();
  }

  Future<bool> rename(String id, String name) async {
    final l = _byId(id);
    if (l == null) return false;
    l.name = name.trim().isEmpty ? 'My Custom' : name.trim();
    notifyListeners();
    return _persist();
  }

  /// Duplicate [id]'s layout under a fresh id (and fresh slot ids). Does not
  /// activate the copy.
  Future<bool> duplicate(String id) async {
    final src = _byId(id);
    if (src == null) return false;
    final copy = CustomLayout(
      id: CustomLayout.newId(),
      name: '${src.name} Copy',
      slots: src.slots.map((s) => ControlSlot.clone(s)).toList(),
    );
    _layouts.add(copy);
    notifyListeners();
    return _persist();
  }

  Future<bool> remove(String id) async {
    final i = _layouts.indexWhere((l) => l.id == id);
    if (i < 0) return false;
    _layouts.removeAt(i);
    if (_activeId == id) {
      _activeId = _layouts.isEmpty ? null : _layouts[0].id;
    }
    notifyListeners();
    return _persist();
  }

  Future<bool> activate(String id) async {
    if (_byId(id) == null) return false;
    _activeId = id;
    notifyListeners();
    return _persist();
  }

  Future<void> clear() async {
    _layouts.clear();
    _activeId = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_v1Key);
    } catch (_) {}
  }

  // ------------------------------- internals ----------------------------- //

  CustomLayout? _byId(String id) {
    for (final l in _layouts) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Normalise every legacy plain action on button slots to the namespaced
  /// wire form.
  CustomLayout _normalized(CustomLayout layout) {
    for (final s in layout.slots) {
      if (s.kind == 'button') s.action = SlotAction.classify(s.action).wire;
    }
    return layout;
  }

  bool _decodeEnvelope(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final layouts = (m['layouts'] as List<dynamic>? ?? [])
          .map((e) => CustomLayout.fromJson(e as Map<String, dynamic>))
          .toList();
      _layouts
        ..clear()
        ..addAll(layouts.map(_normalized));
      _activeId = m['active'] as String?;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _persist() => _persistWith(null);

  Future<bool> _persistWith(SharedPreferences? prefs) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final envelope = jsonEncode({
        'active': _activeId,
        'layouts': _layouts.map((l) => l.toJson()).toList(),
      });
      return await p.setString(_key, envelope);
    } catch (_) {
      return false;
    }
  }
}