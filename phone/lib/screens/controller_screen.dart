import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../services/connection_manager.dart';
import '../models/control_slot.dart';
import '../models/packet.dart';
import '../services/layout_store.dart';
import '../theme/app_theme.dart';
import '../widgets/analog_stick.dart';
import '../widgets/gamepad_button.dart';
import '../layout/layout_engine.dart';
import 'connection_screen.dart';
import 'layout_editor_screen.dart';
import 'settings_screen.dart';

/// Full-screen controller for a phone held LANDSCAPE.  Presets are rendered
/// inside the disjoint zones produced by [LayoutPanel], keeping them clear of
/// notches/nav bars.  A full-width shoulder strip spans the top; the menu and
/// latency sit in a chrome band beneath it; the in-game menu is a bottom sheet.
enum ControllerLayout { gamepad, custom }

class _RadialItem {
  final String label;
  final IconData? icon;
  final String action;
  final double angle;

  const _RadialItem({
    this.label = '',
    this.icon,
    required this.action,
    required this.angle,
  });
}

/// Radial face/d-pad pad driven by RAW pointer events — responds instantly to
/// plain taps AND glides (no gesture-arena slop), and is multi-touch safe.
class _RadialPad extends StatefulWidget {
  final double size;
  final List<_RadialItem> items;
  final void Function(String action, bool pressed) onChanged;

  const _RadialPad({
    required this.size,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_RadialPad> createState() => _RadialPadState();
}

class _RadialPadState extends State<_RadialPad> {
  final GlobalKey _padKey = GlobalKey();

  /// Action armed by each active pointer (null while in the centre gap).
  final Map<int, String?> _pointerArm = {};
  final Set<String> _held = {};

  /// Resolves a screen point into pad-local space. Going through
  /// [RenderBox.globalToLocal] (instead of trusting `PointerEvent.localPosition`)
  /// removes any transform ambiguity from the pads being shifted out of the
  /// grip zone by [FractionalTranslation].
  Offset _localFrom(Offset global) {
    final ctx = _padKey.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox) return Offset.zero;
    return box.globalToLocal(global);
  }

  double _angleDiff(double a, double b) =>
      math.atan2(math.sin(a - b), math.cos(a - b)).abs();

  String? _actionAt(Offset local) {
    final size = widget.size;
    final dx = local.dx - size / 2;
    final dy = local.dy - size / 2;

    // Small square neutral gap around the pad centre.
    final gap = size * 0.14;
    if (dx.abs() < gap && dy.abs() < gap) return null;

    // Axis-dominant classification (mirrors the proven original D-pad/face
    // scheme): the whole top region maps to the up button, so a tap at the top
    // edge is never swallowed by a dead circle.
    final double target;
    if (dy.abs() >= dx.abs()) {
      target = dy < 0 ? -math.pi / 2 : math.pi / 2; // up / down
    } else {
      target = dx < 0 ? math.pi : 0.0; // left / right
    }

    _RadialItem nearest = widget.items.first;
    var best = double.infinity;
    for (final item in widget.items) {
      final diff = _angleDiff(target, item.angle);
      if (diff < best) {
        best = diff;
        nearest = item;
      }
    }
    return nearest.action;
  }

  void _press(String action) {
    if (_held.contains(action)) return;
    setState(() => _held.add(action));
    widget.onChanged(action, true);
  }

  void _release(String action) {
    if (!_held.contains(action)) return;
    setState(() => _held.remove(action));
    widget.onChanged(action, false);
  }

  void _sync(int pointer, Offset local) {
    final next = _actionAt(local);
    final prev = _pointerArm[pointer];
    if (prev == next) return;
    _pointerArm[pointer] = next;
    if (prev != null && !_pointerArm.containsValue(prev)) {
      _release(prev);
    }
    if (next != null) {
      final others = _pointerArm.entries
          .where((e) => e.key != pointer && e.value == next)
          .map((e) => e.key)
          .toList();
      if (others.isNotEmpty) {
        for (final other in others) {
          _pointerArm[other] = null;
        }
        setState(() {});
      }
      _press(next);
    } else {
      setState(() {});
    }
  }

  void _remove(int pointer) {
    final prev = _pointerArm.remove(pointer);
    if (prev != null && !_pointerArm.containsValue(prev)) {
      _release(prev);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final center = size / 2;
    final buttonDiameter = size * 0.34;
    final orbit = size * 0.30;
    final lit = _held.isNotEmpty;

    return Listener(
      key: _padKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _sync(e.pointer, _localFrom(e.position)),
      onPointerMove: (e) {
        if (_pointerArm.containsKey(e.pointer)) {
          _sync(e.pointer, _localFrom(e.position));
        }
      },
      onPointerUp: (e) => _remove(e.pointer),
      onPointerCancel: (e) => _remove(e.pointer),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surface.withOpacity(0.72),
                    border: Border.all(
                      color: lit ? AppTheme.accent : AppTheme.textMuted.withOpacity(0.22),
                      width: lit ? 1.6 : 1.2,
                    ),
                  ),
                ),
              ),
            ),
            ...widget.items.map((item) {
              final left = center + math.cos(item.angle) * orbit - buttonDiameter / 2;
              final top = center + math.sin(item.angle) * orbit - buttonDiameter / 2;
              final active = _held.contains(item.action);

              return Positioned(
                left: left,
                top: top,
                width: buttonDiameter,
                height: buttonDiameter,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 55),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? AppTheme.accent.withOpacity(0.92)
                          : AppTheme.bg.withOpacity(0.88),
                      border: Border.all(
                        color: active
                            ? AppTheme.accent
                            : AppTheme.textMuted.withOpacity(0.30),
                        width: active ? 2.0 : 1.1,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.28),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : const [],
                    ),
                    alignment: Alignment.center,
                    child: item.icon != null
                        ? Icon(
                            item.icon,
                            size: buttonDiameter * 0.62,
                            color: active ? AppTheme.bg : AppTheme.textPrimary,
                          )
                        : Text(
                            item.label,
                            style: TextStyle(
                              color: active ? AppTheme.bg : AppTheme.textPrimary,
                              fontSize: size * 0.085,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              );
            }),
            // Big centre hub — diameter matches the dead zone, so it reads as
            // the neutral "glide gap" and never triggers a direction.
            Positioned(
              left: center - size * 0.15,
              top: center - size * 0.15,
              width: size * 0.30,
              height: size * 0.30,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bg.withOpacity(0.55),
                    border: Border.all(
                      color: lit
                          ? AppTheme.textMuted.withOpacity(0.45)
                          : AppTheme.textMuted.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  ControllerLayout _currentLayout = ControllerLayout.gamepad;
  bool _menuOpen = false;
  int _mouseMask = 0;
  ConnectionStatus? _lastStatus;
  bool _returning = false;
  ConnectionManager? _watched;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _watched = context.read<ConnectionManager>();
    _lastStatus = _watched!.state;
    _watched!.addListener(_onStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionManager>().enableAutoReconnect();
    });
    _bindHaptic();
  }

  /// A dropped link (manual Disconnect or lost connection) sends the player to
  /// the main connection page instead of leaving a stuck/blank screen.
  void _onStatusChanged() {
    if (_returning || !mounted) return;
    final s = _watched!.state;
    final wasConnected = _lastStatus == ConnectionStatus.connected;
    _lastStatus = s;
    if (s == ConnectionStatus.disconnected && wasConnected) {
      _returning = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ConnectionScreen()),
      );
    }
  }

  void _bindHaptic() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionManager>().onHaptic = (dur, intensity, motor) {
        Vibration.vibrate(duration: dur);
      };
    });
  }

  @override
  void dispose() {
    _watched?.removeListener(_onStatusChanged);
    // Restore normal (portrait) UI for whatever screen is underneath.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  ConnectionManager _cm() => context.read<ConnectionManager>();

  LayoutPanel get _panel {
    final vp = MediaQuery.of(context).viewPadding;
    return LayoutPanel(
      size: MediaQuery.of(context).size,
      safeTop: vp.top,
      safeBottom: vp.bottom,
      safeLeft: vp.left,
      safeRight: vp.right,
    );
  }

  // ------------------------------- inputs ------------------------------ //
  /// Subtle click on press-down so every button press is heard. Toggled by the
  /// Settings "Button Feedback" switch. Gated by the [SettingsScreen] toggle.
  /// Sound only (no vibration / haptics).
  void _feedback() {
    if (!_cm().buttonFeedback) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  void _setButton(String name, bool pressed) {
    final cm = _cm();
    final c = cm.controller;
    var changed = c.setButton(name, pressed);

    if (name == 'L2' || name == 'R2') {
      changed = c.setTrigger(name, pressed ? 1.0 : 0.0) || changed;
    }

    if (pressed) {
      _feedback();
    }

    if (mounted) setState(() {});

    if (changed) {
      cm.pushState();
    }
  }

  /// Circular, glide-friendly D-pad. Vector arrows (no emoji), tap OR glide.
  Widget _buildDPad(double size) {
    return _RadialPad(
      size: size,
      items: const [
        _RadialItem(
            icon: Icons.keyboard_arrow_up,
            action: 'DPAD_UP',
            angle: -math.pi / 2),
        _RadialItem(
            icon: Icons.keyboard_arrow_right,
            action: 'DPAD_RIGHT',
            angle: 0),
        _RadialItem(
            icon: Icons.keyboard_arrow_down,
            action: 'DPAD_DOWN',
            angle: math.pi / 2),
        _RadialItem(
            icon: Icons.keyboard_arrow_left,
            action: 'DPAD_LEFT',
            angle: math.pi),
      ],
      onChanged: (action, pressed) => _setButton(action, pressed),
    );
  }

  /// Circular, glide-friendly face pad.
  /// Triangle -> Y, circle -> B, cross -> A, square -> X.
  Widget _buildFacePad(double size) {
    return _RadialPad(
      size: size,
      items: const [
        _RadialItem(label: '■', action: 'X', angle: -math.pi / 2),
        _RadialItem(label: '●', action: 'B', angle: 0),
        _RadialItem(label: '✕', action: 'A', angle: math.pi / 2),
        _RadialItem(label: '▲', action: 'Y', angle: math.pi),
      ],
      onChanged: (action, pressed) => _setButton(action, pressed),
    );
  }

  void _sendKey(String name, bool pressed) {
    if (pressed) _feedback();
    _cm().sendKey(name, pressed);
  }

  void _setAxis(String name, double v) {
    final cm = _cm();
    v = (v * cm.sensitivity).clamp(-1.0, 1.0);
    if (cm.controller.setAxis(name, v)) cm.pushState();
  }

  void _exit() {
    context.read<ConnectionManager>().disconnect();
  }

  // ------------------------------- build ------------------------------- //
  @override
  Widget build(BuildContext context) {
    final p = _panel;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Background(
        child: Stack(
          children: [
            SizedBox.expand(child: _buildCurrentLayout()),
            // Top chrome: small menu + latency, no wide shoulder bar.
            _inRect(
                Rect.fromLTWH(0, 0, p.size.width, 48), _buildChrome()),
            // Gamepad bumpers hug the very top screen corners (edge-to-edge),
            // so they never share the bar with the menu.
            if (_currentLayout == ControllerLayout.gamepad) ...[
              Positioned(top: 0, left: 0, child: _bumperRow(['L2', 'L1'])),
              Positioned(top: 0, right: 0, child: _bumperRow(['R1', 'R2'])),
            ],
            if (_menuOpen) Positioned.fill(child: _buildMenuOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _inRect(Rect r, Widget child) => Positioned(
      left: r.left, top: r.top, width: r.width, height: r.height, child: child);

  /// Where a top-anchored pad renders after its calibrated
  /// [FractionalTranslation] shift (was `Align(alignment: topCenter)` +
  /// `FractionalTranslation(t)` over a [Rect]). The [Positioned] box must match
  /// the *visual* box: with `Align`+`FractionalTranslation` the box stayed at
  /// the grip rect, so the part of the pad protruding above the grip could
  /// never receive a pointer down and the top button was untappable.
  Rect _calibratedTopRect(Rect grip, double size, Offset t) => Rect.fromLTWH(
      grip.center.dx - size / 2 + t.dx * size, grip.top + t.dy * size, size, size);

  /// Same as [_calibratedTopRect] but for a bottom-anchored widget
  /// (was `Align(alignment: bottomCenter)`).
  Rect _calibratedBottomRect(Rect grip, double size, Offset t) => Rect.fromLTWH(
      grip.center.dx - size / 2 + t.dx * size,
      grip.bottom - size + t.dy * size,
      size,
      size);

  Widget _buildCurrentLayout() {
    switch (_currentLayout) {
      case ControllerLayout.custom:
        return _buildCustomLayout();
      case ControllerLayout.gamepad:
      default:
        return _buildGamepadLayout();
    }
  }

  // --------------------------- bumpers + chrome ------------------------ //
  /// Two bumpers hugging the screen edge: L2/L1 on the left corner, R1/R2 on
  /// the right. No container/bar behind them — they sit right on the edge.
  Widget _bumperRow(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _bumper(labels[i]),
          ],
        ],
      ),
    );
  }

  Widget _bumper(String label, {double width = 92, double height = 40}) {
    return GamepadButton(
      label: label,
      width: width,
      height: height,
      fontSize: 12,
      onDown: () => _setButton(label, true),
      onUp: () => _setButton(label, false),
    );
  }

  Widget _bumperMenu() {
    return GamepadButton(
      label: '',
      icon: _menuOpen ? Icons.close : Icons.menu,
      width: 48,
      height: 40,
      fontSize: 12,
      active: _menuOpen,
      onTap: () => setState(() => _menuOpen = !_menuOpen),
    );
  }

  Widget _buildChrome() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bumperMenu(),
          const SizedBox(width: 10),
          _buildLatencyPill(),
        ],
      ),
    );
  }

  Widget _buildLatencyPill() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: AppTheme.card(
            radius: 999, color: AppTheme.surface, border: AppTheme.hairline),
        child: Row(
          children: [
            Icon(
              manager.mode.toString().toLowerCase().contains('usb')
                  ? Icons.usb
                  : Icons.wifi,
                size: 14, color: AppTheme.green),
            const SizedBox(width: 6),
            Text('${manager.latency}ms',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.green,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ----------------------------- Gamepad ------------------------------- //
  // Both grip positions always visible: left grip = D-pad (top) + left stick
  // (bottom); right grip = ABXY (top) + right stick (bottom); SELECT/START in
  // the central column.
  Widget _buildGamepadLayout() {
    return _dualGripLayout();
  }

  /// Your original calibrated gamepad layout.
  /// Do not change these translations or the grip geometry without recalibrating.
  Widget _dualGripLayout({double topFrac = 0.58, double botFrac = 0.42}) {
    final p = _panel;
    final dz = LayoutPanel.fit(p.gripLeft, topFrac);
    final sz = LayoutPanel.fit(p.gripLeft, botFrac);
    final dead = _cm().deadZone;

    Widget leftStick() => AnalogStick(
          size: sz,
          deadZone: dead,
          onChanged: (x, y) {
            _setAxis('LX', x);
            _setAxis('LY', y);
          },
        );

    Widget rightStick() => AnalogStick(
          size: sz,
          deadZone: dead,
          onChanged: (x, y) {
            _setAxis('RX', x);
            _setAxis('RY', y);
          },
        );

    return Stack(
      children: [
        // ORIGINAL CALIBRATED POSITION — DO NOT MOVE.
        _inRect(
          _calibratedTopRect(p.gripLeft, dz, const Offset(-0.30, -0.40)),
          _buildDPad(dz),
        ),
        // ORIGINAL CALIBRATED POSITION — DO NOT MOVE.
        _inRect(
          _calibratedBottomRect(p.gripLeft, sz, const Offset(0.70, -0.50)),
          leftStick(),
        ),
        // ORIGINAL CALIBRATED POSITION — DO NOT MOVE.
        _inRect(
          _calibratedTopRect(p.gripRight, dz, const Offset(0.30, -0.40)),
          _buildFacePad(dz),
        ),
        // ORIGINAL CALIBRATED POSITION — DO NOT MOVE.
        _inRect(
          _calibratedBottomRect(p.gripRight, sz, const Offset(-0.70, -0.50)),
          rightStick(),
        ),
        _inRect(
          p.center,
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_pill('SELECT'), const SizedBox(height: 10), _pill('START')],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String label) {
    return GamepadButton(
      label: label,
      width: 52,
      height: 38,
      fontSize: 10,
      onDown: () => _setButton(label, true),
      onUp: () => _setButton(label, false),
    );
  }

  // ----------------------------- Custom -------------------------------- //
  Widget _buildCustomLayout() {
    final layout = context.watch<LayoutStore>().active;
    if (layout == null || layout.slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No custom layout yet', style: AppTheme.bodySecondary),
            const SizedBox(height: 16),
            GamepadButton(
              label: 'NEW LAYOUT',
              width: 168,
              height: 48,
              highlight: true,
              fontSize: 12,
              onTap: _startNewLayout,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: layout.slots.map((s) {
            return Positioned(
              left: (s.x - s.w / 2) * w,
              top: (s.y - s.h / 2) * h,
              width: s.w * w,
              height: s.h * h,
              child: _renderSlot(s, s.w * w, s.h * h),
            );
          }).toList(),
        );
      },
    );
  }

  /// Renders one custom slot, fully sized to its box so what you draw in the
  /// layout editor is exactly what the controller shows (D-pad + sticks scale
  /// with their slot; buttons fill it).
  Widget _renderSlot(ControlSlot s, double boxW, double boxH) {
    final d = math.min(boxW, boxH) * 0.92;
    switch (s.kind) {
      case 'stick':
        final isRight = s.action.contains('R') && !s.action.contains('LX');
        return Center(
          child: AnalogStick(
            size: d,
            deadZone: _cm().deadZone,
            onChanged: (x, y) {
              _setAxis(isRight ? 'RX' : 'LX', x);
              _setAxis(isRight ? 'RY' : 'LY', y);
            },
          ),
        );
      case 'dpad':
        return Center(child: _buildDPad(d));
      case 'face':
        return Center(child: _buildFacePad(d));
      default:
        final action = s.action.isEmpty ? s.label : s.action;
        return _customButton(s.label, action);
    }
  }

  Widget _customButton(String label, String action) {
    // A custom button fires a gamepad button, a real keyboard key, or a mouse
    // click depending on its namespaced action (`pad:A` / `key:W` / `mouse:LMB`).
    void press(bool down) {
      final a = SlotAction.parse(action);
      switch (a.type) {
        case SlotActionType.key:
          _sendKey(a.name, down);
        case SlotActionType.mouse:
          _mouseBit(a.name, down);
        case SlotActionType.pad:
          _setButton(a.name, down);
      }
    }

    return GamepadButton(
      label: label,
      width: double.infinity,
      height: double.infinity,
      fontSize: 14,
      onDown: () => press(true),
      onUp: () => press(false),
    );
  }

  static const Map<String, int> _mouseBits = {
    'LMB': 0x01,
    'RMB': 0x02,
    'MMB': 0x04,
  };

  /// Press/release a mouse button through the wire protocol.
  void _mouseBit(String name, bool pressed) {
    final bit = _mouseBits[name];
    if (bit == null) return;
    setState(() {
      if (pressed) {
        _mouseMask |= bit;
      } else {
        _mouseMask &= ~bit;
      }
    });
    if (pressed) _feedback();
    _cm().sendMouse(0, 0, _mouseMask);
  }

  Future<void> _startNewLayout({String? name}) async {
    final finalName =
        name ?? await _promptName(title: 'New layout', defaultValue: 'My Custom');
    if (!mounted || finalName == null) return;
    final layout = _defaultCustomLayout()..name = finalName;
    await context.read<LayoutStore>().save(layout);
    if (!mounted) return;
    await _openLayout(layout);
  }

  Future<void> _openLayout(CustomLayout layout) async {
    setState(() => _menuOpen = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LayoutEditorScreen(layout: layout)),
    );
  }

  Future<String?> _promptName(
      {required String title, String defaultValue = '', String? message}) {
    final controller = TextEditingController(text: defaultValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(message, style: AppTheme.caption),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Name',
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.hairline)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _openActiveLayout() async {
    final store = context.read<LayoutStore>();
    final layout = store.active;
    if (layout == null) return;
    await _openLayout(layout);
  }

  CustomLayout _defaultCustomLayout() {
    // A faithful, non-overlapping copy of the default controller you can
    // enlarge / reposition in the editor. Values are fractions of screen W/H;
    // D-pad + sticks render at their slot-box size.
    ControlSlot s(String id, String kind, double x, double y, double wd,
            double ht, String label, String action) =>
        ControlSlot(
            id: id,
            kind: kind,
            x: x,
            y: y,
            w: wd,
            h: ht,
            label: label,
            action: action);
    return CustomLayout(id: CustomLayout.newId(), name: 'My Custom', slots: [
      // Shoulder stacks along the very top edge (L2 above L1, R2 above R1).
      s('l2', 'button', 0.09, 0.05, 0.12, 0.10, 'L2', 'L2'),
      s('l1', 'button', 0.09, 0.16, 0.12, 0.10, 'L1', 'L1'),
      s('r2', 'button', 0.91, 0.05, 0.12, 0.10, 'R2', 'R2'),
      s('r1', 'button', 0.91, 0.16, 0.12, 0.10, 'R1', 'R1'),
      // Left grip: D-pad on top, left stick below.
      s('d', 'dpad', 0.17, 0.38, 0.28, 0.40, 'D-PAD', 'DPAD'),
      s('lst', 'stick', 0.17, 0.75, 0.24, 0.22, 'L-STICK', 'LX/LY'),
      // Right grip: face pad (▲ ● ✕ ■) up top, right stick below.
      s('f', 'face', 0.83, 0.38, 0.28, 0.40, 'FACE', 'Y/B/A/X'),
      s('rst', 'stick', 0.83, 0.75, 0.24, 0.22, 'R-STICK', 'RX/RY'),
      // Centre column: SELECT / START.
      s('sel', 'button', 0.46, 0.30, 0.10, 0.10, 'SELECT', 'SELECT'),
      s('sta', 'button', 0.54, 0.30, 0.10, 0.10, 'START', 'START'),
    ]);
  }

  // ------------------------------ Menu --------------------------------- //
  Widget _buildMenuOverlay() {
    final mq = MediaQuery.of(context);
    final sheetW = math.min(372.0, mq.size.width - 16);
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: sheetW,
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              constraints:
                  BoxConstraints(maxHeight: mq.size.height * 0.72),
              decoration: AppTheme.card(color: AppTheme.surface),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                        child:
                            Text('CONTROLS', textAlign: TextAlign.center, style: AppTheme.label)),
                    const SizedBox(height: 10),
                    _menuLabel('MY CONTROLS'),
                    _menuRow(Icons.gamepad, 'Controller', ControllerLayout.gamepad),
                    if (!_hasCustom)
                      _menuRow(
                        Icons.tune,
                        'Custom (none yet)',
                        ControllerLayout.custom,
                        enabled: false,
                        onTap: _startNewLayout,
                      ),
                    const SizedBox(height: 6),
                    _menuLabel('MY LAYOUTS'),
                    ..._layoutRows(),
                    const SizedBox(height: 8),
                    _menuAction(Icons.add, 'New Layout', _startNewLayout),
                    const SizedBox(height: 12),
                    _menuLabel('CUSTOMIZE'),
                    _menuAction(
                      Icons.edit,
                      'Edit Active Layout',
                      _openActiveLayout,
                      color: _hasCustom
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                    _menuAction(Icons.settings, 'Settings', () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    }, color: AppTheme.textSecondary),
                    const SizedBox(height: 4),
                    _menuAction(Icons.exit_to_app, 'Disconnect', _exit,
                        color: AppTheme.red),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One row per saved layout: tap to activate, trailing `⋮` manages it.
  List<Widget> _layoutRows() {
    final store = context.watch<LayoutStore>();
    return [
      for (final layout in store.layouts) _layoutRow(store, layout),
    ];
  }

  Widget _layoutRow(LayoutStore store, CustomLayout layout) {
    final active = store.active?.id == layout.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          store.activate(layout.id);
          setState(() {
            _currentLayout = ControllerLayout.custom;
            _menuOpen = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
          decoration: active
              ? AppTheme.cardActive(radius: 10)
              : BoxDecoration(
                  color: AppTheme.whiteAt(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.transparent),
                ),
          child: Row(
            children: [
              Icon(Icons.tune,
                  size: 20,
                  color: active ? AppTheme.accent : AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(layout.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (active) const Icon(Icons.check, size: 18, color: AppTheme.accent),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert,
                    size: 20, color: active ? AppTheme.accent : AppTheme.textMuted),
                color: AppTheme.surface,
                onSelected: (choice) => _onLayoutMenu(store, layout, choice),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onLayoutMenu(
      LayoutStore store, CustomLayout layout, String choice) async {
    switch (choice) {
      case 'edit':
        await _openLayout(layout);
        break;
      case 'rename':
        final name = await _promptName(
            title: 'Rename layout', defaultValue: layout.name);
        if (name != null && name.isNotEmpty) await store.rename(layout.id, name);
        break;
      case 'duplicate':
        await store.duplicate(layout.id);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Delete layout?',
                style: TextStyle(color: AppTheme.textPrimary)),
            content: Text("'${layout.name}' will be removed.",
                style: const TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: AppTheme.red))),
            ],
          ),
        );
        if (confirmed == true) await store.remove(layout.id);
    }
  }

  Widget _menuRow(IconData icon, String label, ControllerLayout layout,
      {bool enabled = true, VoidCallback? onTap}) {
    final active = _currentLayout == layout;
    final action = onTap ??
        (enabled
            ? () {
                setState(() {
                  _currentLayout = layout;
                  _menuOpen = false;
                });
              }
            : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: action,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: active
              ? AppTheme.cardActive(radius: 10)
              : BoxDecoration(
                  color: AppTheme.whiteAt(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.transparent),
                ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: active
                      ? AppTheme.accent
                      : enabled
                          ? AppTheme.textSecondary
                          : AppTheme.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: active
                            ? AppTheme.textPrimary
                            : enabled
                                ? AppTheme.textSecondary
                                : AppTheme.textMuted,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (active) const Icon(Icons.check, size: 18, color: AppTheme.accent),
              if (!enabled && !active)
                Text('Build one',
                    style: AppTheme.caption.copyWith(color: AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Text(text, style: AppTheme.label.copyWith(color: AppTheme.textMuted)),
    );
  }

  Widget _menuAction(IconData icon, String label, VoidCallback onTap,
      {Color color = AppTheme.textPrimary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.whiteAt(0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasCustom => context.read<LayoutStore>().active != null;
}