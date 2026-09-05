import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../models/packet.dart';
import '../services/connection_manager.dart';
import '../models/control_slot.dart';
import '../services/layout_store.dart';
import '../theme/app_theme.dart';
import '../widgets/analog_stick.dart';
import '../widgets/action_buttons.dart';
import '../widgets/dpad.dart';
import 'layout_editor_screen.dart';
import 'settings_screen.dart';

/// Full-screen controller designed for a phone held LANDSCAPE (like a Steam
/// Deck / Steam Controller). It auto-rotates to landscape on entry, runs
/// full-bleed (maximised controls, no task/status bar) and hides all chrome
/// behind a single small floating menu button.
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with TickerProviderStateMixin {
  ControllerLayout _currentLayout = ControllerLayout.gamepad;
  bool _dpadMode = false;
  bool _menuOpen = false;
  int _mouseButtons = 0;
  Offset? _touchLast;

  @override
  void initState() {
    super.initState();
    // Landscape-first: lock to horizontal and go immersive (no status/nav bar).
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  ConnectionManager _cm() => context.read<ConnectionManager>();

  // ------------------------------- inputs ------------------------------ //
  void _setButton(String name, bool pressed) {
    final cm = _cm();
    final c = cm.controller;
    var changed = c.setButton(name, pressed);
    if (name == 'L2' || name == 'R2') {
      // Bumpers are digital taps, but also drive the analog trigger axis so
      // analog-aware games see the full 0..255 range on ABS_Z/ABS_RZ.
      changed = c.setTrigger(name, pressed ? 1.0 : 0.0) || changed;
    }
    if (changed) cm.pushState();
  }

  void _sendKey(String name, bool pressed) => _cm().sendKey(name, pressed);

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Background(
        // Full-bleed: no SafeArea so the controls fill the whole screen.
        child: Stack(
          children: [
            SizedBox.expand(child: _buildCurrentLayout()),
            // Overlay: menu button + latency.
            Positioned(
              top: 8,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMenuButton(),
                    const SizedBox(width: 8),
                    _buildLatencyPill(),
                  ],
                ),
              ),
            ),
            if (_menuOpen) Positioned.fill(child: _buildMenuOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLayout() {
    switch (_currentLayout) {
      case ControllerLayout.psp:
        return _buildPSPLayout();
      case ControllerLayout.ps5:
        return _buildPS5Layout();
      case ControllerLayout.mouse:
        return _buildMouseLayout();
      case ControllerLayout.keyboard:
        return _buildKeyboardLayout();
      case ControllerLayout.simple:
        return _buildSimpleLayout();
      case ControllerLayout.pro:
        return _buildProLayout();
      case ControllerLayout.custom:
        return _buildCustomLayout();
      case ControllerLayout.gamepad:
      default:
        return _buildSteamDeckLayout();
    }
  }

  // ---------------- Steam Deck-inspired landscape gamepad ---------------- //
  // Left grip: D-pad (top) + left stick (below). Right grip: ABXY (top) +
  // right stick (below). Symmetric like the Steam Deck, full-bleed.
  Widget _buildSteamDeckLayout() {
    // Half the width for each grip; controls sized to available space.
    final media = MediaQuery.of(context).size;
    final topControl = (media.height * 0.44).clamp(90.0, 220.0);
    final bottomControl = (media.height * 0.38).clamp(80.0, 190.0);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 88, 8, 8),
          child: Row(
            children: [
              // ---- Left grip ----
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dpadMode
                        ? DPad(onChanged: _dpad, size: topControl)
                        : AnalogStick(
                            size: topControl,
                            onChanged: (x, y) {
                              _setAxis('LX', x);
                              _setAxis('LY', y);
                            }),
                    const Spacer(),
                    AnalogStick(
                      size: bottomControl,
                      onChanged: (x, y) {
                        _setAxis('LX', x);
                        _setAxis('LY', y);
                      },
                    ),
                  ],
                ),
              ),
              // ---- Center controls ----
              SizedBox(
                width: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pill('SELECT'),
                    const SizedBox(height: 14),
                    _pill('START'),
                  ],
                ),
              ),
              // ---- Right grip ----
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Center(
                      child: ActionButtons(
                        onPressed: (b) => _setButton(b, true),
                        onReleased: (b) => _setButton(b, false),
                      ),
                    ),
                    const Spacer(),
                    AnalogStick(
                      size: bottomControl,
                      onChanged: (x, y) {
                        _setAxis('RX', x);
                        _setAxis('RY', y);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Steam-Deck style bumpers sit along the top edge of each grip.
        Positioned(top: 8, left: 16,
            child: _cornerBumpers(const ['L1', 'L2'], left: true)),
        Positioned(top: 8, right: 16,
            child: _cornerBumpers(const ['R2', 'R1'], left: false)),
      ],
    );
  }

  /// A compact pair of shoulder bumpers for one grip corner. Steam-style:
  /// large targets with tactile press feedback.
  Widget _cornerBumpers(List<String> labels, {required bool left}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: labels.map((l) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _Bumper(label: l, onChanged: _setButton),
        );
      }).toList(),
    );
  }

  Widget _pill(String label) {
    return _PillButton(label: label, onChanged: _setButton);
  }

  // ---------------------------- Simple layout -------------------------- //
  // Big, few controls — best for casual users. Just two sticks, a D-pad and
  // the face buttons, sized large and placed for easy thumbs.
  Widget _buildSimpleLayout() {
    final media = MediaQuery.of(context).size;
    final big = (media.height * 0.42).clamp(90.0, 200.0);
    final face = (media.height * 0.3).clamp(70.0, 150.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 64, 8, 12),
      child: Stack(
        children: [
          // Left stick (large).
          Positioned(
            left: media.width * 0.02,
            top: 0,
            child: AnalogStick(
              size: big,
              onChanged: (x, y) {
                _setAxis('LX', x);
                _setAxis('LY', y);
              },
            ),
          ),
          // Right side: big ABXY cluster.
          Positioned(
            right: media.width * 0.02,
            top: 0,
            child: ClipOval(
              child: SizedBox(
                width: face + 40,
                height: face + 40,
                child: Center(
                  child: ActionButtons(
                    onPressed: (b) => _setButton(b, true),
                    onReleased: (b) => _setButton(b, false),
                  ),
                ),
              ),
            ),
          ),
          // D-pad bottom-left.
          Positioned(
            left: media.width * 0.08,
            bottom: 4,
            child: DPad(onChanged: _dpad, size: media.height * 0.32),
          ),
          // Right stick bottom-right.
          Positioned(
            right: media.width * 0.06,
            bottom: 4,
            child: AnalogStick(
              size: media.height * 0.36,
              onChanged: (x, y) {
                _setAxis('RX', x);
                _setAxis('RY', y);
              },
            ),
          ),
          // SELECT / START mini group centre.
          Positioned(
            right: media.width * 0.50,
            bottom: media.height * 0.02,
            child: Row(
              children: [
                _pill('SELECT'),
                const SizedBox(width: 10),
                _pill('START'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------ Pro layout --------------------------- //
  // Everything, laid out like a premium pad: two sticks, D-pad, ABXY, L/R1/L2
  // bumpers and triggers, plus L3/R3 and extra shoulders.
  Widget _buildProLayout() {
    final media = MediaQuery.of(context).size;
    final grip = (media.height * 0.34).clamp(80.0, 165.0);

    return Stack(
      children: [
        // Top bumpers + triggers.
        Positioned(top: 8, left: 16, child: _cornerBumpers(const ['L1', 'L2'], left: true)),
        Positioned(top: 8, right: 16, child: _cornerBumpers(const ['R2', 'R1'], left: false)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 88, 8, 24),
          child: Row(
            children: [
              // Left grip: D-pad (top) + left stick (below).
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dpadMode
                        ? DPad(onChanged: _dpad, size: grip)
                        : AnalogStick(
                            size: grip,
                            onChanged: (x, y) {
                              _setAxis('LX', x);
                              _setAxis('LY', y);
                            }),
                    const Spacer(),
                    AnalogStick(
                      size: grip,
                      onChanged: (x, y) {
                        _setAxis('LX', x);
                        _setAxis('LY', y);
                      },
                    ),
                  ],
                ),
              ),
              // Centre: SELECT / START + L3 / R3.
              SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pill('L3'),
                    const SizedBox(height: 10),
                    _pill('SELECT'),
                    const SizedBox(height: 10),
                    _pill('START'),
                    const SizedBox(height: 10),
                    _pill('R3'),
                  ],
                ),
              ),
              // Right grip: face (top) + right stick (below).
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Center(
                      child: ActionButtons(
                        onPressed: (b) => _setButton(b, true),
                        onReleased: (b) => _setButton(b, false),
                      ),
                    ),
                    const Spacer(),
                    AnalogStick(
                      size: grip,
                      onChanged: (x, y) {
                        _setAxis('RX', x);
                        _setAxis('RY', y);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------- Custom layout --------------------------- //
  // Renders the user's saved custom layout (from the visual editor). Controls
  // are positioned/sized by normalised fractions of the screen.
  Widget _buildCustomLayout() {
    final layout = context.watch<LayoutStore>().layout;
    if (layout == null || layout.slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline,
                size: 48, color: AppTheme.accentB),
            const SizedBox(height: 12),
            Text('No custom layout yet',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openEditor,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.4),
                ),
                child: const Text('Open Editor',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
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
          size: 100,
          onChanged: (x, y) {
            _setAxis(isRight ? 'RX' : 'LX', x);
            _setAxis(isRight ? 'RY' : 'LY', y);
          },
        );
      case 'dpad':
        return DPad(onChanged: _dpad);
      default:
        final action = s.action.isEmpty ? s.label : s.action;
        return _customButton(s.label, action);
    }
  }

  Widget _customButton(String label, String action) {
    return GestureDetector(
      onTapDown: (_) => _setButton(action, true),
      onTapUp: (_) => _setButton(action, false),
      onTapCancel: () => _setButton(action, false),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x337F86FD), Color(0x886366F1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.hairline, width: 1.2),
          boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.25),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    );
  }

  void _openEditor() {
    final store = context.read<LayoutStore>();
    final existing = store.layout;
    final working = existing != null
        ? CustomLayout(name: 'My Custom', slots: existing.slots)
        : _defaultCustomLayout();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LayoutEditorScreen(layout: working)),
    );
    setState(() => _menuOpen = false);
  }

  CustomLayout _defaultCustomLayout() {
    return CustomLayout(name: 'My Custom', slots: [
      ControlSlot(id: 'a', kind: 'button', x: 0.78, y: 0.32, w: 0.10, h: 0.14, label: 'A', action: 'A'),
      ControlSlot(id: 'b', kind: 'button', x: 0.86, y: 0.50, w: 0.10, h: 0.14, label: 'B', action: 'B'),
      ControlSlot(id: 'x', kind: 'button', x: 0.86, y: 0.16, w: 0.10, h: 0.14, label: 'X', action: 'X'),
      ControlSlot(id: 'y', kind: 'button', x: 0.78, y: 0.66, w: 0.10, h: 0.14, label: 'Y', action: 'Y'),
      ControlSlot(id: 'd', kind: 'dpad', x: 0.16, y: 0.5, w: 0.22, h: 0.45, label: 'D-PAD', action: 'DPAD'),
      ControlSlot(id: 's', kind: 'stick', x: 0.84, y: 0.78, w: 0.18, h: 0.32, label: 'STICK', action: 'RX/RY'),
      ControlSlot(id: 'sel', kind: 'button', x: 0.45, y: 0.78, w: 0.10, h: 0.10, label: 'SELECT', action: 'SELECT'),
      ControlSlot(id: 'sta', kind: 'button', x: 0.55, y: 0.78, w: 0.10, h: 0.10, label: 'START', action: 'START'),
    ]);
  }

  // ---------------------------- PSP layout ---------------------------- //
  Widget _buildPSPLayout() {
    final media = MediaQuery.of(context).size;
    final ctrl = (media.height * 0.42).clamp(90.0, 200.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 64, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DPad(onChanged: _dpad, size: ctrl),
                const SizedBox(height: 14),
                _pill('L3'),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pill('SELECT'),
                const SizedBox(height: 14),
                _pill('START'),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionButtons(
                  onPressed: (b) => _setButton(b, true),
                  onReleased: (b) => _setButton(b, false),
                ),
                const SizedBox(height: 14),
                AnalogStick(
                  size: (media.height * 0.3).clamp(70.0, 150.0),
                  onChanged: (x, y) {
                    _setAxis('RX', x);
                    _setAxis('RY', y);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------- PS5 layout ---------------------------- //
  Widget _buildPS5Layout() {
    final media = MediaQuery.of(context).size;
    final ctrl = (media.height * 0.4).clamp(85.0, 190.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 64, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dpadMode
                    ? DPad(onChanged: _dpad, size: ctrl)
                    : AnalogStick(
                        size: ctrl,
                        onChanged: (x, y) {
                          _setAxis('LX', x);
                          _setAxis('LY', y);
                        }),
                const SizedBox(height: 14),
                AnalogStick(
                  size: ctrl * 0.8,
                  onChanged: (x, y) {
                    _setAxis('LX', x);
                    _setAxis('LY', y);
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pill('SELECT'),
                const SizedBox(height: 14),
                _pill('START'),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionButtons(
                  onPressed: (b) => _setButton(b, true),
                  onReleased: (b) => _setButton(b, false),
                ),
                const SizedBox(height: 14),
                AnalogStick(
                  size: ctrl * 0.8,
                  onChanged: (x, y) {
                    _setAxis('RX', x);
                    _setAxis('RY', y);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------- Mouse layout --------------------------- //
  Widget _buildMouseLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 64, 8, 24),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (d) {
                setState(() => _mouseButtons = _mouseButtons | 0x01);
                _touchLast = d.localPosition;
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
                decoration: AppTheme.glass(radius: 24),
                child: const Center(
                  child: Text('Touchpad Area',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill('SELECT'),
              const SizedBox(width: 16),
              _pill('START'),
              const SizedBox(width: 16),
              _mouseButtonPill('LMB', 1),
              const SizedBox(width: 16),
              _mouseButtonPill('RMB', 2),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMouseDelta(Offset delta) {
    final dx = (delta.dx * 3).round().clamp(-127, 127);
    final dy = (delta.dy * 3).round().clamp(-127, 127);
    if (dx == 0 && dy == 0) return;
    _cm().sendMouse(dx, dy, _mouseButtons);
  }

  Widget _mouseButtonPill(String label, int bit) {
    final active = (_mouseButtons & bit) != 0;
    return GestureDetector(
      onTap: () {
        setState(() => _mouseButtons ^= bit);
        _cm().sendMouse(0, 0, _mouseButtons);
      },
      child: Container(
        width: 52,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.accentA.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: active ? AppTheme.accentB : AppTheme.hairline,
              width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 8,
                color: Colors.white.withOpacity(active ? 1 : 0.7),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      ),
    );
  }

  // -------------------------- Keyboard layout ------------------------- //
  Widget _buildKeyboardLayout() {
    final media = MediaQuery.of(context).size;
    final keys = ['W', 'A', 'S', 'D', 'SPACE', 'SHIFT', 'CTRL', 'ENTER', 'ESC'];
    final keySize = (media.height * 0.24).clamp(60.0, 120.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 64, 8, 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: keys
            .map((k) => _buildKeyboardKey(k, keySize))
            .toList(),
      ),
    );
  }

  Widget _buildKeyboardKey(String key, double size) {
    return GestureDetector(
      onTapDown: (_) => _sendKey(key, true),
      onTapUp: (_) => _sendKey(key, false),
      onTapCancel: () => _sendKey(key, false),
      child: Container(
        width: size,
        height: size,
        decoration: AppTheme.glass(radius: 14),
        child: Center(
          child: Text(key,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --------------------------- Menu / chrome -------------------------- //
  Widget _buildMenuButton() {
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = !_menuOpen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _menuOpen
              ? AppTheme.accentGradient
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x1AFFFFFF), Color(0x0AFFFFFF)],
                ),
          border: Border.all(
              color: _menuOpen ? AppTheme.accentB : AppTheme.hairline, width: 1.2),
          boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.35),
        ),
        child: Icon(_menuOpen ? Icons.close : Icons.menu,
            color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildLatencyPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Consumer<ConnectionManager>(
        builder: (context, manager, _) => Row(
          children: [
            Icon(manager.mode == ConnectionMode.usb ? Icons.usb : Icons.wifi,
                size: 14, color: AppTheme.green),
            const SizedBox(width: 6),
            Text('${manager.latency}ms',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.green,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = false),
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 60),
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B2436).withOpacity(0.97),
                  const Color(0xFF10162B).withOpacity(0.97),
                ],
              ),
              border: Border.all(color: AppTheme.hairline),
              boxShadow: AppTheme.glow(AppTheme.accentA, opacity: 0.25,
                  blur: 30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('CONTROLS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentB)),
                const SizedBox(height: 12),
                _menuLabel('STYLES'),
                _menuRow(Icons.favorite, 'Simple', ControllerLayout.simple),
                _menuRow(Icons.gamepad, 'Gamepad', ControllerLayout.gamepad),
                _menuRow(Icons.military_tech, 'Pro', ControllerLayout.pro),
                _menuRow(Icons.videogame_asset, 'PSP', ControllerLayout.psp),
                _menuRow(Icons.sports_esports, 'PS5', ControllerLayout.ps5),
                _menuRow(Icons.mouse, 'Mouse', ControllerLayout.mouse),
                _menuRow(Icons.keyboard, 'Keyboard', ControllerLayout.keyboard),
                _menuRow(Icons.tune, 'My Custom',
                    ControllerLayout.custom, enabled: _hasCustom),
                const SizedBox(height: 12),
                _menuLabel('CUSTOMIZE'),
                _menuAction(Icons.edit, 'Edit Custom Layout', _openEditor),
                const SizedBox(height: 12),
                _menuToggle(
                  icon: Icons.grid_on,
                  label: _dpadMode ? 'D-Pad (left grip)' : 'Stick (left grip)',
                  value: _dpadMode,
                  onChanged: (v) => setState(() => _dpadMode = v),
                ),
                const SizedBox(height: 4),
                _menuAction(Icons.settings, 'Settings', () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),
                const SizedBox(height: 8),
                _menuAction(Icons.exit_to_app, 'Disconnect', _exit,
                    color: AppTheme.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, ControllerLayout layout,
      {bool enabled = true}) {
    final active = _currentLayout == layout;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled
            ? () {
                setState(() {
                  _currentLayout = layout;
                  _menuOpen = false;
                });
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accentA.withOpacity(0.2)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? AppTheme.accentB : Colors.transparent,
                width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20,
                  color: active
                      ? AppTheme.accentB
                      : enabled
                          ? Colors.white60
                          : Colors.white30),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: active
                          ? Colors.white
                          : enabled
                              ? Colors.white70
                              : Colors.white30,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400)),
              const Spacer(),
              if (active)
                const Icon(Icons.check, size: 18, color: AppTheme.accentB),
              if (!enabled && !active)
                Text(layout == ControllerLayout.custom ? 'Build one' : 'Soon',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white38)),
    );
  }

  bool get _hasCustom =>
      (context.read<LayoutStore>().layout?.slots.isNotEmpty ?? false);

  Widget _menuToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white60),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.accentA),
        ],
      ),
    );
  }

  Widget _menuAction(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bumper extends StatefulWidget {
  final String label;
  final void Function(String, bool) onChanged;

  const _Bumper({required this.label, required this.onChanged});

  @override
  State<_Bumper> createState() => _BumperState();
}

class _BumperState extends State<_Bumper> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    widget.onChanged(widget.label, v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: 68,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: _pressed
                ? AppTheme.accentGradient
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2C3A54), Color(0xFF151C2E)]),
            border: Border.all(
              color: _pressed ? AppTheme.accentB : AppTheme.hairline,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
              if (_pressed)
                BoxShadow(
                  color: AppTheme.accentA.withOpacity(0.35),
                  blurRadius: 16,
                ),
            ],
          ),
          child: Text(widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _pressed ? Colors.white : Colors.white70,
              )),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final String label;
  final void Function(String, bool) onChanged;

  const _PillButton({required this.label, required this.onChanged});

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    widget.onChanged(widget.label, v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: 52,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: _pressed ? AppTheme.accentGradient : null,
            color: _pressed ? null : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _pressed ? AppTheme.accentB : AppTheme.hairline,
              width: 1.2,
            ),
          ),
          child: Text(widget.label,
              style: TextStyle(
                fontSize: 8,
                color: _pressed ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              )),
        ),
      ),
    );
  }
}
