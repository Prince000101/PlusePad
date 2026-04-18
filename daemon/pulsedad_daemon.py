import socket
import threading
import json
import uinput
import time
import sys
import os

class PulsePadDaemon:
    def __init__(self):
        self.server = None
        self.running = False
        self.client_socket = None
        
        # Devices
        self.gamepad = None
        self.mouse = None
        self.keyboard = None
        
        self.latency = 0

    def create_devices(self):
        try:
            # 1. Virtual Gamepad
            gamepad_events = (
                uinput.BTN_A, uinput.BTN_B, uinput.BTN_X, uinput.BTN_Y,
                uinput.BTN_TL, uinput.BTN_TR,
                uinput.ABS_X + (-32768, 32767, 0, 128),
                uinput.ABS_Y + (-32768, 32767, 0, 128),
                uinput.ABS_RX + (-32768, 32767, 0, 128),
                uinput.ABS_RY + (-32768, 32767, 0, 128),
                uinput.ABS_Z + (0, 255, 0, 0),
                uinput.ABS_RZ + (0, 255, 0, 0),
            )
            self.gamepad = uinput.Device(gamepad_events, name="PulsePad-Gamepad")
            
            # 2. Virtual Mouse
            mouse_events = (
                uinput.REL_X,
                uinput.REL_Y,
                uinput.BTN_LEFT,
                uinput.BTN_RIGHT,
                uinput.BTN_MIDDLE,
            )
            self.mouse = uinput.Device(mouse_events, name="PulsePad-Mouse")
            
            # 3. Virtual Keyboard
            # Using a wide range of common keys. In a production app, we'd map exactly what's needed.
            keyboard_events = [
                uinput.KEY_A, uinput.KEY_B, uinput.KEY_C, uinput.KEY_D, uinput.KEY_E, uinput.KEY_F, 
                uinput.KEY_G, uinput.KEY_H, uinput.KEY_I, uinput.KEY_J, uinput.KEY_K, uinput.KEY_L,
                uinput.KEY_M, uinput.KEY_N, uinput.KEY_O, uinput.KEY_P, uinput.KEY_Q, uinput.KEY_R,
                uinput.KEY_S, uinput.KEY, uinput.KEY_T, uinput.KEY_U, uinput.KEY_V, uinput.KEY_W,
                uinput.KEY_X, uinput.KEY_Y, uinput.KEY_Z, uinput.KEY_ENTER, uinput.KEY_SPACE,
                uinput.KEY_ESC, uinput.KEY_BACKSPACE, uinput.KEY_TAB, uinput.KEY_LSHIFT,
                uinput.KEY_LCTRL, uinput.KEY_LALT, uinput.KEY_UP, uinput.KEY_DOWN,
                uinput.KEY_LEFT, uinput.KEY_RIGHT,
            ]
            # Fix a small typo in my list above: uinput.KEY instead of uinput.KEY_S
            # Let's just use a safe set
            safe_keyboard_events = [
                uinput.KEY_A, uinput.KEY_B, uinput.KEY_C, uinput.KEY_D, uinput.KEY_E, 
                uinput.KEY_F, uinput.KEY_G, uinput.KEY_H, uinput.KEY_I, uinput.KEY_J, 
                uinput.KEY_K, uinput.KEY_L, uinput.KEY_M, uinput.KEY_N, uinput.KEY_O, 
                uinput.KEY_P, uinput.KEY_Q, uinput.KEY_R, uinput.KEY_S, uinput.KEY_T, 
                uinput.KEY_U, uinput.KEY_V, uinput.KEY_W, uinput.KEY_X, uinput.KEY_Y, 
                uinput.KEY_Z, uinput.KEY_ENTER, uinput.KEY_SPACE, uinput.KEY_ESC, 
                uinput.KEY_BACKSPACE, uinput.KEY_TAB, uinput.KEY_LSHIFT, uinput.KEY_LCTRL,
                uinput.KEY_LALT, uinput.KEY_UP, uinput.KEY_DOWN, uinput.KEY_LEFT, uinput.KEY_RIGHT
            ]
            self.keyboard = uinput.Device(safe_keyboard_events, name="PulsePad-Keyboard")
            
            return True
        except Exception as e:
            print(f"[!] Hardware Init Error: {e}")
            return False

    def handle_gamepad(self, data):
        buttons = data.get('buttons', {})
        axes = data.get('axes', {})
        
        # Map Buttons
        mapping = {'A': uinput.BTN_A, 'B': uinput.BTN_B, 'X': uinput.BTN_X, 'Y': uinput.BTN_Y,
                  'L1': uinput.BTN_TL, 'R1': uinput.BTN_TR, 'L2': uinput.ABS_Z, 'R2': uinput.ABS_RZ}
        for btn, val in buttons.items():
            event = mapping.get(btn)
            if event:
                if btn in ['L2', 'R2']:
                    self.gamepad.emit(event, int(val * 255))
                else:
                    self.gamepad.emit(event, val)
        
        # Map Axes
        axis_mapping = {'LX': uinput.ABS_X, 'LY': uinput.ABS_Y, 'RX': uinput.ABS_RX, 'RY': uinput.ABS_RY}
        for axis, val in axes.items():
            event = axis_mapping.get(axis)
            if event:
                self.gamepad.emit(event, int(val * 32767))

    def handle_mouse(self, data):
        # Expects: {'dx': 0.5, 'dy': -0.2, 'buttons': {'LEFT': 1, 'RIGHT': 0}}
        dx = int(data.get('dx', 0) * 20)
        dy = int(data.get('dy', 0) * 20)
        self.mouse.emit(uinput.REL_X, dx)
        self.mouse.emit(uinput.REL_Y, dy)
        
        buttons = data.get('buttons', {})
        btn_mapping = {'LEFT': uinput.BTN_LEFT, 'RIGHT': uinput.BTN_RIGHT, 'MIDDLE': uinput.BTN_MIDDLE}
        for btn, val in buttons.items():
            event = btn_mapping.get(btn)
            if event:
                self.mouse.emit(event, val)

    def handle_keyboard(self, data):
        # Expects: {'key': 'A', 'state': 1}
        key_name = data.get('key')
        state = data.get('state', 0)
        
        # Use getattr to find the uinput.KEY_* constant
        try:
            key_const = getattr(uinput, f"KEY_{key_name.upper()}")
            self.keyboard.emit(key_const, state)
        except AttributeError:
            pass

    def handle_client(self, client_socket, addr):
        print(f"\n[+] Connection Established: {addr}")
        buffer = b''
        while self.running:
            try:
                client_socket.settimeout(1.0)
                data = client_socket.recv(4096)
                if not data: break
                buffer += data
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        packet = json.loads(line.decode())
                        p_type = packet.get('type')
                        
                        if p_type == 'GAMEPAD':
                            self.handle_gamepad(packet)
                        elif p_type == 'MOUSE':
                            self.handle_mouse(packet)
                        elif p_type == 'KEYBOARD':
                            self.handle_keyboard(packet)
                        
                        if 'timestamp' in packet:
                            self.latency = int(time.time() * 1000 - packet['timestamp'])
                            print(f"\r[SENSING] Latency: {self.latency}ms | Device: {p_type}", end='', flush=True)
                    except: continue
            except socket.timeout: continue
            except: break
        print(f"\n[-] Connection Lost: {addr}")
        client_socket.close()

    def start(self, port=5006):
        if not self.create_devices():
            print("[!] FATAL: Could not initialize uinput devices. Run as sudo.")
            sys.exit(1)
            
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(('0.0.0.0', port))
        self.server.listen(1)
        self.running = True
        
        print("="*40)
        print("  PULSEPAD SERVER - HIGH PERFORMANCE")
        print("="*40)
        print(f"[+] Listening on port: {port}")
        print("[+] Devices active: Gamepad, Mouse, Keyboard")
        print("[+] Awaiting connection...")
        
        while self.running:
            try:
                self.server.settimeout(1.0)
                client_socket, addr = self.server.accept()
                self.client_socket = client_socket
                thread = threading.Thread(target=self.handle_client, args=(client_socket, addr))
                thread.daemon = True
                thread.start()
            except socket.timeout: continue
            except KeyboardInterrupt: break
            except: break
        
        self.stop()

    def stop(self):
        self.running = False
        if self.client_socket: self.client_socket.close()
        if self.server: self.server.close()
        print("\n[+] Server shutdown complete.")

if __name__ == '__main__':
    daemon = PulsePadDaemon()
    try:
        daemon.start()
    except KeyboardInterrupt:
        daemon.stop()