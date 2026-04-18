import argparse
import socket
import json
import uinput
import threading
import time
from typing import Dict, Any

class PulsePadDaemon:
    def __init__(self, mode: str = 'usb', ip: str = '0.0.0.0'):
        self.mode = mode
        self.ip = ip
        self.port = 5005 if mode == 'usb' else 5006
        self.running = False
        self.device = None
        self.client_socket = None

    def create_virtual_gamepad(self):
        events = (
            uinput.BTN_A, uinput.BTN_B, uinput.BTN_X, uinput.BTN_Y,
            uinput.BTN_TL, uinput.BTN_TR,
            uinput.ABS_X + (-32768, 32767, 0, 128),
            uinput.ABS_Y + (-32768, 32767, 0, 128),
            uinput.ABS_RX + (-32768, 32767, 0, 128),
            uinput.ABS_RY + (-32768, 32767, 0, 128),
            uinput.ABS_Z + (0, 255, 0, 0),
            uinput.ABS_RZ + (0, 255, 0, 0),
        )
        self.device = uinput.Device(events, name='PulsePad-Gamepad')
        print('Virtual gamepad created: /dev/input/js0')

    def map_button(self, button: str) -> int:
        mapping = {
            'A': uinput.BTN_A,
            'B': uinput.BTN_B,
            'X': uinput.BTN_X,
            'Y': uinput.BTN_Y,
            'L1': uinput.BTN_TL,
            'R1': uinput.BTN_TR,
            'L2': uinput.ABS_Z,
            'R2': uinput.ABS_RZ,
        }
        return mapping.get(button, 0)

    def map_axis(self, axis: str) -> int:
        mapping = {
            'LX': uinput.ABS_X,
            'LY': uinput.ABS_Y,
            'RX': uinput.ABS_RX,
            'RY': uinput.ABS_RY,
        }
        return mapping.get(axis, 0)

    def process_input(self, packet: Dict[str, Any]):
        if not self.device:
            return

        buttons = packet.get('buttons', {})
        for btn, value in buttons.items():
            event = self.map_button(btn)
            if event:
                if btn in ['L2', 'R2']:
                    self.device.emit(event, int(value * 255))
                else:
                    self.device.emit(event, value)

        axes = packet.get('axes', {})
        for axis, value in axes.items():
            event = self.map_axis(axis)
            if event:
                self.device.emit(event, int(value * 32767))

    def handle_client(self, client_socket, addr):
        print(f'Client connected: {addr}')
        buffer = b''
        while self.running:
            try:
                data = client_socket.recv(1024)
                if not data:
                    break
                buffer += data
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        packet = json.loads(line.decode())
                        if packet.get('type') == 'INPUT':
                            self.process_input(packet)
                    except json.JSONDecodeError:
                        continue
            except Exception as e:
                print(f'Error: {e}')
                break
        print(f'Client disconnected: {addr}')
        client_socket.close()

    def start(self):
        self.running = True
        self.create_virtual_gamepad()

        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        if self.mode == 'usb':
            server.bind(('127.0.0.1', self.port))
        else:
            server.bind((self.ip, self.port))
        
        server.listen(1)
        print(f'Listening on {"127.0.0.1" if self.mode == "usb" else self.ip}:{self.port}')

        while self.running:
            try:
                server.settimeout(1.0)
                client_socket, addr = server.accept()
                self.client_socket = client_socket
                thread = threading.Thread(target=self.handle_client, args=(client_socket, addr))
                thread.daemon = True
                thread.start()
            except socket.timeout:
                continue
            except Exception as e:
                print(f'Error: {e}')
                break

        server.close()

    def stop(self):
        self.running = False
        if self.client_socket:
            self.client_socket.close()
        print('Daemon stopped')

def main():
    parser = argparse.ArgumentParser(description='PulsePad Daemon')
    parser.add_argument('--mode', choices=['usb', 'wifi'], default='usb', help='Connection mode')
    parser.add_argument('--ip', default='0.0.0.0', help='IP address for Wi-Fi mode')
    args = parser.parse_args()

    daemon = PulsePadDaemon(mode=args.mode, ip=args.ip)
    try:
        daemon.start()
    except KeyboardInterrupt:
        daemon.stop()

if __name__ == '__main__':
    main()