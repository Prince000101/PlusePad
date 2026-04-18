#!/usr/bin/env python3
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
        self.device = None
        self.latency = 0
        
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
        self.device = uinput.Device(events, name="PulsePad-Gamepad")
        return True
    
    def map_button(self, button):
        mapping = {'A': uinput.BTN_A, 'B': uinput.BTN_B, 'X': uinput.BTN_X, 'Y': uinput.BTN_Y,
                 'L1': uinput.BTN_TL, 'R1': uinput.BTN_TR, 'L2': uinput.ABS_Z, 'R2': uinput.ABS_RZ}
        return mapping.get(button, 0)
    
    def map_axis(self, axis):
        mapping = {'LX': uinput.ABS_X, 'LY': uinput.ABS_Y, 'RX': uinput.ABS_RX, 'RY': uinput.ABS_RY}
        return mapping.get(axis, 0)
    
    def process_input(self, packet):
        if not self.device: return
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
        print(f"[+] Client connected: {addr}")
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
                        timestamp = packet.get('timestamp', 0)
                        if packet.get('type') == 'INPUT':
                            self.process_input(packet)
                            self.latency = int(time.time() * 1000 - timestamp)
                            print(f"\r[+] Latency: {self.latency}ms", end='', flush=True)
                        elif packet.get('type') == 'HEARTBEAT':
                            pass
                    except: continue
            except socket.timeout: continue
            except Exception as e: break
        print(f"\n[-] Client disconnected: {addr}")
        client_socket.close()
    
    def start(self, mode='wifi', port=5006):
        try:
            self.create_virtual_gamepad()
            print("[+] Virtual gamepad created: /dev/input/js0")
        except Exception as e:
            print(f"[!] Error: {e}")
            print("[!] Run with: sudo python3 pulsedad_daemon.py")
            sys.exit(1)
        
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(('0.0.0.0', port))
        self.server.listen(1)
        self.running = True
        
        print(f"[+] Listening on 0.0.0.0:{port}")
        print("[+] Waiting for phone connection...")
        
        while self.running:
            try:
                self.server.settimeout(1.0)
                client_socket, addr = self.server.accept()
                self.client_socket = client_socket
                print(f"\n[+] Phone connected: {addr}")
                thread = threading.Thread(target=self.handle_client, args=(client_socket, addr))
                thread.daemon = True
                thread.start()
            except socket.timeout: continue
            except KeyboardInterrupt:
                self.stop()
                break
            except Exception as e:
                print(f"[!] Error: {e}")
                break
    
    def stop(self):
        self.running = False
        if self.client_socket: self.client_socket.close()
        if self.server: self.server.close()
        print("\n[+] Server stopped")

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', choices=['usb', 'wifi'], default='wifi')
    parser.add_argument('--ip', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=5006)
    args = parser.parse_args()
    
    daemon = PulsePadDaemon()
    try:
        daemon.start(args.mode, args.port)
    except KeyboardInterrupt:
        daemon.stop()