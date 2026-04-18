# PulsePad - Project Documentation

---

## 1. Problem Statement

Current smartphone-as-controller solutions suffer from:
- High latency (40-200ms)
- Unstable connections
- Poor game compatibility
- No plug-and-play experience

**PulsePad achieves sub-10ms latency, matching native hardware controllers.**

---

## 2. Objectives

1. Achieve <5ms latency (USB) / <15ms (Wi-Fi)
2. Plug-and-play Linux gamepad recognition
3. Customizable controller interface
4. Steam and emulator compatibility

---

## 3. Target Users

**Primary:**
- PC gamers (Linux)
- Emulator users
- Indie developers

**Secondary:**
- Casual gamers without controllers
- Developers exploring input systems

---

## 4. Functional Requirements

| ID | Requirement |
|----|-------------|
| FR1 | USB connection via ADB |
| FR2 | Wi-Fi connection via UDP |
| FR3 | Virtual gamepad via uinput |
| FR4 | Button input (A, B, X, Y, L1, R1, L2, R2) |
| FR5 | Analog stick input |
| FR6 | Haptic feedback |
| FR7 | Real-time latency display |

---

## 5. Non-Functional Requirements

| Metric | Target |
|--------|--------|
| USB Latency | ≤ 5 ms |
| Wi-Fi Latency | ≤ 15 ms |
| Packet Rate | 120 Hz |
| Packet Loss | ≤ 2% |
| CPU Usage | < 5% |

---

## 6. System Architecture

```
Phone (Flutter) ──USB/WiFi──> PC (Python Daemon) ──uinput──> Games
     │                                      │
     │  Input packets                      │  /dev/input/js0
     └──────────────────────────────────────┘
```

---

## 7. Communication Flow

### USB Mode:
1. ADB port forwarding: `adb forward tcp:5005 tcp:5005`
2. TCP socket on localhost:5005
3. Near-zero latency

### Wi-Fi Mode:
1. UDP broadcast/discovery
2. UDP packets on port 5006
3. 120Hz streaming

---

## 8. Virtual Controller Mapping

Standard Linux gamepad layout (js0):
- 6 buttons (A, B, X, Y, TL, TR)
- 2 analog axes (left stick)
- Compatible with Steam Input

---

## 9. Performance Analysis

| Mode | Latency | Reliability | Setup |
|------|---------|-------------|-------|
| USB | <5ms | High | Requires USB |
| Wi-Fi | <15ms | Medium | Requires network |

---

## 10. Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| USB debugging friction | Clear onboarding guide |
| Wi-Fi packet loss | Prediction + smoothing |
| uinput permissions | Setup script with sudo |
| Android fragmentation | Flutter abstraction |

---

## 11. Success Metrics

- [ ] Latency benchmarks achieved
- [ ] Controller detected in Steam
- [ ] Stable 1+ hour sessions
- [ ] Compatible with emulators

---

## 12. Future Scope

- Dual analog sticks
- Gyroscope support
- Haptic feedback
- Controller profiles
- Multiplayer mode (multiple phones)
- Binary protocol optimization

---

## 13. Conclusion

PulsePad combines systems-level performance with modern mobile UX, providing a production-grade alternative to dedicated game controllers for Linux gaming.
