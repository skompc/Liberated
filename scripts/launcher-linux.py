#!/usr/bin/env python3
"""Liberated control window for Linux (runs on the bundled Python's Tk)."""
import grp
import os
import pwd
import queue
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import messagebox, ttk

RES = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = os.path.join(RES, "run")
VENV_PY = os.path.join(RES, "venv", "bin", "python3")
SCRAPER = os.path.join(RES, "scraper", "scraper.py")
SCRAPER_CONFIG = os.path.join(RES, "scraper", "scraper-config.json")
HELPER = os.path.join(RES, "bin", "privileged.sh")
COMMAND = os.path.join(RUN, "privileged.command")
WEB_STATUS = os.path.join(RUN, "web.status")
DNS_STATUS = os.path.join(RUN, "dns.status")
HELPER_STATUS = os.path.join(RUN, "helper.status")
FPM_PID = os.path.join(RUN, "php-fpm.pid")
SCRAPER_LOG = os.path.join(RUN, "scraper.log")
PROGRESS_RE = re.compile(r"^\[(\d+)/(\d+)\]")
RETRY_SECONDS = 10


def read_file(path, default=""):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip() or default
    except OSError:
        return default


def write_file(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text + "\n")


def send_command(command):
    write_file(COMMAND, command)


def fix_venv_config():
    # Re-point the venv at the bundled interpreter (the folder may have been moved)
    cfg = os.path.join(RES, "venv", "pyvenv.cfg")
    with open(cfg, encoding="utf-8") as f:
        lines = [l for l in f if not re.match(r"^(home|executable|command)\s*=", l)]
    with open(cfg + ".tmp", "w", encoding="utf-8") as f:
        f.write(f"home = {os.path.join(RES, 'python', 'bin')}\n")
        f.writelines(lines)
    os.replace(cfg + ".tmp", cfg)


def local_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("1.1.1.1", 53))
            return s.getsockname()[0]
    except OSError:
        return ""


def open_path(*paths):
    for p in paths:
        subprocess.Popen(["xdg-open", p], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def start_helper(ip):
    """Starts the root helper that owns ports 53/80/443. Returns the Popen or None."""
    args = [HELPER, str(os.getpid()), pwd.getpwuid(os.getuid()).pw_name, ip]
    if os.getuid() == 0:
        cmd = args
    elif sys.stdin.isatty() and shutil.which("sudo"):
        print("Liberated needs root to bind DNS (53) and web (80/443) ports.")
        if subprocess.call(["sudo", "-v"]) != 0:
            return None
        cmd = ["sudo", "-n"] + args
    elif shutil.which("pkexec"):
        cmd = ["pkexec"] + args
    else:
        return None
    return subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class DownloadWindow:
    def __init__(self, app):
        self.app = app
        self.proc = None
        self.cancelled = False
        self.retry_job = None
        self.retry_left = 0
        self.last_line = ""
        self.lines = queue.Queue()

        self.win = tk.Toplevel(app.root)
        self.win.title("Liberated - Downloading game assets")
        self.win.resizable(False, False)
        self.win.protocol("WM_DELETE_WINDOW", self.close)
        frame = ttk.Frame(self.win, padding=12)
        frame.pack(fill="both", expand=True)

        self.bar = ttk.Progressbar(frame, length=560, mode="indeterminate", maximum=100)
        self.bar.pack(fill="x")
        self.count = ttk.Label(frame, text="Starting...")
        self.count.pack(fill="x", pady=(6, 6))
        text_frame = ttk.Frame(frame)
        text_frame.pack(fill="both", expand=True)
        self.text = tk.Text(text_frame, width=80, height=14, state="disabled", font="TkFixedFont", wrap="none")
        scroll = ttk.Scrollbar(text_frame, command=self.text.yview)
        self.text.configure(yscrollcommand=scroll.set)
        self.text.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        buttons = ttk.Frame(frame)
        buttons.pack(fill="x", pady=(10, 0))
        self.cancel_button = ttk.Button(buttons, text="Cancel", command=self.cancel)
        self.cancel_button.pack(side="right")
        self.retry_button = ttk.Button(buttons, text="Retry Now", command=self.retry_now)

        self.start()
        self.poll()

    def show(self):
        self.win.deiconify()
        self.win.lift()

    @property
    def running(self):
        return self.proc is not None and self.proc.poll() is None

    def append(self, line):
        self.text.configure(state="normal")
        self.text.insert("end", line + "\n")
        self.text.see("end")
        self.text.configure(state="disabled")

    def start(self):
        self.stop_retry()
        self.retry_button.pack_forget()
        self.cancel_button.configure(text="Cancel", state="normal")
        self.bar.configure(mode="indeterminate", value=0)
        self.bar.start(15)
        self.count.configure(text="Starting...")
        self.cancelled = False
        self.last_line = ""
        self.app.set_assets("Downloading game assets...")
        try:
            self.proc = subprocess.Popen(
                [VENV_PY, "-u", SCRAPER], cwd=RES, stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        except OSError as e:
            self.proc = None
            self.count.configure(text=f"Could not start the scraper: {e}")
            self.cancel_button.configure(text="Close")
            return
        threading.Thread(target=self.read_output, args=(self.proc,), daemon=True).start()

    def read_output(self, proc):
        with open(SCRAPER_LOG, "a", encoding="utf-8") as log:
            for line in proc.stdout:
                line = line.rstrip("\n")
                log.write(line + "\n")
                log.flush()
                self.lines.put(line)
        self.lines.put((proc.wait(),))

    def poll(self):
        try:
            while True:
                item = self.lines.get_nowait()
                if isinstance(item, tuple):
                    self.finished(item[0])
                else:
                    self.line(item)
        except queue.Empty:
            pass
        if self.win.winfo_exists():
            self.win.after(100, self.poll)

    def line(self, line):
        self.last_line = line
        self.append(line)
        m = PROGRESS_RE.match(line)
        if m and int(m.group(2)) > 0:
            done, total = int(m.group(1)), int(m.group(2))
            pct = min(100, done * 100 // total)
            if str(self.bar.cget("mode")) != "determinate":
                self.bar.stop()
                self.bar.configure(mode="determinate")
            self.bar.configure(value=pct)
            self.count.configure(text=f"{done} / {total} files ({pct}%)")

    def finished(self, code):
        self.proc = None
        self.bar.stop()
        self.bar.configure(mode="determinate")
        self.cancel_button.configure(state="normal")
        if self.app.quitting:
            self.app.quit()
            return
        if code == 0:
            self.bar.configure(value=100)
            self.count.configure(text="Done.")
            self.append("\nGame assets downloaded.")
            self.cancel_button.configure(text="Close")
            self.app.set_assets("Game assets are ready.")
        elif self.cancelled:
            self.count.configure(text="Cancelled; downloaded files were kept.")
            self.cancel_button.configure(text="Close")
            self.retry_button.pack(side="right", padx=(0, 8))
            self.app.set_assets("Download cancelled; downloaded files were kept.")
        else:
            self.append(f"\nDownload failed: {self.last_line or 'see run/scraper.log'}")
            self.app.set_assets("Download failed; retrying...")
            self.retry_left = RETRY_SECONDS
            self.cancel_button.configure(text="Cancel")
            self.retry_button.pack(side="right", padx=(0, 8))
            self.tick_retry()

    def tick_retry(self):
        if self.retry_left <= 0:
            self.retry_job = None
            self.start()
            return
        self.count.configure(text=f"Download failed. Retrying in {self.retry_left} seconds...")
        self.retry_left -= 1
        self.retry_job = self.win.after(1000, self.tick_retry)

    def stop_retry(self):
        if self.retry_job is not None:
            self.win.after_cancel(self.retry_job)
            self.retry_job = None

    def retry_now(self):
        if not self.running:
            self.start()

    def cancel(self):
        if self.running:
            self.cancelled = True
            self.count.configure(text="Cancelling download...")
            self.cancel_button.configure(state="disabled")
            self.proc.send_signal(signal.SIGINT)
        elif self.retry_job is not None:
            self.stop_retry()
            self.count.configure(text="Download failed; automatic retry cancelled.")
            self.cancel_button.configure(text="Close")
            self.app.set_assets("Download failed; see run/scraper.log.")
        else:
            self.close()

    def interrupt(self):
        self.stop_retry()
        if self.running:
            self.cancelled = True
            self.proc.send_signal(signal.SIGINT)

    def close(self):
        if self.running or self.retry_job is not None:
            self.cancel()
            if self.running:
                return
        self.win.destroy()
        self.app.download = None


class App:
    def __init__(self, ip, helper):
        self.ip = ip
        self.helper = helper
        self.ready = False
        self.quitting = False
        self.download = None
        self.wait_started = time.monotonic()

        self.root = tk.Tk(className="Liberated")
        self.root.title("Liberated")
        self.root.resizable(False, False)
        try:
            self.icon = tk.PhotoImage(file=os.path.join(RES, "icon.png"))
            self.root.iconphoto(True, self.icon)
        except tk.TclError:
            pass
        style = ttk.Style(self.root)
        if "clam" in style.theme_names():
            style.theme_use("clam")
        self.root.protocol("WM_DELETE_WINDOW", self.quit)
        for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            signal.signal(sig, lambda *_: self.root.after(0, self.quit))

        frame = ttk.Frame(self.root, padding=16)
        frame.pack(fill="both", expand=True)
        frame.columnconfigure(0, weight=1)
        self.heading = ttk.Label(frame, text="Waiting for authorization...", font=("TkDefaultFont", 13, "bold"))
        self.heading.grid(row=0, column=0, columnspan=4, sticky="w")
        ttk.Label(frame, text=f"Set your device DNS to: {ip or 'unknown'}").grid(
            row=1, column=0, columnspan=4, sticky="w", pady=(4, 14))

        self.web_label = ttk.Label(frame, text="Web server: Stopped")
        self.web_label.grid(row=2, column=0, columnspan=3, sticky="w")
        self.web_button = ttk.Button(frame, text="Start Web", width=14, command=self.toggle_web)
        self.web_button.grid(row=2, column=3, sticky="e", pady=3)
        self.dns_label = ttk.Label(frame, text="DNS server: Stopped")
        self.dns_label.grid(row=3, column=0, columnspan=3, sticky="w")
        self.dns_button = ttk.Button(frame, text="Start DNS", width=14, command=self.toggle_dns)
        self.dns_button.grid(row=3, column=3, sticky="e", pady=3)

        self.assets_label = ttk.Label(frame, text="")
        self.assets_label.grid(row=4, column=0, columnspan=4, sticky="w", pady=(12, 12))

        actions = ttk.Frame(frame)
        actions.grid(row=5, column=0, columnspan=4, sticky="we")
        self.action_buttons = [
            ttk.Button(actions, text="Update Assets", command=self.update_assets),
            ttk.Button(actions, text="Edit Scraper Config", command=lambda: open_path(SCRAPER_CONFIG)),
            ttk.Button(actions, text="Show Logs", command=lambda: open_path(RUN, os.path.join(RES, "web", "logs"))),
            ttk.Button(actions, text="Stop All", command=self.stop_all),
        ]
        for b in self.action_buttons:
            b.pack(side="left", padx=(0, 6))
        ttk.Button(actions, text="Quit", command=self.quit).pack(side="right")
        self.set_controls_enabled(False)

        if helper is None:
            self.root.after(0, lambda: self.fail(
                "Root access is required to bind ports 53/80/443. Install pkexec (polkit) "
                "or run Liberated from a terminal so sudo can prompt for your password."))
        else:
            self.root.after(200, self.wait_for_helper)

    def set_controls_enabled(self, enabled):
        state = "normal" if enabled else "disabled"
        for b in [self.web_button, self.dns_button] + self.action_buttons:
            b.configure(state=state)

    def set_assets(self, text):
        self.assets_label.configure(text=text)

    def fail(self, message):
        messagebox.showerror("Liberated", message, parent=self.root)
        self.quit()

    def wait_for_helper(self):
        if read_file(HELPER_STATUS) == "ready":
            self.on_ready()
        elif self.helper.poll() is not None or time.monotonic() - self.wait_started > 120:
            self.fail("Authorization was cancelled or failed.")
        else:
            self.root.after(250, self.wait_for_helper)

    def on_ready(self):
        self.ready = True
        send_command("idle")
        write_file(WEB_STATUS, "stopped")
        write_file(DNS_STATUS, "stopped")
        self.heading.configure(text="Liberated is running")
        self.set_controls_enabled(True)
        check = subprocess.run([VENV_PY, SCRAPER, "--check"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.set_assets("Game assets are ready." if check.returncode == 0 else "Game assets are missing.")
        self.start_web()
        self.refresh()

    def refresh(self):
        web = read_file(WEB_STATUS, "stopped")
        dns = read_file(DNS_STATUS, "stopped")
        self.web_label.configure(text=f"Web server: {web.capitalize()}")
        self.dns_label.configure(text=f"DNS server: {dns.capitalize()}")
        self.web_button.configure(text="Stop Web" if web in ("running", "starting") else "Start Web")
        self.dns_button.configure(text="Stop DNS" if dns in ("running", "starting") else "Start DNS")
        if self.helper.poll() is not None and not self.quitting:
            self.heading.configure(text="Root helper stopped; restart Liberated")
            self.set_controls_enabled(False)
            return
        self.root.after(500, self.refresh)

    def start_web(self):
        with open(os.path.join(RES, "php", "php-fpm.conf"), encoding="utf-8") as f:
            conf = f.read()
        user = pwd.getpwuid(os.getuid()).pw_name
        group = grp.getgrgid(os.getgid()).gr_name
        conf = conf.replace("[www]\n", f"[www]\nuser = {user}\ngroup = {group}\n", 1)
        fpm_conf = os.path.join(RUN, "php-fpm.conf")
        with open(fpm_conf, "w", encoding="utf-8") as f:
            f.write(conf)
        result = subprocess.run([os.path.join(RES, "php", "php-fpm"), "-p", RES, "-y", fpm_conf,
                                 "-c", os.path.join(RES, "php", "php.ini")],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode != 0:
            write_file(WEB_STATUS, "failed (see run/php-fpm.log)")
            return
        write_file(WEB_STATUS, "starting")
        send_command("start-web")

    def stop_web(self):
        send_command("stop-web")
        try:
            os.kill(int(read_file(FPM_PID, "0")), signal.SIGTERM)
        except (ValueError, OSError):
            pass
        write_file(WEB_STATUS, "stopped")

    def toggle_web(self):
        if read_file(WEB_STATUS, "stopped") in ("running", "starting"):
            self.stop_web()
        else:
            self.start_web()

    def toggle_dns(self):
        running = read_file(DNS_STATUS, "stopped") in ("running", "starting")
        if not running:
            write_file(DNS_STATUS, "starting")
        send_command("stop-dns" if running else "start-dns")

    def stop_all(self):
        self.stop_web()
        send_command("stop-all")

    def update_assets(self):
        if self.download is None:
            self.download = DownloadWindow(self)
        else:
            self.download.show()

    def quit(self):
        if self.download is not None and self.download.running and not self.quitting:
            self.quitting = True
            self.download.interrupt()
            return   # DownloadWindow.finished calls quit again
        self.quitting = True
        if self.ready:
            # The helper stops nginx and DNS itself on quit
            self.stop_web()
            send_command("quit")
        if self.helper is not None and self.helper.poll() is None:
            try:
                self.helper.terminate()
            except OSError:
                pass
        self.root.destroy()


def main():
    os.makedirs(RUN, exist_ok=True)
    os.makedirs(os.path.join(RES, "web", "logs"), exist_ok=True)
    os.makedirs(os.path.join(RES, "web", "temp"), exist_ok=True)
    try:
        os.remove(HELPER_STATUS)
    except FileNotFoundError:
        pass
    fix_venv_config()
    ip = local_ip()
    helper = start_helper(ip)
    App(ip, helper).root.mainloop()


if __name__ == "__main__":
    main()
