#!/usr/bin/env python3
"""
DeskPulse - Lightweight Computer Monitor & Remote Control Server
Zero external dependencies - runs on Python 3 standard library.
"""

import os
import sys
import time
import json
import socket
import shutil
import platform
import argparse
import threading
import subprocess
from http import HTTPStatus
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Configuration
DEFAULT_PORT = 8765
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

# State for delta calculations
class SystemSampler:
    def __init__(self):
        self.lock = threading.Lock()
        self.last_cpu_sample = None
        self.last_cpu_time = 0
        self.last_net_bytes = None
        self.last_net_time = 0
        self.cached_stats = {}
        self.sample()

    def _read_cpu_stats(self):
        """Read overall and per-core CPU times from /proc/stat."""
        overall = None
        cores = []
        try:
            with open("/proc/stat", "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if not parts:
                        continue
                    if parts[0] == "cpu":
                        times = [float(x) for x in parts[1:]]
                        # idle = times[3] + times[4] (idle + iowait)
                        idle = times[3] + (times[4] if len(times) > 4 else 0)
                        total = sum(times)
                        overall = (idle, total)
                    elif parts[0].startswith("cpu") and parts[0][3:].isdigit():
                        times = [float(x) for x in parts[1:]]
                        idle = times[3] + (times[4] if len(times) > 4 else 0)
                        total = sum(times)
                        cores.append((idle, total))
        except Exception:
            pass
        return overall, cores

    def _read_net_bytes(self):
        """Read total bytes received and transmitted from /proc/net/dev."""
        rx_total = 0
        tx_total = 0
        try:
            with open("/proc/net/dev", "r") as f:
                lines = f.readlines()[2:]
                for line in lines:
                    parts = line.split(":")
                    if len(parts) == 2:
                        dev = parts[0].strip()
                        if dev == "lo":
                            continue
                        stats = parts[1].strip().split()
                        if len(stats) >= 9:
                            rx_total += int(stats[0])
                            tx_total += int(stats[8])
        except Exception:
            pass
        return rx_total, tx_total

    def _read_mem_info(self):
        """Read memory and swap from /proc/meminfo."""
        mem = {}
        try:
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        mem[parts[0].strip()] = int(parts[1].strip().split()[0])
        except Exception:
            pass

        total = mem.get("MemTotal", 0)
        avail = mem.get("MemAvailable", mem.get("MemFree", 0))
        used = max(0, total - avail)
        pct = round((used / total * 100), 1) if total > 0 else 0

        swap_total = mem.get("SwapTotal", 0)
        swap_free = mem.get("SwapFree", 0)
        swap_used = max(0, swap_total - swap_free)
        swap_pct = round((swap_used / swap_total * 100), 1) if swap_total > 0 else 0

        return {
            "total_mb": round(total / 1024, 1),
            "used_mb": round(used / 1024, 1),
            "free_mb": round(avail / 1024, 1),
            "percent": pct,
            "swap_total_mb": round(swap_total / 1024, 1),
            "swap_used_mb": round(swap_used / 1024, 1),
            "swap_percent": swap_pct
        }

    def _read_disks(self):
        """Read disk usage for / and /home."""
        mounts = ["/"]
        home_path = os.path.expanduser("~")
        if os.path.ismount(home_path):
            mounts.append(home_path)

        disks = []
        for path in mounts:
            try:
                usage = shutil.disk_usage(path)
                total_gb = round(usage.total / (1024**3), 1)
                used_gb = round(usage.used / (1024**3), 1)
                free_gb = round(usage.free / (1024**3), 1)
                pct = round((usage.used / usage.total * 100), 1) if usage.total > 0 else 0
                disks.append({
                    "mount": path,
                    "total_gb": total_gb,
                    "used_gb": used_gb,
                    "free_gb": free_gb,
                    "percent": pct
                })
            except Exception:
                pass
        return disks

    def _read_battery(self):
        """Read battery percentage and charging state."""
        try:
            power_dir = "/sys/class/power_supply"
            if os.path.isdir(power_dir):
                for entry in os.listdir(power_dir):
                    if entry.startswith("BAT"):
                        cap_file = os.path.join(power_dir, entry, "capacity")
                        stat_file = os.path.join(power_dir, entry, "status")
                        if os.path.isfile(cap_file):
                            with open(cap_file, "r") as f:
                                capacity = int(f.read().strip())
                            status = "Unknown"
                            if os.path.isfile(stat_file):
                                with open(stat_file, "r") as f:
                                    status = f.read().strip()
                            return {
                                "has_battery": True,
                                "percent": capacity,
                                "status": status
                            }
        except Exception:
            pass
        return {"has_battery": False, "percent": 0, "status": "No Battery"}

    def _read_temperature(self):
        """Read average or max CPU temperature in Celsius."""
        temps = []
        try:
            # Check thermal zones
            thermal_dir = "/sys/class/thermal"
            if os.path.isdir(thermal_dir):
                for entry in os.listdir(thermal_dir):
                    if entry.startswith("thermal_zone"):
                        temp_file = os.path.join(thermal_dir, entry, "temp")
                        if os.path.isfile(temp_file):
                            with open(temp_file, "r") as f:
                                val = float(f.read().strip())
                                # Millidegrees to degrees
                                if val > 1000:
                                    val /= 1000.0
                                if 10 <= val <= 115:
                                    temps.append(val)
        except Exception:
            pass
        if temps:
            return round(max(temps), 1)
        return None

    def _read_uptime(self):
        """Read system uptime in seconds and human format."""
        try:
            with open("/proc/uptime", "r") as f:
                seconds = float(f.read().split()[0])
            mins, sec = divmod(int(seconds), 60)
            hours, mins = divmod(mins, 60)
            days, hours = divmod(hours, 24)
            if days > 0:
                text = f"{days}d {hours}h {mins}m"
            elif hours > 0:
                text = f"{hours}h {mins}m {sec}s"
            else:
                text = f"{mins}m {sec}s"
            return {"seconds": int(seconds), "formatted": text}
        except Exception:
            return {"seconds": 0, "formatted": "N/A"}

    def _read_os_info(self):
        """Read pretty OS name and kernel info."""
        os_name = "Linux"
        try:
            if os.path.isfile("/etc/os-release"):
                with open("/etc/os-release", "r") as f:
                    for line in f:
                        if line.startswith("PRETTY_NAME="):
                            os_name = line.split("=", 1)[1].strip().strip('"')
                            break
        except Exception:
            pass
        return {
            "hostname": platform.node(),
            "os_name": os_name,
            "kernel": platform.release(),
            "arch": platform.machine()
        }

    def sample(self):
        """Perform a sampling round and store current snapshot."""
        now = time.time()
        curr_cpu_overall, curr_cpu_cores = self._read_cpu_stats()
        curr_rx, curr_tx = self._read_net_bytes()

        cpu_percent = 0.0
        cores_percent = []

        if self.last_cpu_sample and curr_cpu_overall:
            prev_idle, prev_total = self.last_cpu_sample[0]
            curr_idle, curr_total = curr_cpu_overall
            delta_total = curr_total - prev_total
            delta_idle = curr_idle - prev_idle
            if delta_total > 0:
                cpu_percent = round(100.0 * (1.0 - (delta_idle / delta_total)), 1)
                cpu_percent = max(0.0, min(100.0, cpu_percent))

            # Per-core percent
            prev_cores = self.last_cpu_sample[1]
            for i, curr_c in enumerate(curr_cpu_cores):
                if i < len(prev_cores):
                    p_idle, p_tot = prev_cores[i]
                    c_idle, c_tot = curr_c
                    d_tot = c_tot - p_tot
                    d_idle = c_idle - p_idle
                    if d_tot > 0:
                        cp = round(100.0 * (1.0 - (d_idle / d_tot)), 1)
                        cores_percent.append(max(0.0, min(100.0, cp)))
                    else:
                        cores_percent.append(0.0)

        # Network transfer rates
        down_speed_kb = 0.0
        up_speed_kb = 0.0
        if self.last_net_bytes and self.last_net_time > 0:
            dt = max(0.001, now - self.last_net_time)
            rx_diff = max(0, curr_rx - self.last_net_bytes[0])
            tx_diff = max(0, curr_tx - self.last_net_bytes[1])
            down_speed_kb = round((rx_diff / 1024.0) / dt, 1)
            up_speed_kb = round((tx_diff / 1024.0) / dt, 1)

        self.last_cpu_sample = (curr_cpu_overall, curr_cpu_cores)
        self.last_cpu_time = now
        self.last_net_bytes = (curr_rx, curr_tx)
        self.last_net_time = now

        mem_info = self._read_mem_info()
        disks = self._read_disks()
        battery = self._read_battery()
        temperature = self._read_temperature()
        uptime = self._read_uptime()
        system = self._read_os_info()

        with self.lock:
            self.cached_stats = {
                "timestamp": now,
                "cpu": {
                    "percent": cpu_percent,
                    "cores_count": len(curr_cpu_cores) or os.cpu_count() or 1,
                    "cores": cores_percent,
                    "temperature_c": temperature
                },
                "memory": mem_info,
                "disks": disks,
                "network": {
                    "download_kbps": down_speed_kb,
                    "upload_kbps": up_speed_kb,
                    "total_rx_mb": round(curr_rx / (1024**2), 1),
                    "total_tx_mb": round(curr_tx / (1024**2), 1)
                },
                "battery": battery,
                "uptime": uptime,
                "system": system
            }

    def get_stats(self):
        with self.lock:
            return self.cached_stats

    def get_processes(self, limit=12, sort_by="cpu"):
        """Get top processes by CPU or MEM."""
        sort_flag = "-%cpu" if sort_by == "cpu" else "-%mem"
        cmd = ["ps", "-eo", "pid,user,%cpu,%mem,comm", f"--sort={sort_flag}"]
        procs = []
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
            lines = res.stdout.strip().split("\n")
            for line in lines[1:limit + 1]:
                parts = line.split(None, 4)
                if len(parts) >= 5:
                    procs.append({
                        "pid": int(parts[0]),
                        "user": parts[1],
                        "cpu": float(parts[2]),
                        "mem": float(parts[3]),
                        "name": parts[4]
                    })
        except Exception:
            pass
        return procs


SAMPLER = SystemSampler()

def background_sampler_loop():
    while True:
        try:
            time.sleep(1.0)
            SAMPLER.sample()
        except Exception:
            pass

# Security & Actions
AUTH_PIN = os.environ.get("DESKPULSE_PIN", "").strip()

def verify_auth(headers, query_params):
    if not AUTH_PIN:
        return True
    header_token = headers.get("X-Auth-Pin") or headers.get("x-auth-pin")
    if header_token == AUTH_PIN:
        return True
    q_pin = query_params.get("pin", [None])[0]
    if q_pin == AUTH_PIN:
        return True
    return False

def execute_action(action_name):
    """Execute safe, allowlisted desktop actions."""
    if action_name == "vol_up":
        # Try wpctl first, fallback to pactl or amixer
        for cmd in [
            ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"],
            ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"],
            ["amixer", "-D", "pulse", "sset", "Master", "5%+"]
        ]:
            if shutil.which(cmd[0]):
                res = subprocess.run(cmd, capture_output=True)
                if res.returncode == 0:
                    return {"success": True, "message": "Volume increased"}
        return {"success": False, "error": "No audio controller found"}

    elif action_name == "vol_down":
        for cmd in [
            ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"],
            ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"],
            ["amixer", "-D", "pulse", "sset", "Master", "5%-"]
        ]:
            if shutil.which(cmd[0]):
                res = subprocess.run(cmd, capture_output=True)
                if res.returncode == 0:
                    return {"success": True, "message": "Volume decreased"}
        return {"success": False, "error": "No audio controller found"}

    elif action_name == "vol_mute":
        for cmd in [
            ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"],
            ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"],
            ["amixer", "-D", "pulse", "sset", "Master", "toggle"]
        ]:
            if shutil.which(cmd[0]):
                res = subprocess.run(cmd, capture_output=True)
                if res.returncode == 0:
                    return {"success": True, "message": "Volume mute toggled"}
        return {"success": False, "error": "No audio controller found"}

    elif action_name == "media_play_pause":
        if shutil.which("playerctl"):
            subprocess.run(["playerctl", "play-pause"], capture_output=True)
            return {"success": True, "message": "Media Play/Pause"}
        return {"success": False, "error": "playerctl not installed"}

    elif action_name == "media_next":
        if shutil.which("playerctl"):
            subprocess.run(["playerctl", "next"], capture_output=True)
            return {"success": True, "message": "Media Next"}
        return {"success": False, "error": "playerctl not installed"}

    elif action_name == "media_prev":
        if shutil.which("playerctl"):
            subprocess.run(["playerctl", "previous"], capture_output=True)
            return {"success": True, "message": "Media Previous"}
        return {"success": False, "error": "playerctl not installed"}

    elif action_name == "lock_screen":
        for cmd in [["loginctl", "lock-session"], ["xdg-screensaver", "lock"]]:
            if shutil.which(cmd[0]):
                subprocess.run(cmd, capture_output=True)
                return {"success": True, "message": "Screen locked"}
        return {"success": False, "error": "Lock command not available"}

    elif action_name == "suspend":
        if shutil.which("systemctl"):
            subprocess.run(["systemctl", "suspend"], capture_output=True)
            return {"success": True, "message": "System suspended"}
        return {"success": False, "error": "systemctl not available"}

    elif action_name == "ping_notify":
        # Send a visible desktop notification
        title = "DeskPulse Mobile"
        body = f"Kết nối thành công từ điện thoại lúc {time.strftime('%H:%M:%S')}!"
        if shutil.which("gdbus"):
            subprocess.run([
                "gdbus", "call", "--session",
                "--dest", "org.freedesktop.Notifications",
                "--object-path", "/org/freedesktop/Notifications",
                "--method", "org.freedesktop.Notifications.Notify",
                "DeskPulse", "0", "preferences-desktop-remote-desktop",
                title, body, "[]", "{}", "4000"
            ], capture_output=True)
            return {"success": True, "message": "Notification sent via DBus"}
        elif shutil.which("notify-send"):
            subprocess.run(["notify-send", title, body], capture_output=True)
            return {"success": True, "message": "Notification sent"}
        return {"success": False, "error": "Notification tool not available"}

    return {"success": False, "error": f"Unknown action: {action_name}"}


class DeskPulseHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Mute normal request spam in console
        pass

    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Auth-Pin")

    def do_OPTIONS(self):
        self.send_response(HTTPStatus.OK)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        # API Endpoints
        if path == "/api/status":
            stats = SAMPLER.get_stats()
            # Include pin requirement indicator
            stats["auth_required"] = bool(AUTH_PIN)
            data = json.dumps(stats).encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(data)
            return

        elif path == "/api/processes":
            sort_by = query.get("sort", ["cpu"])[0]
            limit = int(query.get("limit", [12])[0])
            procs = SAMPLER.get_processes(limit=limit, sort_by=sort_by)
            data = json.dumps({"processes": procs}).encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(data)
            return

        elif path == "/api/ping":
            data = json.dumps({"status": "ok", "time": time.time()}).encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(data)
            return

        # Serve Static Files
        if path == "/" or path == "":
            file_path = os.path.join(STATIC_DIR, "index.html")
        else:
            rel_path = path.lstrip("/")
            file_path = os.path.join(STATIC_DIR, rel_path)

        # Directory traversal prevention
        normalized = os.path.abspath(file_path)
        if not normalized.startswith(os.path.abspath(STATIC_DIR)):
            self.send_error(HTTPStatus.FORBIDDEN, "Access denied")
            return

        if os.path.isfile(normalized):
            ext = os.path.splitext(normalized)[1].lower()
            content_types = {
                ".html": "text/html; charset=utf-8",
                ".css": "text/css; charset=utf-8",
                ".js": "application/javascript; charset=utf-8",
                ".json": "application/json; charset=utf-8",
                ".png": "image/png",
                ".svg": "image/svg+xml",
                ".ico": "image/x-icon",
            }
            content_type = content_types.get(ext, "application/octet-stream")
            try:
                with open(normalized, "rb") as f:
                    content = f.read()
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(content)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(content)
                return
            except Exception as e:
                self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, str(e))
                return

        self.send_error(HTTPStatus.NOT_FOUND, "File not found")

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if not verify_auth(self.headers, query):
            self.send_response(HTTPStatus.UNAUTHORIZED)
            self.send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Unauthorized: Invalid PIN"}).encode("utf-8"))
            return

        if path == "/api/action":
            try:
                content_len = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_len)
                payload = json.loads(body.decode("utf-8")) if body else {}
                action = payload.get("action")
                result = execute_action(action)

                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "application/json")
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(result).encode("utf-8"))
            except Exception as e:
                self.send_response(HTTPStatus.BAD_REQUEST)
                self.send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))
            return

        self.send_error(HTTPStatus.NOT_FOUND, "Action endpoint not found")


def get_all_lan_ips():
    """Detect local LAN IP addresses (non-loopback)."""
    ips = []
    # Method 1: route socket connect
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))
        lan_ip = s.getsockname()[0]
        s.close()
        if lan_ip and not lan_ip.startswith("127."):
            ips.append(lan_ip)
    except Exception:
        pass

    # Method 2: hostname resolution
    try:
        host_ips = socket.gethostbyname_ex(socket.gethostname())[2]
        for ip in host_ips:
            if not ip.startswith("127.") and ip not in ips:
                ips.append(ip)
    except Exception:
        pass

    return ips


def main():
    global AUTH_PIN
    parser = argparse.ArgumentParser(description="DeskPulse Remote Monitor Server")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to listen on")
    parser.add_argument("--pin", type=str, default="", help="Optional PIN to protect controls")
    args = parser.parse_args()

    if args.pin:
        AUTH_PIN = args.pin

    # Start background metric sampler thread
    sampler_thread = threading.Thread(target=background_sampler_loop, daemon=True)
    sampler_thread.start()

    # Pre-sample
    SAMPLER.sample()

    lan_ips = get_all_lan_ips()
    primary_lan = lan_ips[0] if lan_ips else "192.168.x.x"

    server_address = ("0.0.0.0", args.port)
    httpd = HTTPServer(server_address, DeskPulseHandler)

    print("=" * 62)
    print("  🚀  DeskPulse Server - Remote Computer Monitor & Control")
    print("=" * 62)
    print(f"  • Máy tính:      {platform.node()} ({platform.system()} {platform.machine()})")
    print(f"  • Cổng (Port):   {args.port}")
    if AUTH_PIN:
        print(f"  • Mã PIN bảo vệ: [ĐÃ BẬT - {AUTH_PIN}]")
    else:
        print(f"  • Mã PIN:        [Không đặt - Truy cập tự do]")
    print("-" * 62)
    print("  📱 CÁCH TRUY CẬP TỪ ĐIỆN THOẠI ANDROID:")
    print(f"     1. Kết nối điện thoại cùng mạng Wi-Fi với máy tính này.")
    print(f"     2. Mở trình duyệt (Chrome) trên điện thoại và truy cập:")
    if lan_ips:
        for ip in lan_ips:
            print(f"        👉 http://{ip}:{args.port}")
    else:
        print(f"        👉 http://<IP_MÁY_TÍNH>:{args.port}")
    print(f"     3. Nhấn 'Cài đặt ứng dụng' (Install App) để tạo icon như APK!")
    print("=" * 62)
    print("  (Nhấn Ctrl+C để dừng server)")
    print()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nĐang dừng DeskPulse Server...")
        httpd.server_close()
        print("Đã dừng thành công.")

if __name__ == "__main__":
    main()
