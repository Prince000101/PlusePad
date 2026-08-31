import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/control_slot.dart';
import '../services/layout_store.dart';
import '../theme/app_theme.dart';

/// A full visual editor for the user's custom controller layout.
///
/// Controls are positioned/resized by dragging them (or their resize handle)
/// on a landscape canvas. Tapping a control lets you rename it, reassign its
/// action, resize it precisely, or delete it. Saving persists the layout
/// locally via [LayoutStore]; the controller then renders it as the
/// `custom` layout.
class LayoutEditorScreen extends StatefulWidget {
  final CustomLayout layout;

  const LayoutEditorScreen({super.key, required this.layout});

  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  late final List<ControlSlot> _slots;
  String? _selectedId;
  bool _dragging = false;

  static const _grip = 22.0; // resize handle size
  static const _minPx = 44.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _slots = widget.layout.slots.map((s) => ControlSlot.copy(s)).toList();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  ControlSlot? get _selected =>
      _slots.where((s) => s.id == _selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Background(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                // ---- canvas ----
                Positioned.fill(
                  child: Stack(
                    children: _slots
                        .map((s) => _buildDraggable(s, w, h))
                        .toList(),
                  ),
                ),
                // ---- top chrome ----
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      _chromeIcon(Icons.arrow_back, 'Back',
                          () => Navigator.pop(context, _currentLayout())),
                      const Spacer(),
                      Text('LAYOUT EDITOR',
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.5,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _chromeIcon(Icons.restore, 'Reset', _resetToDefault),
                      const SizedBox(width: 8),
                      _chromeIcon(Icons.check, 'Save', _save),
                    ],
                  ),
                ),
                // ---- bottom toolbar ----
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildToolbar(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  CustomLayout _currentLayout() => CustomLayout(name: 'My Custom', slots: _slots);

  void _resetToDefault() {
    setState(() {
      _slots.clear();
      _slots.addAll(_defaultSlots());
      _selectedId = null;
    });
  }

  void _save() {
    context.read<LayoutStore>().save(_currentLayout());
    Navigator.pop(context, _currentLayout());
  }

  // ----------------------------- canvas item --------------------------- //
  Widget _buildDraggable(ControlSlot s, double w, double h) {
    final isSelected = _selectedId == s.id;
    final left = (s.x - s.w / 2) * w;
    final top = (s.y - s.h / 2) * h;
    final cw = s.w * w;
    final ch = s.h * h;

    return Positioned(
      left: left,
      top: top,
      width: cw,
      height: ch,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _selectedId = s.id;
          _dragging = false;
        }),
        onPanStart: (_) {
          setState(() {
            _selectedId = s.id;
            _dragging = true;
          });
          _startDrag = (s.x, s.y);
        },
        onPanUpdate: (d) => _move(s, d.delta, w, h),
        onPanEnd: (_) => setState(() => _dragging = false),
        onPanCancel: () => setState(() => _dragging = false),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _colorFor(s.kind).withOpacity(isSelected || _dragging ? 0.45 : 0.30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? AppTheme.accentB : AppTheme.hairline,
                    width: isSelected ? 2.5 : 1.2),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.kind == 'stick' ? Icons.gps_fixed
                      : s.kind == 'dpad' ? Icons.grid_on
                      : Icons.touch_app,
                      size: 20, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(s.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _resizeStart = (s.w, s.h),
                  onPanUpdate: (d) => _resize(s, d.delta, w, h),
                  child: Container(
                    width: _grip,
                    height: _grip,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentA,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow:
                          AppTheme.glow(AppTheme.accentA, opacity: 0.6),
                    ),
                    child: const Icon(Icons.arrow_outward,
                        size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Drag bookkeeping (normalised coords at drag start).
  (double, double)? _startDrag;
  (double, double)? _resizeStart;

  void _move(ControlSlot s, Offset delta, double w, double h) {
    final (sx, sy) = _startDrag ?? (s.x, s.y);
    var nx = sx + delta.dx / w;
    var ny = sy + delta.dy / h;
    nx = nx.clamp(s.w / 2, 1 - s.w / 2);
    ny = ny.clamp(s.h / 2, 1 - s.h / 2);
    setState(() {
      s.x = nx;
      s.y = ny;
      _startDrag = (nx, ny);
    });
  }

  void _resize(ControlSlot s, Offset delta, double w, double h) {
    final (sw, sh) = _resizeStart ?? (s.w, s.h);
    final minW = _minPx / w;
    final minH = _minPx / h;
    final nw = (sw + delta.dx / w).clamp(minW, 0.5);
    final nh = (sh + delta.dy / h).clamp(minH, 0.5);
    setState(() {
      s.w = nw;
      s.h = nh;
      _resizeStart = (nw, nh);
      _clampPosition(s);
    });
  }

  // ----------------------------- toolbar ------------------------------ //
  Widget _buildToolbar() {
    final sel = _selected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF151C2E).withOpacity(0.96),
            const Color(0xFF0B1120).withOpacity(0.98),
          ],
        ),
        border: const Border(top: BorderSide(color: AppTheme.hairline)),
      ),
      child: sel == null ? _buildAddRow() : _buildEditRow(sel),
    );
  }

  Widget _buildAddRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _toolButton(Icons.touch_app, 'Button', () => _add('button')),
        _toolButton(Icons.grid_on, 'D-Pad', () => _add('dpad')),
        _toolButton(Icons.gps_fixed, 'Stick', () => _add('stick')),
        const Spacer(),
        const Text('Tap a control to edit it',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildEditRow(ControlSlot s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _toolButton(Icons.label, 'Rename', () => _rename(s)),
            const SizedBox(width: 8),
            _toolButton(Icons.swap_horiz, 'Action', () => _chooseAction(s)),
            const SizedBox(width: 8),
            _toolButton(Icons.tune, 'Bigger', () => _resizeStep(s, 1.15)),
            const SizedBox(width: 8),
            _toolButton(Icons.tune, 'Smaller', () => _resizeStep(s, 0.87)),
            const Spacer(),
            _toolButton(Icons.delete, 'Delete', () => _delete(s), danger: true),
          ],
        ),
        const SizedBox(height: 8),
        Text('${s.kind.toUpperCase()}  •  ${s.action.isEmpty ? s.label : s.action}',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (danger ? AppTheme.red : AppTheme.accentA).withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (danger ? AppTheme.red : AppTheme.accentB)
                  .withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: danger ? AppTheme.red : AppTheme.accentB),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: danger ? AppTheme.red : Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _chromeIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ----------------------------- actions ------------------------------ //
  void _add(String kind) {
    final slot = ControlSlot(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      x: 0.5,
      y: 0.5,
      w: kind == 'stick' ? 0.16 : 0.12,
      h: kind == 'stick' ? 0.28 : 0.10,
      label: kind == 'stick' ? 'STICK' : kind == 'dpad' ? 'D-PAD' : 'BTN',
      action: '',
    );
    setState(() {
      _slots.add(slot);
      _selectedId = slot.id;
    });
  }

  void _rename(ControlSlot s) {
    final controller = TextEditingController(text: s.label);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2436),
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Label',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                setState(() => s.label = controller.text.trim().isEmpty
                    ? 'BTN'
                    : controller.text.trim().toUpperCase());
                Navigator.pop(ctx);
              },
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _chooseAction(ControlSlot s) {
    final actions = _availableActions();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B2436),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: actions
              .map((a) => ListTile(
                    title: Text(a,
                        style: const TextStyle(color: Colors.white)),
                    trailing: s.action == a
                        ? const Icon(Icons.check,
                            color: AppTheme.accentB)
                        : null,
                    onTap: () {
                      setState(() {
                        s.action = a;
                        if (s.kind == 'button' && a.isNotEmpty) {
                          // For buttons the label mirrors the action by default
                          // if the user hasn't customised it yet.
                          if (s.label == 'BTN' || s.label == '') s.label = a;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  List<String> _availableActions() {
    const buttons = [
      'A', 'B', 'X', 'Y', 'SELECT', 'START', 'L3', 'R3',
      'LB', 'RB', 'LT', 'RT',
      'W', 'A', 'S', 'D', 'SPACE', 'SHIFT', 'CTRL', 'ENTER', 'ESC',
      'LMB', 'RMB',
    ];
    final selected = _selected;
    if (selected != null && selected.kind != 'button') {
      // dpad / stick use fixed wire behaviour; allow choosing the axis set.
      return selected.kind == 'stick'
          ? const ['LX/LY', 'RX/RY']
          : const ['DPAD'];
    }
    return buttons.toSet().toList();
  }

  void _resizeStep(ControlSlot s, double factor) {
    setState(() {
      final nw = (s.w * factor).clamp(0.05, 0.5);
      final nh = (s.h * factor).clamp(0.05, 0.5);
      s.w = nw;
      s.h = nh;
      _clampPosition(s);
    });
  }

  void _delete(ControlSlot s) {
    setState(() {
      _slots.removeWhere((x) => x.id == s.id);
      _selectedId = null;
    });
  }

  void _clampPosition(ControlSlot s) {
    s.x = s.x.clamp(s.w / 2, 1 - s.w / 2);
    s.y = s.y.clamp(s.h / 2, 1 - s.h / 2);
  }

  Color _colorFor(String kind) {
    switch (kind) {
      case 'stick':
        return AppTheme.accentA;
      case 'dpad':
        return AppTheme.green;
      default:
        return AppTheme.amber;
    }
  }

  List<ControlSlot> _defaultSlots() {
    return [
      _mk('a', 'button', 0.78, 0.32, 0.10, 0.12, 'A', 'A'),
      _mk('b', 'button', 0.86, 0.48, 0.10, 0.12, 'B', 'B'),
      _mk('x', 'button', 0.86, 0.16, 0.10, 0.12, 'X', 'X'),
      _mk('y', 'button', 0.78, 0.64, 0.10, 0.12, 'Y', 'Y'),
      _mk('dpad', 'dpad', 0.16, 0.5, 0.20, 0.42, 'D-PAD', 'DPAD'),
      _mk('stick', 'stick', 0.84, 0.78, 0.16, 0.30, 'STICK', 'RX/RY'),
      _mk('sel', 'button', 0.46, 0.42, 0.09, 0.09, 'SELECT', 'SELECT'),
      _mk('sta', 'button', 0.54, 0.60, 0.09, 0.09, 'START', 'START'),
    ];
  }

  ControlSlot _mk(String id, String kind, double x, double y, double wd,
      double ht, String label, String action) =>
      ControlSlot(
          id: id, kind: kind, x: x, y: y, w: wd, h: ht, label: label, action: action);
}
