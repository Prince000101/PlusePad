import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/control_slot.dart';
import '../services/layout_store.dart';
import '../services/protocol.dart' as p;
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
    _slots = widget.layout.slots.map((s) => ControlSlot.copy(s)).toList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  ControlSlot? get _selected =>
      _slots.where((s) => s.id == _selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
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
                      Flexible(
                        child: Text(widget.layout.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      _chromeIcon(Icons.restore, 'Reset', _resetToDefault),
                      const SizedBox(width: 8),
                      _chromeIcon(Icons.save_as, 'Save As New', _saveAs),
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

  CustomLayout _currentLayout() {
    // Normalise every button action to its namespaced wire form so drags and
    // saves keep a consistent store even for layouts that came from v1.
    for (final s in _slots) {
      if (s.kind == 'button' && s.action.isNotEmpty) {
        s.action = SlotAction.parse(s.action).wire;
      }
    }
    return CustomLayout(
        id: widget.layout.id, name: widget.layout.name, slots: _slots);
  }

  void _resetToDefault() {
    setState(() {
      _slots.clear();
      _slots.addAll(_defaultSlots());
      _selectedId = null;
    });
  }

  void _save() {
    final store = context.read<LayoutStore>();
    final layout = _currentLayout();
    store.save(layout);
    Navigator.pop(context, layout);
  }

  Future<void> _saveAs() async {
    final controller = TextEditingController(text: '${widget.layout.name} Copy');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Save as new layout',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Name',
            border: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.hairline)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    final copy = CustomLayout(
      id: CustomLayout.newId(),
      name: name,
      slots: _currentLayout().slots.map((s) => ControlSlot.clone(s)).toList(),
    );
    final store = context.read<LayoutStore>();
    store.save(copy);
    Navigator.pop(context, copy);
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
                color: _colorFor(s.kind).withAlpha(
                    (isSelected || _dragging ? 150 : 95).clamp(0, 255)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.hairline,
                    width: isSelected ? 2 : 1.2),
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
                      color: AppTheme.accent,
                      border:
                          Border.all(color: AppTheme.bg, width: 2),
                    ),
                    child: const Icon(Icons.arrow_outward,
                        size: 12, color: AppTheme.bg),
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.hairline)),
      ),
      child: sel == null ? _buildAddRow() : _buildEditRow(sel),
    );
  }

  Widget _buildAddRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolButton(Icons.touch_app, 'Button', () => _add('button')),
          const SizedBox(width: 8),
          _toolButton(Icons.sports_esports, 'Face Pad', () => _add('face')),
          const SizedBox(width: 8),
          _toolButton(Icons.grid_on, 'D-Pad', () => _add('dpad')),
          const SizedBox(width: 8),
          _toolButton(Icons.gps_fixed, 'Stick', () => _add('stick')),
          const SizedBox(width: 16),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('Tap a control to edit it',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditRow(ControlSlot s) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolButton(Icons.label, 'Rename', () => _rename(s)),
          const SizedBox(width: 8),
          _toolButton(Icons.swap_horiz, 'Action', () => _chooseAction(s)),
          const SizedBox(width: 8),
          _toolButton(Icons.add, 'Bigger', () => _resizeStep(s, 1.15)),
          const SizedBox(width: 8),
          _toolButton(Icons.remove, 'Smaller', () => _resizeStep(s, 0.87)),
          const SizedBox(width: 16),
          _toolButton(Icons.delete, 'Delete', () => _delete(s), danger: true),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (danger ? AppTheme.red : AppTheme.accent).withAlpha(
              (danger ? 60 : 42).clamp(0, 255)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (danger ? AppTheme.red : AppTheme.accent)
                  .withAlpha((danger ? 160 : 120).clamp(0, 255))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: danger ? AppTheme.red : AppTheme.accent),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: danger ? AppTheme.red : AppTheme.textPrimary)),
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
          color: AppTheme.surfaceAlt,
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
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
      label: kind == 'stick'
          ? 'STICK'
          : kind == 'dpad'
              ? 'D-PAD'
              : kind == 'face'
                  ? 'FACE'
                  : 'BTN',
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
        backgroundColor: AppTheme.surface,
        title: const Text('Rename',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Label',
            border: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.hairline)),
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
    final selected = _selected;
    if (selected != null && selected.kind != 'button') {
      // dpad / face / stick use fixed wire behaviour; allow choosing the set.
      List<String> choices = const ['DPAD'];
      if (selected.kind == 'stick') choices = const ['LX/LY', 'RX/RY'];
      if (selected.kind == 'face') choices = const ['Y/B/A/X'];
      _showSimpleChoice(s, choices);
      return;
    }
    _showActionGroups(s);
  }

  void _showSimpleChoice(ControlSlot s, List<String> choices) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: choices
              .map((a) => ListTile(
                    title: Text(a,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    trailing: s.action == a
                        ? const Icon(Icons.check, color: AppTheme.accent)
                        : null,
                    onTap: () {
                      setState(() => s.action = a);
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// Categorised action picker for custom *buttons*. Stores namespaced wire
  /// values (`pad:A`, `key:W`, `mouse:LMB`) so gamepad and keyboard names can
  /// never collide.
  void _showActionGroups(ControlSlot s) {
    final groups = _actionGroups();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(g.section,
                    style: AppTheme.label.copyWith(color: AppTheme.textMuted)),
              ),
              for (final (label, wire) in g.items)
                ListTile(
                  dense: true,
                  title: Text(label,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: s.action == wire
                      ? const Icon(Icons.check, color: AppTheme.accent)
                      : null,
                  onTap: () {
                    setState(() {
                      s.action = wire;
                      // For buttons the label mirrors the action by default if
                      // the user hasn't customised it yet.
                      if (s.label == 'BTN' || s.label == '') s.label = label;
                    });
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// [section, items(label, wire)] — wire values for buttons; categories for
  /// the non-button kinds stay plain.
  static List<({String section, List<(String, String)> items})>
      _actionGroups() {
    const pads = [
      'A', 'B', 'X', 'Y', 'SELECT', 'START',
      'L1', 'R1', 'L2', 'R2', 'L3', 'R3',
      'DPAD_UP', 'DPAD_DOWN', 'DPAD_LEFT', 'DPAD_RIGHT',
    ];
    return [
      (
        section: 'GAMEPAD',
        items: [for (final n in pads) (n, 'pad:$n')],
      ),
      (
        section: 'KEYS',
        items: [for (final n in p.kKeys) (n, 'key:$n')],
      ),
      (
        section: 'MOUSE',
        items: [for (final n in const ['LMB', 'RMB', 'MMB']) (n, 'mouse:$n')],
      ),
    ];
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
        return AppTheme.accent;
      case 'dpad':
        return AppTheme.green;
      case 'face':
        return AppTheme.amber;
      default:
        return AppTheme.amber;
    }
  }

  List<ControlSlot> _defaultSlots() {
    return [
      _mk('l2', 'button', 0.09, 0.05, 0.12, 0.10, 'L2', 'L2'),
      _mk('l1', 'button', 0.09, 0.16, 0.12, 0.10, 'L1', 'L1'),
      _mk('r2', 'button', 0.91, 0.05, 0.12, 0.10, 'R2', 'R2'),
      _mk('r1', 'button', 0.91, 0.16, 0.12, 0.10, 'R1', 'R1'),
      _mk('d', 'dpad', 0.17, 0.38, 0.28, 0.40, 'D-PAD', 'DPAD'),
      _mk('lst', 'stick', 0.17, 0.75, 0.24, 0.22, 'L-STICK', 'LX/LY'),
      _mk('f', 'face', 0.83, 0.38, 0.28, 0.40, 'FACE', 'Y/B/A/X'),
      _mk('rst', 'stick', 0.83, 0.75, 0.24, 0.22, 'R-STICK', 'RX/RY'),
      _mk('sel', 'button', 0.46, 0.30, 0.10, 0.10, 'SELECT', 'SELECT'),
      _mk('sta', 'button', 0.54, 0.30, 0.10, 0.10, 'START', 'START'),
    ];
  }

  ControlSlot _mk(String id, String kind, double x, double y, double wd,
      double ht, String label, String action) =>
      ControlSlot(
          id: id, kind: kind, x: x, y: y, w: wd, h: ht, label: label, action: action);
}
