import tkinter as tk
from tkinter import ttk, messagebox
import threading
from pulsedad_daemon import PulsePadDaemon

class PulsePadGUI:
    def __init__(self):
        self.window = tk.Tk()
        self.window.title("PulsePad Controller")
        self.window.geometry("450x600")
        self.window.configure(bg="#0F172A")
        
        self.daemon = PulsePadDaemon()
        
        self._setup_ui()
        
    def _setup_ui(self):
        # Title
        title = tk.Label(
            self.window,
            text="PulsePad",
            font=("Segoe UI", 28, "bold"),
            bg="#0F172A",
            fg="#6366F1"
        )
        title.pack(pady=30)
        
        # Connection Mode Frame
        mode_frame = tk.LabelFrame(
            self.window,
            text=" Connection Mode ",
            bg="#0F172A",
            fg="white",
            font=("Segoe UI", 11, "bold"),
            padx=10,
            pady=10
        )
        mode_frame.pack(pady=10, padx=30, fill="x")
        
        self.mode_var = tk.StringVar(value="wifi")
        
        # Custom Radio Buttons
        self._create_radio_btn(mode_frame, "USB (via ADB)", "usb")
        self._create_radio_btn(mode_frame, "Wi-Fi", "wifi")
        
        # Wi-Fi Settings Frame
        ip_frame = tk.LabelFrame(
            self.window,
            text=" Wi-Fi Settings ",
            bg="#0F172A",
            fg="white",
            font=("Segoe UI", 11, "bold"),
            padx=10,
            pady=10
        )
        ip_frame.pack(pady=10, padx=30, fill="x")
        
        tk.Label(ip_frame, text="Phone IP Address:", bg="#0F172A", fg="#94A3B8", font=("Segoe UI", 9)).pack(anchor="w")
        self.phone_ip = tk.Entry(
            ip_frame, 
            bg="#1E293B", 
            fg="white", 
            insertbackground="white", 
            font=("Consolas", 11),
            relief="flat",
            borderwidth=5
        )
        self.phone_ip.pack(fill="x", pady=(5, 15))
        
        tk.Label(ip_frame, text="Server Port:", bg="#0F172A", fg="#94A3B8", font=("Segoe UI", 9)).pack(anchor="w")
        self.port_entry = tk.Entry(
            ip_frame, 
            bg="#1E293B", 
            fg="white", 
            insertbackground="white", 
            font=("Consolas", 11),
            relief="flat",
            borderwidth=5
        )
        self.port_entry.insert(0, "5006")
        self.port_entry.pack(fill="x", pady=(5, 0))
        
        # Status Frame
        status_frame = tk.LabelFrame(
            self.window,
            text=" Status ",
            bg="#0F172A",
            fg="white",
            font=("Segoe UI", 11, "bold"),
            padx=10,
            pady=10
        )
        status_frame.pack(pady=20, padx=30, fill="x")
        
        self.status_label = tk.Label(
            status_frame,
            text="DISCONNECTED",
            bg="#0F172A",
            fg="#EF4444",
            font=("Segoe UI", 14, "bold")
        )
        self.status_label.pack(pady=5)
        
        self.latency_label = tk.Label(
            status_frame,
            text="Latency: -- ms",
            bg="#0F172A",
            fg="#94A3B8",
            font=("Segoe UI", 10)
        )
        self.latency_label.pack(pady=5)
        
        # Control Buttons
        button_frame = tk.Frame(self.window, bg="#0F172A")
        button_frame.pack(pady=30)
        
        self.start_btn = tk.Button(
            button_frame,
            text="START SERVER",
            bg="#6366F1",
            fg="white",
            font=("Segoe UI", 12, "bold"),
            command=self._start_server,
            width=18,
            height=2,
            relief="flat",
            cursor="hand2"
        )
        self.start_btn.pack(side="left", padx=10)
        
        self.stop_btn = tk.Button(
            button_frame,
            text="STOP",
            bg="#EF4444",
            fg="white",
            font=("Segoe UI", 12, "bold"),
            command=self._stop_server,
            width=10,
            height=2,
            relief="flat",
            state="disabled",
            cursor="hand2"
        )
        self.stop_btn.pack(side="left", padx=10)
        
    def _create_radio_btn(self, parent, text, value):
        rb = tk.Radiobutton(
            parent,
            text=text,
            variable=self.mode_var,
            value=value,
            bg="#0F172A",
            fg="white",
            selectcolor="#1E293B",
            activebackground="#0F172A",
            activeforeground="#6366F1",
            font=("Segoe UI", 10),
            cursor="hand2"
        )
        rb.pack(anchor="w", padx=10, pady=5)

    def _update_status_loop(self):
        if self.daemon.running:
            # We don't have a direct "connected" flag in PulsePadDaemon, 
            # but we can check if client_socket is not None.
            if self.daemon.client_socket:
                self.status_label.config(text="CONNECTED", fg="#22C55E")
            else:
                self.status_label.config(text="WAITING FOR CONNECTION...", fg="#F59E0B")
            
            self.latency_label.config(text=f"Latency: {self.daemon.latency} ms")
            self.window.after(100, self._update_status_loop)

    def _start_server(self):
        mode = self.mode_var.get()
        try:
            port = int(self.port_entry.get())
        except ValueError:
            messagebox.showerror("Error", "Invalid port number")
            return
        
        # PulsePadDaemon.start() is blocking, so run in thread
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        
        thread = threading.Thread(target=self.daemon.start, args=(port,))
        thread.daemon = True
        thread.start()
        
        self._update_status_loop()

    def _stop_server(self):
        self.daemon.stop()
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.status_label.config(text="DISCONNECTED", fg="#EF4444")
        self.latency_label.config(text="Latency: -- ms")

    def run(self):
        self.window.mainloop()

def main():
    app = PulsePadGUI()
    app.run()

if __name__ == "__main__":
    main()
