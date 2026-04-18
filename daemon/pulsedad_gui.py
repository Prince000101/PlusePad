import tkinter as tk
from tkinter import ttk, messagebox
import socket
import threading
import json
import uinput
import time

class PulsePadGUI:
    def __init__(self):
        self.window = tk.Tk()
        self.window.title("PulsePad Controller")
        self.window.geometry("400x500")
        self.window.configure(bg="#0F172A")
        
        self.style = ttk.Style()
        self.style.theme_use("clam")
        
        self.server = None
        self.running = False
        self.client_socket = None
        self.device = None
        self.latency = 0
        self.last_ping = 0
        
        self._setup_ui()
        
    def _setup_ui(self):
        title = tk.Label(
            self.window,
            text="PulsePad",
            font=("Arial", 24, "bold"),
            bg="#0F172A",
            fg="#6366F1"
        )
        title.pack(pady=20)
        
        mode_frame = tk.LabelFrame(
            self.window,
            text="Connection Mode",
            bg="#0F172A",
            fg="white",
            font=("Arial", 10)
        )
        mode_frame.pack(pady=10, padx=20, fill="x")
        
        self.mode_var = tk.StringVar(value="wifi")
        
        ttk.Radiobutton(
            mode_frame,
            text="USB (via ADB)",
            variable=self.mode_var,
            value="usb",
            style="TRadiobutton"
        ).pack(anchor="w", padx=10, pady=5)
        
        ttk.Radiobutton(
            mode_frame,
            text="Wi-Fi",
            variable=self.mode_var,
            value="wifi",
            style="TRadiobutton"
        ).pack(anchor="w", padx=10, pady=5)
        
        ip_frame = tk.LabelFrame(
            self.window,
            text="Wi-Fi Settings",
            bg="#0F172A",
            fg="white",
            font=("Arial", 10)
        )
        ip_frame.pack(pady=10, padx=20, fill="x")
        
        tk.Label(ip_frame, text="Phone IP:", bg="#0F172A", fg="white").pack(anchor="w", padx=10, pady=2)
        
        self.phone_ip = tk.Entry(ip_frame, bg="#1E293B", fg="white", insertbackground="white")
        self.phone_ip.pack(fill="x", padx=10, pady=5)
        
        tk.Label(ip_frame, text="Server Port:", bg="#0F172A", fg="white").pack(anchor="w", padx=10, pady=2)
        
        self.port_entry = tk.Entry(ip_frame, bg="#1E293B", fg="white", insertbackground="white")
        self.port_entry.insert(0, "5006")
        self.port_entry.pack(fill="x", padx=10, pady=5)
        
        status_frame = tk.LabelFrame(
            self.window,
            text="Status",
            bg="#0F172A",
            fg="white",
            font=("Arial", 10)
        )
        status_frame.pack(pady=10, padx=20, fill="x")
        
        self.status_label = tk.Label(
            status_frame,
            text="Disconnected",
            bg="#0F172A",
            fg="#EF4444",
            font=("Arial", 12, "bold")
        )
        self.status_label.pack(pady=10)
        
        self.latency_label = tk.Label(
            status_frame,
            text="Latency: -- ms",
            bg="#0F172A",
            fg="white",
            font=("Arial", 10)
        )
        self.latency_label.pack(pady=5)
        
        button_frame = tk.Frame(self.window, bg="#0F172A")
        button_frame.pack(pady=20)
        
        self.start_btn = tk.Button(
            button_frame,
            text="START SERVER",
            bg="#6366F1",
            fg="white",
            font=("Arial", 12, "bold"),
            command=self._start_server,
            width=15,
            height=2
        )
        self.start_btn.pack(side="left", padx=5)
        
        self.stop_btn = tk.Button(
            button_frame,
            text="STOP",
            bg="#EF4444",
            fg="white",
            font=("Arial", 12, "bold"),
            command=self._stop_server,
            width=10,
            height=2,
            state="disabled"
        )
        self.stop_btn.pack(side="left", padx=5)
        
    def _create_virtual_gamepad(self):
        try:
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
            self._log("Virtual gamepad created: /dev/input/js0")
            return True
        except Exception as e:
            self._log(f"Error creating gamepad: {e}")
            return False
    
    def _map_button(self, button):
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
    
    def _map_axis(self, axis):
        mapping = {
            'LX': uinput.ABS_X,
            'LY': uinput.ABS_Y,
            'RX': uinput.ABS_RX,
            'RY': uinput.ABS_RY,
        }
        return mapping.get(axis, 0)
    
    def _process_input(self, packet):
        if not self.device:
            return
        
        buttons = packet.get('buttons', {})
        for btn, value in buttons.items():
            event = self._map_button(btn)
            if event:
                if btn in ['L2', 'R2']:
                    self.device.emit(event, int(value * 255))
                else:
                    self.device.emit(event, value)
        
        axes = packet.get('axes', {})
        for axis, value in axes.items():
            event = self._map_axis(axis)
            if event:
                self.device.emit(event, int(value * 32767))
    
    def _handle_client(self, client_socket, addr):
        self._log(f"Client connected: {addr}")
        buffer = b''
        
        while self.running:
            try:
                client_socket.settimeout(1.0)
                data = client_socket.recv(4096)
                if not data:
                    break
                buffer += data
                
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        packet = json.loads(line.decode())
                        timestamp = packet.get('timestamp', 0)
                        
                        if packet.get('type') == 'INPUT':
                            self._process_input(packet)
                            self.last_ping = time.time() * 1000
                            self.latency = int(time.time() * 1000 - timestamp)
                            self.window.after(0, self._update_latency)
                        elif packet.get('type') == 'HEARTBEAT':
                            self.last_ping = time.time() * 1000
                    except json.JSONDecodeError:
                        continue
            except socket.timeout:
                continue
            except Exception as e:
                self._log(f"Error: {e}")
                break
        
        self._log(f"Client disconnected: {addr}")
        client_socket.close()
        self.window.after(0, self._client_disconnected)
    
    def _update_latency(self):
        self.latency_label.config(text=f"Latency: {self.latency} ms")
    
    def _client_connected(self):
        self.status_label.config(text="Connected", fg="#22C55E")
    
    def _client_disconnected(self):
        self.status_label.config(text="Waiting for connection...", fg="#F59E0B")
    
    def _log(self, message):
        print(f"[PulsePad] {message}")
    
    def _start_server(self):
        mode = self.mode_var.get()
        port = int(self.port_entry.get())
        
        self._log(f"Starting {mode} server on port {port}...")
        
        if not self._create_virtual_gamepad():
            messagebox.showerror("Error", "Failed to create virtual gamepad.\nRun with sudo!")
            return
        
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        try:
            self.server.bind(('0.0.0.0', port))
            self.server.listen(1)
            self.running = True
            
            self.start_btn.config(state="disabled")
            self.stop_btn.config(state="normal")
            self.status_label.config(text="Waiting for connection...", fg="#F59E0B")
            
            thread = threading.Thread(target=self._accept_clients)
            thread.daemon = True
            thread.start()
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to start server: {e}")
            return
    
    def _accept_clients(self):
        while self.running:
            try:
                self.server.settimeout(1.0)
                client_socket, addr = self.server.accept()
                self.client_socket = client_socket
                self.window.after(0, self._client_connected)
                thread = threading.Thread(target=self._handle_client, args=(client_socket, addr))
                thread.daemon = True
                thread.start()
            except socket.timeout:
                continue
            except Exception as e:
                self._log(f"Server error: {e}")
                break
    
    def _stop_server(self):
        self._log("Stopping server...")
        self.running = False
        
        if self.client_socket:
            self.client_socket.close()
        if self.server:
            self.server.close()
        
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.status_label.config(text="Disconnected", fg="#EF4444")
        self.latency_label.config(text="Latency: -- ms")
    
    def run(self):
        self.window.mainloop()

def main():
    app = PulsePadGUI()
    app.run()

if __name__ == "__main__":
    main()