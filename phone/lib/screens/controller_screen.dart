import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../models/packet.dart';
import '../services/connection_manager.dart';
import '../services/protocol.dart' as p;
import '../models/control_slot.dart';
import '../services/layout_store.dart';
import '../theme/app_theme.dart';
import '../widgets/analog_stick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/dpad.dart';
import '../widgets/gamepad_button.dart';
import '../layout/layout_engine.dart';
import 'layout_editor_screen.dart';
import 'settings_screen.dart';

/// Full-screen controller for a phone held LANDSCAPE. Every preset is rendered
/// inside the guaranteed-disjoint zones produced by [LayoutPanel], so controls
/// can never overlap and always clear the notches/nav bars. A single full-width
/// shoulder strip spans the top; the menu + latency sit in a chrome band
/// beneath it; the in-game menu is a scrollable bottom sheet.
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with TickerProviderStateMixin {
  ControllerLayout _currentLayout = ControllerLayout.gamepad;
  bool _menuOpen = false;
  int _mouseButtons = 0;
  Offset? _touchLast;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionManager>().enableAutoReconnect();
    });
    _bindHaptic();
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
  /// Subtle tick + buzz on press-down, so every button press is felt/heard.
  /// Gated by the Settings "Button Feedback" toggle. Down-edge only (no flood
  /// while dragging sticks or holding triggers).
  void _feedback() {
    if (!_cm().buttonFeedback) return;
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void _setButton(String name, bool pressed) {
    final cm = _cm();
    final c = cm.controller;
    var changed = c.setButton(name, pressed);
    if (name == 'L2' || name == 'R2') {
      changed = c.setTrigger(name, pressed ? 1.0 : 0.0) || changed;
    }
    if (changed) {
      if (pressed) _feedback();
      cm.pushState();
    }
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

  void _dpad(String dir, bool pressed) => _setButton(dir, pressed);

  void _exit() {
    context.read<ConnectionManager>().disconnect();
    Navigator.pop(context);
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
            // Full-width shoulder strip along the very top edge.
            _inRect(p.shoulder, _buildShoulderStrip(p)),
            // Chrome band: menu + latency, centred under the strip.
            _inRect(
                Rect.fromLTWH(
                    0, p.shoulder.bottom, p.size.width, 56),
                _buildChrome()),
            if (_menuOpen) Positioned.fill(child: _buildMenuOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _inRect(Rect r, Widget child) => Positioned(
      left: r.left, top: r.top, width: r.width, height: r.height, child: child);

  Widget _buildCurrentLayout() {
    switch (_currentLayout) {
      case ControllerLayout.mouse:
        return _buildMouseLayout();
      case ControllerLayout.keyboard:
        return _buildKeyboardLayout();
      case ControllerLayout.custom:
        return _buildCustomLayout();
      case ControllerLayout.gamepad:
      default:
        return _buildGamepadLayout();
    }
  }

  // --------------------------- shoulder strip -------------------------- //
  Widget _buildShoulderStrip(LayoutPanel p) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _bumper('L2'),
                  _bumper('L1'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _bumper('R1'),
                  _bumper('R2'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bumper(String label) {
    return GamepadButton(
      label: label,
      width: 76,
      height: 40,
      fontSize: 12,
      onDown: () => _setButton(label, true),
      onUp: () => _setButton(label, false),
    );
  }

  Widget _buildChrome() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GamepadButton(
            label: '',
            icon: _menuOpen ? Icons.close : Icons.menu,
            width: 48,
            height: 48,
            round: true,
            active: _menuOpen,
            onTap: () => setState(() => _menuOpen = !_menuOpen),
          ),
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
            Icon(manager.mode == ConnectionMode.usb ? Icons.usb : Icons.wifi,
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

  /// Shared grip layout engine for gamepad / ps5 / simple (fraction-tuned).
  Widget _dualGripLayout({double topFrac = 0.56, double botFrac = 0.46}) {
    final p = _panel;
    final dz = LayoutPanel.fit(p.gripLeft, topFrac);
    final sz = LayoutPanel.fit(p.gripLeft, botFrac);
    final face = LayoutPanel.fit(p.gripRight, topFrac);
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
        _inRect(p.gripLeft,
            Align(alignment: Alignment.topCenter, child: DPad(onChanged: _dpad, size: dz))),
        _inRect(
            p.gripLeft, Align(alignment: Alignment.bottomCenter, child: leftStick())),
        _inRect(
            p.gripRight,
            Align(
                alignment: Alignment.topCenter,
                child: ActionButtons(
                  size: face,
                  ps2: true,
                  onPressed: (b) => _setButton(b, true),
                  onReleased: (b) => _setButton(b, false),
                ))),
        _inRect(
            p.gripRight, Align(alignment: Alignment.bottomCenter, child: rightStick())),
        _inRect(
            p.center,
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_pill('SELECT'), const SizedBox(height: 10), _pill('START')],
              ),
            )),
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
    final layout = context.watch<LayoutStore>().layout;
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
              label: 'OPEN EDITOR',
              width: 168,
              height: 48,
              highlight: true,
              fontSize: 12,
              onTap: _openEditor,
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
              child: _renderSlot(s),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _renderSlot(ControlSlot s) {
    switch (s.kind) {
      case 'stick':
        final isRight = s.action.contains('R') && !s.action.contains('LX');
        return AnalogStick(
          size: 110,
          deadZone: _cm().deadZone,
          onChanged: (x, y) {
            _setAxis(isRight ? 'RX' : 'LX', x);
            _setAxis(isRight ? 'RY' : 'LY', y);
          },
        );
      case 'dpad':
        return DPad(onChanged: _dpad, size: 120);
      default:
        final action = s.action.isEmpty ? s.label : s.action;
        return _customButton(s.label, action);
    }
  }

  Widget _customButton(String label, String action) {
    // A custom button can fire a gamepad button OR a real keyboard key.
    void press(bool down) {
      if (p.kKeys.contains(action)) {
        _sendKey(action, down);
      } else {
        _setButton(action, down);
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

  void _openEditor({bool copyDefault = false}) {
    final store = context.read<LayoutStore>();
    final working = switch (copyDefault || !_hasCustom) {
      true => _defaultCustomLayout(),
      false => CustomLayout(name: 'My Custom', slots: store.layout!.slots),
    };
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LayoutEditorScreen(layout: working)),
    );
    setState(() => _menuOpen = false);
  }

  CustomLayout _defaultCustomLayout() {
    // A full PS2-style controller you can copy as a base, then enlarge /
    // reposition every control to taste. Sizes are fractions of screen W/H.
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
    return CustomLayout(name: 'My Custom', slots: [
      // Shoulders along the top edge.
      s('l2', 'button', 0.24, 0.10, 0.13, 0.14, 'L2', 'LT'),
      s('l1', 'button', 0.40, 0.10, 0.13, 0.14, 'L1', 'LB'),
      s('r1', 'button', 0.60, 0.10, 0.13, 0.14, 'R1', 'RB'),
      s('r2', 'button', 0.76, 0.10, 0.13, 0.14, 'R2', 'RT'),
      // Left cluster: D-pad + left stick.
      s('d', 'dpad', 0.16, 0.48, 0.30, 0.42, 'D-PAD', 'DPAD'),
      s('lst', 'stick', 0.14, 0.88, 0.26, 0.26, 'L-STICK', 'LX/LY'),
      // Face buttons, PS2 diamond (A bottom, B right, X left, Y top).
      s('a', 'button', 0.70, 0.34, 0.16, 0.17, 'A', 'A'),
      s('b', 'button', 0.86, 0.52, 0.16, 0.17, 'B', 'B'),
      s('x', 'button', 0.54, 0.52, 0.16, 0.17, 'X', 'X'),
      s('y', 'button', 0.70, 0.70, 0.16, 0.17, 'Y', 'Y'),
      // Right stick + centre buttons.
      s('rst', 'stick', 0.86, 0.88, 0.26, 0.26, 'R-STICK', 'RX/RY'),
      s('sel', 'button', 0.44, 0.10, 0.12, 0.13, 'SELECT', 'SELECT'),
      s('sta', 'button', 0.56, 0.10, 0.12, 0.13, 'START', 'START'),
    ]);
  }

  // ------------------------------ Mouse -------------------------------- //
  Widget _buildMouseLayout() {
    final p = _panel;
    final f = p.field;
    const rowH = 48.0;
    const pad = 10.0;
    final touch = Rect.fromLTRB(
        f.left, f.top, f.right, f.bottom - rowH - pad);

    return Stack(
      children: [
        _inRect(touch, _buildTouchpad()),
        _inRect(
            Rect.fromLTRB(f.left, touch.bottom + pad, f.right, f.bottom),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _mouseButton('LMB', 0x01),
                  const SizedBox(width: 12),
                  _mouseButton('RMB', 0x02),
                ],
              ),
            )),
      ],
    );
  }

  Widget _mouseButton(String label, int bit) {
    final active = (_mouseButtons & bit) != 0;
    return GamepadButton(
      label: label,
      width: 88,
      height: 40,
      fontSize: 11,
      active: active,
      onTap: () {
        setState(() => _mouseButtons ^= bit);
        if ((_mouseButtons & bit) != 0) _feedback();
        _cm().sendMouse(0, 0, _mouseButtons);
      },
    );
  }

  Widget _buildTouchpad() {
    return GestureDetector(
      onPanStart: (d) {
        setState(() => _mouseButtons = _mouseButtons | 0x01);
        _touchLast = d.localPosition;
        _feedback();
        _cm().sendMouse(0, 0, _mouseButtons);
      },
      onPanUpdate: (d) {
        final last = _touchLast;
        _touchLast = d.localPosition;
        if (last != null) _sendMouseDelta(d.localPosition - last);
      },
      onPanEnd: (_) {
        setState(() => _mouseButtons = _mouseButtons & ~0x01);
        _touchLast = null;
        _cm().sendMouse(0, 0, _mouseButtons);
      },
      onPanCancel: () {
        setState(() => _mouseButtons = _mouseButtons & ~0x01);
        _touchLast = null;
        _cm().sendMouse(0, 0, _mouseButtons);
      },
      child: Container(
        decoration: AppTheme.pad(color: AppTheme.surface),
        child: const Center(
          child: Text('TOUCHPAD\nDRAG = MOVE · TAP = CLICK',
              textAlign: TextAlign.center, style: AppTheme.label),
        ),
      ),
    );
  }

  void _sendMouseDelta(Offset delta) {
    final dx = (delta.dx * 3).round().clamp(-127, 127);
    final dy = (delta.dy * 3).round().clamp(-127, 127);
    if (dx == 0 && dy == 0) return;
    _cm().sendMouse(dx, dy, _mouseButtons);
  }

  // ----------------------------- Keyboard ------------------------------ //
  static const _topKeys = ['ESC', 'TAB', 'CAPS', 'SHIFT', 'CTRL', 'ENTER', 'BACKSPACE'];

  Widget _buildKeyboardLayout() {
    final f = _panel.field;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final k in _topKeys) ...[
                  _key(k, k.length > 3 ? 66 : 52, 46, k.length > 3 ? 9.0 : 12.0),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _keyCluster({'W': (0, 0), 'D': (1, 0), 'A': (0, 1), 'S': (1, 1)}),
                _keyCluster(
                    {'UP': (0, 0), 'RIGHT': (1, 0), 'LEFT': (0, 1), 'DOWN': (1, 1)}),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GamepadButton(
              label: 'SPACE',
              width: f.width * 0.45,
              height: 46,
              fontSize: 12,
              onDown: () => _sendKey('SPACE', true),
              onUp: () => _sendKey('SPACE', false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyCluster(Map<String, (int, int)> layout) {
    final kb = LayoutPanel.fit(_panel.gripLeft, 0.62) / 3;
    final size = (kb * 3 + 10).clamp(104.0, 250.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: layout.entries
            .map((e) {
              final (cx, cy) = e.value;
              return Positioned(
                left: cx * (size - kb),
                top: cy * (size - kb),
                width: kb,
                height: kb,
                child: _key(e.key, kb, kb, e.key.length > 1 ? 9.0 : 15.0),
              );
            })
            .toList(),
      ),
    );
  }

  Widget _key(String k, double w, double h, double fs) {
    return GamepadButton(
      label: k,
      width: w,
      height: h,
      fontSize: fs,
      onDown: () => _sendKey(k, true),
      onUp: () => _sendKey(k, false),
    );
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
                    _menuLabel('STYLES'),
                    _menuRow(Icons.gamepad, 'Controller', ControllerLayout.gamepad),
                    _menuRow(Icons.mouse, 'Mouse', ControllerLayout.mouse),
                    _menuRow(Icons.keyboard, 'Keyboard', ControllerLayout.keyboard),
                    _menuRow(Icons.tune, 'My Custom',
                        ControllerLayout.custom, enabled: _hasCustom,
                        onTap: _hasCustom ? null : _openEditor),
                    const SizedBox(height: 12),
                    _menuLabel('CUSTOMIZE'),
                    _menuAction(Icons.content_copy,
                        'Copy Default Controller', () => _openEditor(copyDefault: true)),
                    _menuAction(Icons.edit, 'Edit Custom Layout', _openEditor),
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

  bool get _hasCustom =>
      (context.read<LayoutStore>().layout?.slots.isNotEmpty ?? false);
}