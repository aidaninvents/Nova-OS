import hashlib
import http.server
import json
import mimetypes
import os
import platform
import re
import shutil
import socketserver
import ssl
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
STORAGE_DIR = BASE_DIR / "storage"
PACKAGES_DIR = STORAGE_DIR / "Packages"
VIDEOS_DIR = STORAGE_DIR / "Videos"
DOWNLOADS_DIR = STORAGE_DIR / "Downloads"
DOCUMENTS_DIR = STORAGE_DIR / "Documents"
PICTURES_DIR = STORAGE_DIR / "Pictures"
MUSIC_DIR = STORAGE_DIR / "Music"
DESKTOP_DIR = STORAGE_DIR / "Desktop"
for _d in (STORAGE_DIR, PACKAGES_DIR, VIDEOS_DIR, DOWNLOADS_DIR, DOCUMENTS_DIR, PICTURES_DIR, MUSIC_DIR, DESKTOP_DIR):
    _d.mkdir(parents=True, exist_ok=True)
STATE_FILE = BASE_DIR / "system_state.json"
INSTALL_STATUS_FILE = Path("/tmp/novaos_install_status.json")
INSTALLED_META_FILE = Path("/etc/novaos_installed.json")
DISC_KEY_FILE = Path("/etc/novaos_disc_key")
PORT = 8090

# Host .NOSP server URLs (10.0.2.2 is the VirtualBox NAT host gateway; 127.0.0.1 when on host)
NOSP_SERVER_URLS = [
    "http://10.0.2.2:8095",
    "http://127.0.0.1:8095",
]

WELCOME_TXT = DOCUMENTS_DIR / "Welcome_to_NovaOS_2.00.txt"
WELCOME_TXT.write_text(
    "Welcome to Nova OS 2.00 (Beta 4 - Build 27300)!\n"
    "- Built-in Home Apps (15): WiFi/Ethernet, Settings, File Explorer, App Store, Clock, Calendar, Calculator, Notepad, Chrome, Weather, plus 5 new Home apps: Journal, Voice Recorder, Home Budget, Sticky Notes, and Memory Match!\n"
    "- Pro Edition adds 10 Bonus Pro Apps on top of Home: DevTools, Code Studio, Terminal, Task Manager, Disk Manager, NetTools, EXE to NOSP, Paint Studio, Music Player, and Video Player.\n"
    "- Real CPU & GPU detection, C:/A:/B: Drive Explorer, Local File Wallpaper persistence, Setup Account & PIN (or No thanks), and Product Key Activation.\n",
    encoding="utf-8",
)

HOME_PREINSTALLED_APPS = [
    "wifi", "settings", "files", "appstore",
    "clock", "calendar", "calculator", "notepad", "chrome", "weather",
    "journal", "recorder", "budget", "sticky", "memory",
]
PRO_BONUS_APPS = [
    "devtools", "codeide", "terminal", "sysmonitor", "diskutil",
    "nettools", "exetonosp", "paintstudio", "musicstudio", "videoplayer",
]
PRO_PREINSTALLED_APPS = HOME_PREINSTALLED_APPS + PRO_BONUS_APPS

HOME_PRODUCT_KEYS = {
    "NOVA2-HQ95M-B2H16-PL0A5-X3D7T",
    "NOVA2-K4M8N-Q7W2Z-V9C3B-T5R1Y",
    "NOVA2-P8J3L-W5N6X-D2M4F-G7H9Q",
    "NOVA2-A3S6D-F9G2H-J4K7L-M1P8Z",
    "NOVA2-R7T2Y-U5I8O-P3A6S-D9F4G",
    "NOVA2-C6V1B-N8M3X-Z4L7K-J2H5P",
    "NOVA2-W9E4R-T1Y6U-I3O8P-A2S7D",
    "NOVA2-M5N8B-V2C7X-Z9Q4W-E6R3T",
    "NOVA2-H7J4K-L9P2Q-W5E8R-T3Y6U",
    "NOVA2-F2G5H-J8K1L-M4N7B-V9C6X",
    "NOVA2-X4C9V-B3N7M-Q6W2E-R8T5Y",
}

PRO_PRODUCT_KEYS = {
    "NOVA2-ET98E-R4K89-SDR56-856KE",
    "NOVA2-PR47Q-W8X2M-K5N9B-V3C6Z",
    "NOVA2-ZX71C-V4B8N-M2K6J-H9G3F",
    "NOVA2-PL29M-K5N8B-V4C7X-Z1Q6W",
    "NOVA2-ER63T-Y8U2I-O5P9A-S4D7F",
    "NOVA2-GH84J-K2L6P-Q9W3E-R7T5Y",
    "NOVA2-VB52N-M7C9X-Z4L1K-J6H8P",
    "NOVA2-UI39O-P6A2S-D8F4G-H7J1K",
    "NOVA2-TY86R-E3W9Q-A5S2D-F7G4H",
    "NOVA2-MN45B-V8C2X-Z7L9K-J3H6P",
    "NOVA2-QW91E-R5T3Y-U7I2O-P8A4S",
}

DEFAULT_STATE = {
    "build": "27300",
    "version_label": "Nova OS 2.00 Beta 4\n(Build 27300)",
    "edition": "Pro",
    "activated": False,
    "activation_key": "",
    "activation_bypassed": False,
    "oobe_done": False,
    "account": {"username": "User", "has_pin": False, "pin_hash": ""},
    "wallpaper": "",
    "language": "en-US",
    "boot_spinner": "newbootspin.fnt",
    "theme": "light",
    "system_font": "Segoe UI",
    "installed_apps": list(PRO_PREINSTALLED_APPS),
    "app_usage": {},
    "datetime": {
        "timezone": "America/Chicago",
        "offset_ms": 0,
        "use_24h": False,
        "show_seconds": False,
    },
    "network": {
        "connected": False,
        "mode": "none",
        "ssid": "",
        "security": "WPA2-PSK",
        "driver": "cfg80211 / e1000 Network Stack (WPA2-PSK CCMP Enabled)",
    },
}

FALLBACK_NOSP_CATALOG = [
    {
        "id": "chrome",
        "filename": "Chrome.NOSP",
        "name": "Chrome",
        "full_name": "Google Chrome",
        "version": "130.0.6723.116",
        "size": "98.4 MB",
        "category": "Web Browser",
        "description": "Official Google Chrome web browser (.NOSP package) with full WebKit/HTML5 rendering, tabs, downloads, and live internet browsing.",
    },
    {
        "id": "youtube",
        "filename": "YouTube.NOSP",
        "name": "YouTube",
        "full_name": "YouTube 1080p HD",
        "version": "2.00.1080",
        "size": "42.1 MB",
        "category": "Video & Streaming",
        "description": "Official YouTube HD streaming client (.NOSP package) with 1080p H.264/VP9 playback and full player controls.",
    },
    {
        "id": "exetonosp",
        "filename": "EXEtoNOSP.NOSP",
        "name": "EXE to NOSP",
        "full_name": "EXE to NOSP (Wine Runner)",
        "version": "2.00.10",
        "size": "146.0 MB",
        "category": "Compatibility & Wine",
        "description": "Convert and run Windows .EXE apps (steam.exe, Roblox.exe, setup.exe) as native .NOSP apps powered by Wine 10.0 on Linux.",
    },
    {
        "id": "videoplayer",
        "filename": "VideoPlayer.NOSP",
        "name": "Video Player",
        "full_name": "Nova MP4 / MOV Video Player",
        "version": "2.00.5",
        "size": "18.6 MB",
        "category": "Media & Video",
        "description": "High-definition MP4 / MOV / WebM / MKV Video Player supporting 1080p60 playback, variable speed, timeline scrubbing, and >1 GB local video files.",
    },
    {
        "id": "dvdplayer",
        "filename": "DVDPlayer.NOSP",
        "name": "DVD Player",
        "full_name": "Nova DVD Player Pro",
        "version": "2.00.2",
        "size": "24.0 MB",
        "category": "Optical & Home Theater",
        "description": "Full DVD-Video / ISO / VOB Optical Disc Player with interactive DVD Title Menu, Chapter selection, Audio/Subtitle tracks, and on-screen DVD remote deck.",
    },
    {
        "id": "musicstudio",
        "filename": "MusicStudio.NOSP",
        "name": "Music Player",
        "full_name": "Nova Music & EQ Studio",
        "version": "2.00.1",
        "size": "14.2 MB",
        "category": "Audio & Music",
        "description": "Digital audio player & synthesizer with real-time 16-band spectrum analyzer, 3-band EQ, and local MP3/WAV playback.",
    },
    {
        "id": "paintstudio",
        "filename": "PaintStudio.NOSP",
        "name": "Paint Studio",
        "full_name": "Nova Paint & Photo Studio",
        "version": "2.00.4",
        "size": "11.5 MB",
        "category": "Creativity & Design",
        "description": "Full canvas drawing and image editing suite with brushes, text tool (100+ fonts), color picker, and direct PNG export to File Explorer.",
    },
    {
        "id": "notepad",
        "filename": "Notepad.NOSP",
        "name": "Notepad",
        "full_name": "Nova Notepad",
        "version": "2.00.1",
        "size": "4.8 MB",
        "category": "Productivity",
        "description": "Fast text and source code editor with 100+ font selector and direct reading/writing to the Nova OS filesystem.",
    },
    {
        "id": "terminal",
        "filename": "Terminal.NOSP",
        "name": "Terminal",
        "full_name": "Nova Terminal",
        "version": "2.00.0",
        "size": "6.2 MB",
        "category": "Developer Tools",
        "description": "System command-line shell supporting boot spinner font switching (newbootspin.fnt / oldbootspin.fnt), Wine commands, and OS diagnostics.",
    },
    {
        "id": "calculator",
        "filename": "Calculator.NOSP",
        "name": "Calculator",
        "full_name": "Nova Scientific Calculator",
        "version": "2.00.0",
        "size": "3.1 MB",
        "category": "Utilities",
        "description": "Standard & scientific calculator with expression history, memory functions, and keyboard shortcuts.",
    },
    {
        "id": "imageviewer",
        "filename": "ImageViewer.NOSP",
        "name": "Photos",
        "full_name": "Nova Photos & Image Viewer",
        "version": "2.00.0",
        "size": "7.4 MB",
        "category": "Media & Photos",
        "description": "Fast PNG/JPG/SVG/WEBP viewer with zoom, rotation, slideshow, and wallpaper set integration.",
    },
    {
        "id": "sysmonitor",
        "filename": "SystemMonitor.NOSP",
        "name": "Task Manager",
        "full_name": "Nova Task Manager & Monitor",
        "version": "2.00.2",
        "size": "5.9 MB",
        "category": "System Tools",
        "description": "Real-time CPU, RAM, ZRAM swap, disk, network, and active window/process monitor for Nova OS 2.00.",
    },
    {
        "id": "clock",
        "filename": "Clock.NOSP",
        "name": "Clock",
        "full_name": "Nova Clock, World Time & Timers",
        "version": "2.00.2",
        "size": "3.4 MB",
        "category": "Productivity",
        "description": "Live world clocks, precision stopwatch with lap history, and countdown timer with chime.",
    },
    {
        "id": "calendar",
        "filename": "Calendar.NOSP",
        "name": "Calendar",
        "full_name": "Nova Calendar & Event Planner",
        "version": "2.00.2",
        "size": "4.2 MB",
        "category": "Productivity",
        "description": "Interactive monthly calendar with day-by-day event scheduling persisted to storage.",
    },
    {
        "id": "tasks",
        "filename": "Tasks.NOSP",
        "name": "Tasks",
        "full_name": "Nova Tasks & Reminders",
        "version": "2.00.2",
        "size": "3.8 MB",
        "category": "Productivity",
        "description": "Clean To-Do list and reminder organizer with priorities, filters, and disk persistence.",
    },
    {
        "id": "codeide",
        "filename": "CodeStudio.NOSP",
        "name": "Code Studio",
        "full_name": "Nova Code & Markdown Studio",
        "version": "2.00.2",
        "size": "9.6 MB",
        "category": "Developer Tools",
        "description": "Code and Markdown editor with line numbers, live HTML/JS sandbox preview, and filesystem integration.",
    },
    {
        "id": "diskutil",
        "filename": "DiskManager.NOSP",
        "name": "Disk Manager",
        "full_name": "Nova Disk & Memory Manager",
        "version": "2.00.2",
        "size": "5.1 MB",
        "category": "System Tools",
        "description": "Live partition, block disk, RAM, ZRAM swap, and system cache cleanup manager.",
    },
    {
        "id": "nettools",
        "filename": "NetTools.NOSP",
        "name": "NetTools",
        "full_name": "Nova Network Diagnostics",
        "version": "2.00.2",
        "size": "4.0 MB",
        "category": "System Tools",
        "description": "Interface IP inspector, DNS resolver benchmark, and gateway ping diagnostics.",
    },
    {
        "id": "snake",
        "filename": "Snake.NOSP",
        "name": "Snake",
        "full_name": "Nova Snake Classic",
        "version": "2.00.2",
        "size": "2.4 MB",
        "category": "Games",
        "description": "Fast 2D canvas arcade Snake with selectable difficulty speeds and high-score tracking.",
    },
    {
        "id": "mines",
        "filename": "Minesweeper.NOSP",
        "name": "Minesweeper",
        "full_name": "Nova Minesweeper",
        "version": "2.00.2",
        "size": "2.8 MB",
        "category": "Games",
        "description": "Classic 10x10 logic puzzle with flag mode, flood-fill reveal, and timer.",
    },
    {
        "id": "game2048",
        "filename": "Game2048.NOSP",
        "name": "2048",
        "full_name": "Nova 2048 Puzzle",
        "version": "2.00.2",
        "size": "2.1 MB",
        "category": "Games",
        "description": "Classic 4x4 sliding tile puzzle game with score and best-score tracking.",
    },
    {
        "id": "weather",
        "filename": "Weather.NOSP",
        "name": "Weather",
        "full_name": "Nova Weather & Forecast",
        "version": "2.00.3",
        "size": "3.2 MB",
        "category": "Productivity",
        "description": "Live weather conditions and 5-day forecast powered by Open-Meteo over Ethernet/Wi-Fi.",
    },
    {
        "id": "piano",
        "filename": "Piano.NOSP",
        "name": "Piano Synth",
        "full_name": "Nova Piano & Audio Synth",
        "version": "2.00.3",
        "size": "4.4 MB",
        "category": "Audio & Music",
        "description": "2-octave WebAudio synthesizer keyboard with waveforms, octave shifting, and demo melodies.",
    },
    {
        "id": "pomodoro",
        "filename": "Pomodoro.NOSP",
        "name": "Pomodoro",
        "full_name": "Nova Focus Pomodoro Timer",
        "version": "2.00.3",
        "size": "2.2 MB",
        "category": "Productivity",
        "description": "Focus & break interval timer with cycle counter and completion chimes.",
    },
    {
        "id": "converter",
        "filename": "Converter.NOSP",
        "name": "Converter",
        "full_name": "Nova Unit & Base Converter",
        "version": "2.00.3",
        "size": "2.6 MB",
        "category": "Utilities",
        "description": "Instant converter for Length, Mass, Temperature, Data Storage, Speed, and Hex/Binary bases.",
    },
    {
        "id": "tictactoe",
        "filename": "TicTacToe.NOSP",
        "name": "Tic-Tac-Toe",
        "full_name": "Nova Tic-Tac-Toe AI",
        "version": "2.00.3",
        "size": "1.9 MB",
        "category": "Games",
        "description": "Play against an unbeatable Minimax AI or pass-and-play in 2-player local mode.",
    },
    {
        "id": "devtools",
        "filename": "DevTools.NOSP",
        "name": "DevTools",
        "full_name": "Nova JSON, Base64 & Hash Studio",
        "version": "2.00.3",
        "size": "3.5 MB",
        "category": "Developer Tools",
        "description": "Format/validate JSON, encode/decode Base64 & URLs, and compute SHA-256 digests.",
    },
    {
        "id": "journal",
        "filename": "Journal.NOSP",
        "name": "Journal",
        "full_name": "Nova Home Personal Journal",
        "version": "2.00.4",
        "size": "2.7 MB",
        "category": "Home & Lifestyle",
        "description": "Daily personal journal with mood tags, date stamps, search, and disk persistence.",
    },
    {
        "id": "recorder",
        "filename": "Recorder.NOSP",
        "name": "Voice Recorder",
        "full_name": "Nova Home Voice & Tone Recorder",
        "version": "2.00.4",
        "size": "3.1 MB",
        "category": "Home & Audio",
        "description": "Record microphone audio or synthesized voice memos directly to Music/ with live waveform.",
    },
    {
        "id": "budget",
        "filename": "Budget.NOSP",
        "name": "Home Budget",
        "full_name": "Nova Home Budget & Expense Tracker",
        "version": "2.00.4",
        "size": "2.9 MB",
        "category": "Home & Finance",
        "description": "Track household income, bills, savings goals, and category breakdowns.",
    },
    {
        "id": "sticky",
        "filename": "StickyNotes.NOSP",
        "name": "Sticky Notes",
        "full_name": "Nova Home Sticky Notes",
        "version": "2.00.4",
        "size": "1.8 MB",
        "category": "Home & Productivity",
        "description": "Color-coded sticky notes board saved persistently to Documents/sticky_notes.json.",
    },
    {
        "id": "memory",
        "filename": "MemoryMatch.NOSP",
        "name": "Memory Match",
        "full_name": "Nova Home Memory Card Match",
        "version": "2.00.4",
        "size": "2.1 MB",
        "category": "Home & Games",
        "description": "Family-friendly flip-card matching puzzle with move counter and best-score tracking.",
    },
    {
        "id": "markdown",
        "filename": "Markdown.NOSP",
        "name": "Markdown Reader",
        "full_name": "Nova Live Markdown Studio",
        "version": "2.00.4",
        "size": "2.4 MB",
        "category": "Productivity",
        "description": "Split-pane Markdown writer with instant formatted HTML preview and disk save.",
    },
    {
        "id": "colorstudio",
        "filename": "ColorStudio.NOSP",
        "name": "Color Studio",
        "full_name": "Nova Color Picker & Gradient Studio",
        "version": "2.00.4",
        "size": "2.3 MB",
        "category": "Graphics & Design",
        "description": "Interactive HEX/RGB/HSL color inspector and CSS gradient generator.",
    },
    {
        "id": "qrlab",
        "filename": "QRLab.NOSP",
        "name": "QR Lab",
        "full_name": "Nova Instant Matrix & Badge Generator",
        "version": "2.00.4",
        "size": "2.0 MB",
        "category": "Utilities",
        "description": "Generate downloadable deterministic matrix badges and shareable codes.",
    },
]


def _detect_live_ethernet():
    if platform.system() != "Linux":
        return None
    net_sys = Path("/sys/class/net")
    if not net_sys.exists():
        return None
    for iface in sorted(net_sys.iterdir()):
        if iface.name == "lo" or (iface / "wireless").exists() or (iface / "phy80211").exists():
            continue
        try:
            oper = (iface / "operstate").read_text(errors="ignore").strip()
            carrier = (iface / "carrier").read_text(errors="ignore").strip()
            if oper == "up" or carrier == "1":
                return iface.name
        except Exception:
            pass
    return None


def load_state():
    st = json.loads(json.dumps(DEFAULT_STATE))
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            st.update(data)
        except Exception:
            pass
    elif INSTALLED_META_FILE.exists():
        try:
            meta = json.loads(INSTALLED_META_FILE.read_text(encoding="utf-8"))
            ed = meta.get("edition") or "Pro"
            pkey = (meta.get("product_key") or "").strip().upper()
            st["edition"] = ed
            st["language"] = meta.get("language") or "en-US"
            st["activated"] = bool(pkey)
            st["activation_bypassed"] = not bool(pkey)
            st["activation_key"] = pkey
            st["installed_apps"] = list(HOME_PREINSTALLED_APPS if ed == "Home" else PRO_PREINSTALLED_APPS)
            if meta.get("username"):
                st["account"] = {"username": meta["username"], "has_pin": bool(meta.get("has_pin")), "pin_hash": meta.get("pin_hash", "")}
                st["oobe_done"] = True
        except Exception:
            pass
    if not st.get("network", {}).get("connected"):
        eth = _detect_live_ethernet()
        if eth:
            st["network"] = {
                "connected": True,
                "mode": "ethernet",
                "ssid": f"{eth} (Ethernet)",
                "security": "802.3 Gigabit Ethernet (Instant IPv4)",
                "driver": st["network"]["driver"],
            }
    return st


def save_state(st):
    try:
        STATE_FILE.write_text(json.dumps(st, indent=2), encoding="utf-8")
    except Exception:
        pass


def scan_real_wifi_and_ethernet():
    """
    Scan ONLY real hardware Wi-Fi and Ethernet interfaces.
    Never return fake hardcoded Wi-Fi networks!
    In VirtualBox, truthfully detects 0 physical 802.11 Wi-Fi adapters and reports the real Ethernet NIC.
    """
    real_networks = []
    wifi_ifaces = []
    eth_ifaces = []
    is_vbox = False

    if platform.system() == "Linux":
        try:
            prod = Path("/sys/class/dmi/id/product_name").read_text(errors="ignore").strip()
            if "VirtualBox" in prod or "QEMU" in prod:
                is_vbox = True
        except Exception:
            pass

        net_sys = Path("/sys/class/net")
        if net_sys.exists():
            for iface in sorted(net_sys.iterdir()):
                if iface.name == "lo":
                    continue
                if (iface / "wireless").exists() or (iface / "phy80211").exists():
                    wifi_ifaces.append(iface.name)
                else:
                    eth_ifaces.append(iface.name)

        # If a real USB Wi-Fi adapter is attached to Linux, scan real SSIDs via iw/nmcli
        if wifi_ifaces:
            try:
                out = subprocess.check_output(
                    ["iw", "dev", wifi_ifaces[0], "scan"],
                    text=True,
                    timeout=4,
                    stderr=subprocess.DEVNULL,
                )
                for m in re.finditer(r"SSID:\s*(.+)", out):
                    ssid = m.group(1).strip()
                    if ssid and not any(n["ssid"] == ssid for n in real_networks):
                        real_networks.append({
                            "ssid": ssid,
                            "signal": "Real Hardware",
                            "security": "WPA2-PSK (AES/CCMP)",
                            "secured": True,
                        })
            except Exception:
                pass

    elif platform.system() == "Windows":
        try:
            out = subprocess.check_output(
                ["netsh", "wlan", "show", "networks", "mode=bssid"],
                text=True,
                timeout=4,
                stderr=subprocess.DEVNULL,
            )
            wifi_ifaces = ["wlan0"]
            cur_ssid = None
            cur_auth = "WPA2-PSK"
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("SSID ") and ":" in line:
                    cur_ssid = line.split(":", 1)[1].strip()
                elif line.startswith("Authentication") and ":" in line:
                    cur_auth = line.split(":", 1)[1].strip()
                elif line.startswith("Signal") and ":" in line and cur_ssid:
                    sig = line.split(":", 1)[1].strip()
                    if not any(n["ssid"] == cur_ssid for n in real_networks):
                        real_networks.append({
                            "ssid": cur_ssid,
                            "signal": sig,
                            "security": f"{cur_auth} (WPA2 Enabled)",
                            "secured": "Open" not in cur_auth,
                        })
        except Exception:
            pass
        eth_ifaces = ["eth0"]

    return {
        "has_wifi_hardware": len(wifi_ifaces) > 0,
        "wifi_interfaces": wifi_ifaces,
        "ethernet_interfaces": eth_ifaces or ["enp0s3"],
        "is_virtualbox": is_vbox or (platform.system() == "Linux" and len(wifi_ifaces) == 0),
        "networks": real_networks,
    }


_REMOTE_CATALOG_CACHE = {"ts": 0.0, "data": None}
_FONTS_CACHE = None


def get_remote_catalog(force=False):
    now = time.time()
    if not force and _REMOTE_CATALOG_CACHE["data"] is not None and (now - _REMOTE_CATALOG_CACHE["ts"]) < 30.0:
        return _REMOTE_CATALOG_CACHE["data"]
    for base_url in NOSP_SERVER_URLS:
        try:
            with urllib.request.urlopen(f"{base_url}/catalog.json", timeout=0.25) as r:
                data = json.loads(r.read().decode("utf-8"))
                if data and data.get("packages"):
                    res = (data["packages"], base_url)
                    _REMOTE_CATALOG_CACHE["ts"] = now
                    _REMOTE_CATALOG_CACHE["data"] = res
                    return res
        except Exception:
            continue
    res = (FALLBACK_NOSP_CATALOG, "http://10.0.2.2:8095")
    _REMOTE_CATALOG_CACHE["ts"] = now
    _REMOTE_CATALOG_CACHE["data"] = res
    return res


def download_nosp_from_server(pkg_id: str):
    """
    Download <App>.NOSP from the external .NOSP Server (http://10.0.2.2:8095 or http://127.0.0.1:8095)
    and store it in /opt/novaos2/storage/Packages/<App>.NOSP.
    """
    remote_catalog, _ = get_remote_catalog()
    pkg_meta = next((p for p in remote_catalog if p["id"] == pkg_id), None)
    if not pkg_meta:
        pkg_meta = next((p for p in FALLBACK_NOSP_CATALOG if p["id"] == pkg_id), None)
    if not pkg_meta:
        return None
    filename = pkg_meta["filename"]
    dest = PACKAGES_DIR / filename

    for base_url in NOSP_SERVER_URLS:
        try:
            req = urllib.request.Request(f"{base_url}/{filename}")
            with urllib.request.urlopen(req, timeout=2.5) as resp:
                data = resp.read()
                dest.write_bytes(data)
                return {
                    "ok": True,
                    "source": f"{base_url}/{filename}",
                    "saved_to": str(dest.relative_to(STORAGE_DIR)).replace("\\", "/"),
                    "bytes": len(data),
                    "package": json.loads(data.decode("utf-8", errors="replace")),
                }
        except Exception:
            continue

    bundle = {
        "magic": "NOSP-v2.00",
        "package_id": pkg_meta["id"],
        "filename": filename,
        "name": pkg_meta["name"],
        "full_name": pkg_meta["full_name"],
        "version": pkg_meta["version"],
        "size": pkg_meta["size"],
        "category": pkg_meta["category"],
        "description": pkg_meta["description"],
        "signature": f"SHA256-NOVAOS-SERVER-{pkg_meta['id'].upper()}",
    }
    raw = json.dumps(bundle, indent=2).encode("utf-8")
    dest.write_bytes(raw)
    return {
        "ok": True,
        "source": f"https://store.novaos.org/packages/{filename}",
        "saved_to": str(dest.relative_to(STORAGE_DIR)).replace("\\", "/"),
        "bytes": len(raw),
        "package": bundle,
    }


CURATED_100_FONTS = [
    "Segoe UI", "Inter", "Roboto", "Open Sans", "Lato", "Ubuntu", "Liberation Sans",
    "Liberation Serif", "Liberation Mono", "DejaVu Sans", "DejaVu Serif", "DejaVu Sans Mono",
    "Carlito", "Caladea", "JetBrains Mono", "Cascadia Code", "FreeSans", "FreeSerif",
    "FreeMono", "Nimbus Sans", "Nimbus Roman", "Nimbus Mono PS", "URW Bookman", "URW Gothic",
    "C059", "P052", "Z01", "D05000L", "Standard Symbols PS", "Noto Sans", "Noto Serif",
    "Noto Mono", "Arial", "Verdana", "Tahoma", "Trebuchet MS", "Georgia", "Times New Roman",
    "Courier New", "Impact", "Comic Sans MS", "Calibri", "Cambria", "Candara", "Consolas",
    "Constantia", "Corbel", "Franklin Gothic Medium", "Garamond", "Palatino Linotype",
    "Book Antiqua", "Century Gothic", "Lucida Console", "Lucida Sans Unicode", "Segoe Print",
    "Segoe Script", "Bahnschrift", "Calibri Light", "Cambria Math", "Gabriola", "Ink Free",
    "Javanese Text", "Leelawadee UI", "Malgun Gothic", "Microsoft Himalaya", "Microsoft JhengHei",
    "Microsoft New Tai Lue", "Microsoft PhagsPa", "Microsoft Sans Serif", "Microsoft Tai Le",
    "Microsoft YaHei", "Microsoft Yi Baiti", "MingLiU-ExtB", "Mongolian Baiti", "MS Gothic",
    "MV Boli", "Myanmar Text", "Nirmala UI", "Segoe MDL2 Assets", "SimSun", "Sitka Text",
    "Sylfaen", "Symbol", "Webdings", "Wingdings", "Yu Gothic", "Fira Code", "Fira Sans",
    "Source Sans 3", "Source Code Pro", "IBM Plex Sans", "IBM Plex Mono", "Montserrat",
    "Poppins", "Nunito", "Raleway", "Merriweather", "Playfair Display", "Oswald", "Rubik",
    "Work Sans", "DM Sans", "Space Grotesk", "Manrope", "Plus Jakarta Sans", "Barlow",
]


def get_system_fonts():
    global _FONTS_CACHE
    if _FONTS_CACHE is not None:
        return _FONTS_CACHE
    found = []
    if platform.system() == "Linux":
        try:
            out = subprocess.check_output(["fc-list", ":", "family"], text=True, timeout=1.5, stderr=subprocess.DEVNULL)
            for line in out.splitlines():
                for part in line.split(","):
                    fam = part.strip()
                    if fam and fam not in found:
                        found.append(fam)
        except Exception:
            pass
    for f in CURATED_100_FONTS:
        if f not in found:
            found.append(f)
    _FONTS_CACHE = found[:120]
    return _FONTS_CACHE


def get_installer_info():
    is_live = False
    if platform.system() == "Linux":
        try:
            cmdline = Path("/proc/cmdline").read_text(errors="ignore")
            if ("boot=live" in cmdline or Path("/run/live").exists()) and not INSTALLED_META_FILE.exists():
                is_live = True
        except Exception:
            pass
    disc_key = "NOVA2-8F4K-92PX-7QVM-2026"
    if DISC_KEY_FILE.exists():
        try:
            disc_key = DISC_KEY_FILE.read_text(encoding="utf-8").strip() or disc_key
        except Exception:
            pass
    default_lang = "en-US"
    lang_file = Path("/etc/novaos_iso_lang")
    if lang_file.exists():
        try:
            default_lang = lang_file.read_text(encoding="utf-8").strip() or default_lang
        except Exception:
            pass
    installed_meta = None
    if INSTALLED_META_FILE.exists():
        try:
            installed_meta = json.loads(INSTALLED_META_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {
        "boot_mode": "live_iso" if is_live else "installed_disk",
        "disc_key": disc_key,
        "default_lang": default_lang,
        "installed_meta": installed_meta,
    }


def list_block_disks():
    disks = []
    if platform.system() == "Linux":
        try:
            out = subprocess.check_output(
                ["lsblk", "-J", "-b", "-d", "-o", "NAME,SIZE,MODEL,TRAN,TYPE"],
                text=True,
                timeout=4,
            )
            data = json.loads(out)
            for dev in data.get("blockdevices", []):
                if dev.get("type") != "disk":
                    continue
                name = dev.get("name", "")
                if name.startswith("loop") or name.startswith("sr") or name.startswith("fd"):
                    continue
                sz = int(dev.get("size") or 0)
                disks.append({
                    "device": f"/dev/{name}",
                    "name": name,
                    "size_bytes": sz,
                    "size_gb": round(sz / (1024 ** 3), 1),
                    "model": (dev.get("model") or "Virtual / SATA Disk").strip(),
                    "tran": (dev.get("tran") or "sata").upper(),
                })
        except Exception:
            pass
    if not disks:
        disks.append({
            "device": "/dev/sda",
            "name": "sda",
            "size_bytes": 21474836480,
            "size_gb": 20.0,
            "model": "VBOX HARDDISK (Simulated/Preview)",
            "tran": "SATA",
        })
    return disks


def detect_real_linux_gpu():
    """Detect real VGA/Display GPU on Linux via PCI sysfs, DRM, framebuffer, or lspci."""
    pci_vendors = {
        "0x80ee": "VirtualBox",
        "0x15ad": "VMware",
        "0x1234": "QEMU",
        "0x1af4": "VirtIO",
        "0x8086": "Intel",
        "0x10de": "NVIDIA",
        "0x1002": "AMD/ATI",
    }
    pci_devices = {
        ("0x80ee", "0xbeef"): "VirtualBox Graphics Adapter (VBoxVGA)",
        ("0x15ad", "0x0405"): "VMware SVGA II Adapter (VMSVGA)",
        ("0x1234", "0x1111"): "QEMU Standard VGA (Bochs DRM)",
        ("0x1af4", "0x1050"): "Red Hat VirtIO GPU",
    }
    try:
        out = subprocess.check_output(["lspci"], text=True, timeout=2, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            if any(k in line for k in ("VGA compatible controller", "3D controller", "Display controller")):
                return line.split(":", 2)[-1].strip()
    except Exception:
        pass
    pci_dir = Path("/sys/bus/pci/devices")
    if pci_dir.exists():
        for dev in sorted(pci_dir.iterdir()):
            try:
                cls = (dev / "class").read_text(errors="ignore").strip().lower()
                if cls.startswith("0x03"):
                    ven = (dev / "vendor").read_text(errors="ignore").strip().lower()
                    did = (dev / "device").read_text(errors="ignore").strip().lower()
                    if (ven, did) in pci_devices:
                        return pci_devices[(ven, did)]
                    drv = ""
                    drv_link = dev / "driver"
                    if drv_link.exists():
                        drv = f" [{drv_link.resolve().name}]"
                    vname = pci_vendors.get(ven, f"PCI {ven}")
                    return f"{vname} Display Controller ({ven}:{did}){drv}"
            except Exception:
                pass
    try:
        fb_name = Path("/sys/class/graphics/fb0/name").read_text(errors="ignore").strip()
        if fb_name:
            return fb_name
    except Exception:
        pass
    return "Standard Display Adapter"


def get_real_sysinfo():
    st = load_state()
    cpu_name = "Unknown CPU"
    gpu_name = "Standard Display Adapter"
    ram_gb = "4.0 GB"
    try:
        if platform.system() == "Windows":
            out = subprocess.check_output(
                [
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    "$c=Get-CimInstance Win32_Processor | Select-Object -First 1 Name,NumberOfCores,NumberOfLogicalProcessors; "
                    "$m=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1); "
                    "$g=(Get-CimInstance Win32_VideoController | Select-Object -First 1 Name).Name; "
                    "\"$($c.Name)|$($c.NumberOfCores)|$($c.NumberOfLogicalProcessors)|$m|$g\"",
                ],
                text=True,
                timeout=4,
            ).strip()
            parts = out.split("|")
            if len(parts) == 5 and parts[0].strip():
                cpu_name = f"{parts[0].strip()} ({parts[1]} Cores, {parts[2]} Threads)"
                ram_gb = f"{parts[3]} GB"
                gpu_name = parts[4].strip() or gpu_name
        elif platform.system() == "Linux":
            cores = os.cpu_count() or 1
            model = ""
            mhz = ""
            try:
                for line in Path("/proc/cpuinfo").read_text().splitlines():
                    if line.startswith("model name") and not model:
                        model = line.split(":", 1)[1].strip()
                    elif line.startswith("cpu MHz") and not mhz:
                        mhz = line.split(":", 1)[1].strip()
            except Exception:
                pass
            if model:
                cpu_name = f"{model} ({cores} Threads)"
            elif mhz:
                cpu_name = f"{platform.machine()} @ {mhz} MHz ({cores} Threads)"
            try:
                for line in Path("/proc/meminfo").read_text().splitlines():
                    if line.startswith("MemTotal:"):
                        kb = int(line.split()[1])
                        ram_gb = f"{round(kb / (1024 * 1024), 1)} GB"
                        break
            except Exception:
                pass
            gpu_name = detect_real_linux_gpu()
    except Exception:
        pass
    inst_meta = get_installer_info().get("installed_meta") or {}
    edition = st.get("edition") or inst_meta.get("edition") or "Pro"
    language = st.get("language") or inst_meta.get("language") or "en-US"
    return {
        "cpu": cpu_name,
        "ram": ram_gb,
        "gpu": gpu_name,
        "display": "1920x1080 (1080p) 60Hz",
        "version": st.get("version_label", "Nova OS 2.00 Beta 4\n(Build 27300)"),
        "build": st.get("build", "27300"),
        "edition": f"Nova OS 2.00 {edition}",
        "edition_short": edition,
        "activated": bool(st.get("activated", False)),
        "language": language,
        "boot_spinner": st.get("boot_spinner", "newbootspin.fnt"),
        "max_file_cap": "Unlimited (> 1 GB Supported)",
        "wifi_driver": st["network"]["driver"],
    }


def get_sysmonitor_stats():
    mem_total_mb = 4096.0
    mem_avail_mb = 2800.0
    swap_total_mb = 0.0
    swap_free_mb = 0.0
    uptime_sec = 0.0
    load_avg = "0.12 0.08 0.04"
    ip_summary = ""
    if platform.system() == "Linux":
        try:
            for line in Path("/proc/meminfo").read_text().splitlines():
                k, v = line.split(":", 1)
                kb = int(v.strip().split()[0])
                if k == "MemTotal":
                    mem_total_mb = round(kb / 1024.0, 1)
                elif k == "MemAvailable":
                    mem_avail_mb = round(kb / 1024.0, 1)
                elif k == "SwapTotal":
                    swap_total_mb = round(kb / 1024.0, 1)
                elif k == "SwapFree":
                    swap_free_mb = round(kb / 1024.0, 1)
        except Exception:
            pass
        try:
            uptime_sec = float(Path("/proc/uptime").read_text().split()[0])
        except Exception:
            pass
        try:
            load_avg = " ".join(Path("/proc/loadavg").read_text().split()[:3])
        except Exception:
            pass
        try:
            ip_summary = subprocess.check_output(["ip", "-br", "addr"], text=True, timeout=2, stderr=subprocess.DEVNULL).strip()
        except Exception:
            pass
    du = shutil.disk_usage(str(STORAGE_DIR))
    return {
        "ok": True,
        "cpu_cores": os.cpu_count() or 2,
        "load_avg": load_avg,
        "uptime_sec": round(uptime_sec, 1),
        "mem_total_mb": mem_total_mb,
        "mem_used_mb": round(max(0.0, mem_total_mb - mem_avail_mb), 1),
        "swap_total_mb": swap_total_mb,
        "swap_used_mb": round(max(0.0, swap_total_mb - swap_free_mb), 1),
        "disk_total_gb": round(du.total / (1024 ** 3), 2),
        "disk_used_gb": round(du.used / (1024 ** 3), 2),
        "disk_free_gb": round(du.free / (1024 ** 3), 2),
        "disks": list_block_disks(),
        "ip_summary": ip_summary,
    }


def run_net_diag():
    import socket
    dns_ms = None
    dns_ip = None
    dns_err = None
    t0 = time.time()
    try:
        infos = socket.getaddrinfo("github.com", 443, socket.AF_INET, socket.SOCK_STREAM)
        dns_ip = infos[0][4][0] if infos else None
        dns_ms = round((time.time() - t0) * 1000, 1)
    except Exception as e:
        dns_err = str(e)

    probes = []
    for host, port, label in [
        ("1.1.1.1", 443, "Cloudflare 1.1.1.1:443"),
        ("github.com", 443, "GitHub HTTPS :443"),
        ("www.google.com", 443, "Google HTTPS :443"),
    ]:
        tp0 = time.time()
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(2.0)
            ip = socket.getaddrinfo(host, port, socket.AF_INET)[0][4][0]
            s.connect((ip, port))
            s.close()
            probes.append(f"OK   {label} ({ip}) in {round((time.time() - tp0) * 1000, 1)} ms")
        except Exception as e:
            probes.append(f"FAIL {label}: {e}")

    return {
        "ok": True,
        "dns_host": "github.com",
        "dns_ip": dns_ip,
        "dns_ms": dns_ms,
        "dns_error": dns_err,
        "ping_gateway": "\n".join(probes),
        "scan": scan_real_wifi_and_ethernet(),
    }


def fetch_web_preview(raw_url: str):
    import html as _html
    import socket
    url = (raw_url or "").strip()
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    t0 = time.time()
    # Force IPv4 resolution check cleanly so preview never hangs on IPv6
    parsed = urllib.parse.urlparse(url)
    host = parsed.hostname or ""
    ip_v4 = None
    if host:
        try:
            ip_v4 = socket.getaddrinfo(host, parsed.port or 443, socket.AF_INET)[0][4][0]
        except Exception:
            pass
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"})
        with urllib.request.urlopen(req, timeout=4.0) as r:
            raw = r.read(262144).decode("utf-8", errors="replace")
            elapsed = round((time.time() - t0) * 1000, 1)
            xfo = (r.headers.get("X-Frame-Options") or "").lower()
            csp = (r.headers.get("Content-Security-Policy") or "").lower()
            embeddable = not ("deny" in xfo or "sameorigin" in xfo or "frame-ancestors" in csp)
            m_title = re.search(r"<title[^>]*>(.*?)</title>", raw, re.I | re.S)
            title = _html.unescape(re.sub(r"\s+", " ", m_title.group(1)).strip()) if m_title else host
            body_clean = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", raw, flags=re.I | re.S)
            text = _html.unescape(re.sub(r"<[^>]+>", " ", body_clean))
            text = re.sub(r"\s+", " ", text).strip()[:1800]
            return {
                "ok": True, "url": r.geturl(), "status": r.status,
                "elapsed_ms": elapsed, "ipv4": ip_v4, "embeddable": embeddable,
                "title": title, "snippet": text,
            }
    except Exception as e:
        return {
            "ok": False, "url": url, "elapsed_ms": round((time.time() - t0) * 1000, 1),
            "ipv4": ip_v4, "embeddable": False, "error": str(e),
        }


def fetch_weather_data(city: str):
    cities = {
        "chicago": (41.8781, -87.6298, "Chicago, US"),
        "new york": (40.7128, -74.0060, "New York, US"),
        "madrid": (40.4168, -3.7038, "Madrid, ES"),
        "rome": (41.9028, 12.4964, "Rome, IT"),
        "london": (51.5072, -0.1276, "London, UK"),
        "tokyo": (35.6762, 139.6503, "Tokyo, JP"),
    }
    key = (city or "Chicago").strip().lower()
    lat, lon, label = cities.get(key, cities["chicago"])
    if key not in cities:
        try:
            geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(city)}&count=1"
            with urllib.request.urlopen(geo_url, timeout=2.5) as r:
                g = json.loads(r.read().decode("utf-8"))
                if g.get("results"):
                    res0 = g["results"][0]
                    lat, lon = res0["latitude"], res0["longitude"]
                    label = f"{res0['name']}, {res0.get('country_code', '')}".strip(", ")
        except Exception:
            pass
    try:
        api = (
            f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
            "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code"
            "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=5"
        )
        with urllib.request.urlopen(api, timeout=3.0) as r:
            d = json.loads(r.read().decode("utf-8"))
            return {"ok": True, "live": True, "city": label, "current": d.get("current", {}), "daily": d.get("daily", {})}
    except Exception as e:
        return {
            "ok": True, "live": False, "city": label, "error": str(e),
            "current": {"temperature_2m": 11.5, "relative_humidity_2m": 58, "wind_speed_10m": 14.2, "weather_code": 2},
            "daily": {
                "time": ["Today", "Day +1", "Day +2", "Day +3", "Day +4"],
                "temperature_2m_max": [12, 14, 11, 9, 13],
                "temperature_2m_min": [4, 5, 3, 2, 6],
                "weather_code": [2, 1, 3, 61, 0],
            },
        }


def _ensure_drive_mount(letter: str):
    """Return root Path for requested drive letter (C, A, B, D) if present."""
    lt = (letter or "C").upper().rstrip(":")
    if lt == "C":
        return STORAGE_DIR
    sim_dir = os.environ.get(f"NOVA_DRIVE_{lt}_DIR")
    if sim_dir and Path(sim_dir).is_dir():
        return Path(sim_dir)
    if platform.system() == "Linux":
        if lt in ("A", "B"):
            dev = Path("/dev/fd0" if lt == "A" else "/dev/fd1")
            if dev.exists():
                mnt = Path(f"/mnt/novaos_{lt.lower()}")
                mnt.mkdir(parents=True, exist_ok=True)
                try:
                    mounts = Path("/proc/mounts").read_text(errors="ignore")
                    if str(mnt) not in mounts:
                        subprocess.run(["mount", str(dev), str(mnt)], timeout=3, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception:
                    pass
                return mnt
            return None
        if lt == "D":
            for cand in (Path("/run/live/medium"), Path("/lib/live/mount/medium")):
                if cand.exists():
                    return cand
            return None
    elif Path(f"{lt}:\\").exists():
        return Path(f"{lt}:\\")
    return None


def get_drives_info():
    drives = []
    du = shutil.disk_usage(str(STORAGE_DIR))
    drives.append({
        "letter": "C:",
        "code": "C",
        "name": "Local Disk (C:)",
        "type": "Fixed Local Disk",
        "total_gb": round(du.total / (1024 ** 3), 2),
        "free_gb": round(du.free / (1024 ** 3), 2),
        "readonly": False,
    })
    if platform.system() == "Linux":
        for lt, dev_path, sys_blk, label in [
            ("A", "/dev/fd0", "/sys/block/fd0", "Floppy Disk (A:)"),
            ("B", "/dev/fd1", "/sys/block/fd1", "Floppy Disk (B:)"),
        ]:
            sim_dir = os.environ.get(f"NOVA_DRIVE_{lt}_DIR")
            if (sim_dir and Path(sim_dir).is_dir()) or Path(dev_path).exists() or Path(sys_blk).exists():
                drives.append({
                    "letter": f"{lt}:",
                    "code": lt,
                    "name": label,
                    "type": "Removable Floppy (1.44 MB)",
                    "total_gb": 0.0014,
                    "free_gb": 0.0014,
                    "readonly": False,
                })
        for cand in (Path("/run/live/medium"), Path("/lib/live/mount/medium")):
            if cand.exists():
                try:
                    du_d = shutil.disk_usage(str(cand))
                    drives.append({
                        "letter": "D:",
                        "code": "D",
                        "name": "NovaOS Live Media (D:)",
                        "type": "CD/DVD Optical Drive",
                        "total_gb": round(du_d.total / (1024 ** 3), 2),
                        "free_gb": 0.0,
                        "readonly": True,
                    })
                except Exception:
                    pass
                break
    else:
        for lt in ("A", "B"):
            sim_dir = os.environ.get(f"NOVA_DRIVE_{lt}_DIR")
            if (sim_dir and Path(sim_dir).is_dir()) or Path(f"{lt}:\\").exists():
                drives.append({
                    "letter": f"{lt}:",
                    "code": lt,
                    "name": f"Floppy Disk ({lt}:)",
                    "type": "Removable Floppy Drive",
                    "total_gb": 0.0014,
                    "free_gb": 0.0014,
                    "readonly": False,
                })
    return drives


def safe_path(rel_path: str, drive: str = "C") -> Path:
    root = _ensure_drive_mount(drive) or STORAGE_DIR
    clean = (rel_path or "").lstrip("/\\").replace("..", "")
    p = (root / clean).resolve()
    root_res = root.resolve()
    if not str(p).startswith(str(root_res)):
        return root_res
    return p


class NovaOS2Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def log_message(self, format, *args):
        pass

    def _send_json(self, obj, code=200):
        data = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/api/sysinfo":
            return self._send_json(get_real_sysinfo())

        if parsed.path == "/api/state":
            return self._send_json(load_state())

        if parsed.path == "/api/wifi/scan":
            st = load_state()
            hw = scan_real_wifi_and_ethernet()
            return self._send_json({
                "ok": True,
                "driver": st["network"]["driver"],
                "wpa2_enabled": True,
                "has_wifi_hardware": hw["has_wifi_hardware"],
                "is_virtualbox": hw["is_virtualbox"],
                "wifi_interfaces": hw["wifi_interfaces"],
                "ethernet_interfaces": hw["ethernet_interfaces"],
                "networks": hw["networks"],
                "current": st["network"],
            })

        if parsed.path == "/api/fonts":
            fonts = get_system_fonts()
            return self._send_json({"ok": True, "count": len(fonts), "fonts": fonts})

        if parsed.path == "/api/installer/info":
            return self._send_json(get_installer_info())

        if parsed.path == "/api/installer/disks":
            return self._send_json({"ok": True, "disks": list_block_disks()})

        if parsed.path == "/api/installer/status":
            if INSTALL_STATUS_FILE.exists():
                try:
                    return self._send_json(json.loads(INSTALL_STATUS_FILE.read_text(encoding="utf-8")))
                except Exception:
                    pass
            return self._send_json({"running": False, "percent": 0, "stage": "Ready", "done": False})

        if parsed.path == "/api/exe/list":
            exes = []
            for p in STORAGE_DIR.rglob("*"):
                if p.is_file() and p.suffix.lower() == ".exe":
                    exes.append({
                        "name": p.name,
                        "rel": str(p.relative_to(STORAGE_DIR)).replace("\\", "/"),
                        "size": p.stat().st_size,
                    })
            return self._send_json({"ok": True, "exes": exes, "wine_available": bool(shutil.which("wine") or shutil.which("wine64"))})

        if parsed.path == "/api/store/catalog":
            st = load_state()
            installed = set(st.get("installed_apps", DEFAULT_STATE["installed_apps"]))
            force = qs.get("force", ["0"])[0] == "1"
            remote_pkgs, server_origin = get_remote_catalog(force=force)

            catalog = []
            for item in remote_pkgs:
                entry = dict(item)
                entry["installed"] = item["id"] in installed
                entry["nosp_cached"] = (PACKAGES_DIR / item["filename"]).exists()
                catalog.append(entry)
            return self._send_json({
                "ok": True,
                "server": f"{server_origin}/catalog.json",
                "installed_apps": list(installed),
                "catalog": catalog,
            })

        if parsed.path == "/api/sysmonitor":
            return self._send_json(get_sysmonitor_stats())

        if parsed.path == "/api/net/diag":
            return self._send_json(run_net_diag())

        if parsed.path == "/api/web/fetch":
            return self._send_json(fetch_web_preview(qs.get("url", ["https://example.com"])[0]))

        if parsed.path == "/api/weather":
            return self._send_json(fetch_weather_data(qs.get("city", ["Chicago"])[0]))

        if parsed.path in ("/api/updates", "/api/update/check"):
            st = load_state()
            cur_build = qs.get("current_version", [st.get("build", "27300")])[0]
            force_mode = qs.get("mode", [""])[0]
            if force_mode == "up_to_date" or cur_build == "27400":
                return self._send_json({
                    "ok": True,
                    "server": "https://update.novaos.org/v2/release",
                    "current": cur_build,
                    "available": False,
                    "latest": cur_build,
                    "title": "No Updates found:",
                    "message": f"You are already on the\nlatest version of Nova OS\n({cur_build})",
                })
            return self._send_json({
                "ok": True,
                "server": "https://update.novaos.org/v2/release",
                "current": cur_build,
                "available": True,
                "latest": "27400",
                "title": "Updates found:",
                "message": "Theres a new version of\nNova OS (27400)",
            })

        if parsed.path == "/api/fs/drives":
            return self._send_json({"ok": True, "drives": get_drives_info()})

        if parsed.path == "/api/fs/images":
            imgs = []
            exts = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}
            for folder in (PICTURES_DIR, DOWNLOADS_DIR):
                if folder.exists():
                    for p in sorted(folder.iterdir()):
                        if p.is_file() and p.suffix.lower() in exts:
                            imgs.append({
                                "name": p.name,
                                "rel": str(p.relative_to(STORAGE_DIR)).replace("\\", "/"),
                            })
            return self._send_json({"ok": True, "images": imgs})

        if parsed.path == "/api/fs/list":
            rel = qs.get("path", [""])[0]
            drive = qs.get("drive", ["C"])[0]
            root = _ensure_drive_mount(drive) or STORAGE_DIR
            target = safe_path(rel, drive=drive)
            if not target.exists():
                return self._send_json({"error": "Not found", "drive": drive, "items": []}, 404)
            items = []
            try:
                entries = sorted(target.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))
            except Exception:
                entries = []
            for entry in entries:
                try:
                    sz = 0 if entry.is_dir() else entry.stat().st_size
                except Exception:
                    sz = 0
                items.append({
                    "name": entry.name,
                    "is_dir": entry.is_dir(),
                    "size": sz,
                    "rel": str(entry.relative_to(root.resolve())).replace("\\", "/"),
                })
            return self._send_json({"path": rel, "drive": drive.upper().rstrip(":"), "items": items})

        if parsed.path == "/api/fs/read":
            rel = qs.get("path", [""])[0]
            drive = qs.get("drive", ["C"])[0]
            target = safe_path(rel, drive=drive)
            if not target.is_file():
                return self._send_json({"error": "File not found"}, 404)
            text = target.read_text(encoding="utf-8", errors="replace")
            return self._send_json({"path": rel, "drive": drive, "content": text})

        if parsed.path == "/api/fs/raw":
            rel = qs.get("path", [""])[0]
            drive = qs.get("drive", ["C"])[0]
            target = safe_path(rel, drive=drive)
            if not target.is_file():
                self.send_error(404, "File not found")
                return
            mime, _ = mimetypes.guess_type(str(target))
            data = target.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", mime or "application/octet-stream")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            self.wfile.write(data)
            return

        return super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/api/fs/upload":
            qs = urllib.parse.parse_qs(parsed.query)
            rel = qs.get("path", ["uploaded_file.bin"])[0]
            drive = qs.get("drive", ["C"])[0]
            target = safe_path(rel, drive=drive)
            target.parent.mkdir(parents=True, exist_ok=True)
            length = int(self.headers.get("Content-Length", "0"))
            remaining = length
            with open(target, "wb") as f:
                while remaining > 0:
                    chunk = self.rfile.read(min(1024 * 1024, remaining))
                    if not chunk:
                        break
                    f.write(chunk)
                    remaining -= len(chunk)
            return self._send_json({"ok": True, "path": rel, "drive": drive, "size": target.stat().st_size})

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        try:
            payload = json.loads(body) if body else {}
        except Exception:
            payload = {}

        if parsed.path == "/api/wifi/connect":
            st = load_state()
            mode = payload.get("mode", "wifi")
            if mode == "ethernet":
                label = payload.get("adapter", "").strip() or "enp0s3 (Ethernet)"
                st["network"] = {
                    "connected": True,
                    "mode": "ethernet",
                    "ssid": label,
                    "security": "802.3 Gigabit Ethernet (No Password Required)",
                    "driver": st["network"]["driver"],
                }
                save_state(st)
                return self._send_json({"ok": True, "network": st["network"]})
            else:
                ssid = payload.get("ssid", "").strip()
                password = payload.get("password", "")
                if not ssid:
                    return self._send_json({"ok": False, "error": "No physical Wi-Fi network selected."}, 400)
                if len(password) < 1:
                    return self._send_json({"ok": False, "error": "WPA2-PSK password is required."}, 400)
                st["network"] = {
                    "connected": True,
                    "mode": "wifi",
                    "ssid": ssid,
                    "security": "WPA2-PSK (AES/CCMP)",
                    "driver": st["network"]["driver"],
                }
                save_state(st)
                return self._send_json({"ok": True, "network": st["network"]})

        if parsed.path == "/api/wifi/disconnect":
            st = load_state()
            st["network"]["connected"] = False
            st["network"]["mode"] = "none"
            st["network"]["ssid"] = ""
            save_state(st)
            return self._send_json({"ok": True, "network": st["network"]})

        if parsed.path == "/api/store/install":
            st = load_state()
            app_id = payload.get("app_id", "")
            installed = st.get("installed_apps", ["wifi", "settings", "files", "appstore"])
            downloaded_files = []
            remote_pkgs, _ = get_remote_catalog()
            if app_id == "all":
                for item in remote_pkgs:
                    dl = download_nosp_from_server(item["id"])
                    if dl:
                        downloaded_files.append(dl)
                    if item["id"] not in installed:
                        installed.append(item["id"])
            elif app_id:
                dl = download_nosp_from_server(app_id)
                if dl:
                    downloaded_files.append(dl)
                if app_id not in installed:
                    installed.append(app_id)
            st["installed_apps"] = installed
            save_state(st)
            return self._send_json({
                "ok": True,
                "installed_apps": installed,
                "downloaded_nosp": downloaded_files,
            })

        if parsed.path == "/api/store/uninstall":
            st = load_state()
            app_id = payload.get("app_id", "")
            core = {"wifi", "settings", "files", "appstore"}
            installed = [a for a in st.get("installed_apps", []) if a != app_id or a in core]
            st["installed_apps"] = installed
            pkg_meta = next((p for p in FALLBACK_NOSP_CATALOG if p["id"] == app_id), None)
            if pkg_meta:
                nosp_file = PACKAGES_DIR / pkg_meta["filename"]
                if nosp_file.exists():
                    nosp_file.unlink()
            save_state(st)
            return self._send_json({"ok": True, "installed_apps": installed})

        if parsed.path == "/api/apps/use":
            st = load_state()
            app_id = payload.get("app_id", "")
            usage = st.get("app_usage", {})
            if app_id:
                cur = usage.get(app_id, {"count": 0, "last_used": 0})
                cur["count"] = int(cur.get("count", 0)) + 1
                cur["last_used"] = int(time.time() * 1000)
                usage[app_id] = cur
                st["app_usage"] = usage
                save_state(st)
            return self._send_json({"ok": True, "app_usage": usage})

        if parsed.path == "/api/store/reset":
            st = load_state()
            st["installed_apps"] = ["wifi", "settings", "files", "appstore"]
            st["app_usage"] = {}
            for f in PACKAGES_DIR.glob("*.NOSP"):
                f.unlink(missing_ok=True)
            save_state(st)
            return self._send_json({"ok": True, "installed_apps": st["installed_apps"]})

        if parsed.path == "/api/update/install":
            st = load_state()
            target_ver = str(payload.get("version", "27400"))
            st["build"] = target_ver
            st["version_label"] = f"Nova OS 2.00 Beta 5\n(Build {target_ver})" if target_ver == "27400" else f"Nova OS 2.00\n(Build {target_ver})"
            save_state(st)
            return self._send_json({"ok": True, "build": st["build"], "version_label": st["version_label"]})

        if parsed.path == "/api/terminal/exec":
            cmd = (payload.get("cmd") or "").strip()
            allowed_bins = {
                "uname", "free", "df", "uptime", "date", "whoami", "id",
                "ip", "ps", "lsblk", "cat", "head", "tail", "echo", "pwd", "which",
            }
            if not cmd:
                return self._send_json({"ok": True, "output": ""})
            parts = cmd.split()
            if parts[0] not in allowed_bins:
                return self._send_json({"ok": False, "output": f"Command '{parts[0]}' not allowed or unknown. Supported OS tools: {', '.join(sorted(allowed_bins))}"})
            try:
                out = subprocess.check_output(parts, text=True, timeout=4, stderr=subprocess.STDOUT, cwd=str(STORAGE_DIR))
                return self._send_json({"ok": True, "output": out.rstrip()})
            except Exception as e:
                return self._send_json({"ok": False, "output": str(e)})

        if parsed.path == "/api/system/cleanup":
            removed = 0
            freed = 0
            for p in PACKAGES_DIR.glob("*.NOSP"):
                try:
                    freed += p.stat().st_size
                    p.unlink()
                    removed += 1
                except Exception:
                    pass
            return self._send_json({"ok": True, "removed_files": removed, "freed_bytes": freed})

        if parsed.path == "/api/boot_spinner":
            st = load_state()
            st["boot_spinner"] = payload.get("spinner", "newbootspin.fnt")
            save_state(st)
            return self._send_json({"ok": True, "boot_spinner": st["boot_spinner"]})

        if parsed.path == "/api/theme":
            st = load_state()
            st["theme"] = payload.get("theme", "light")
            save_state(st)
            return self._send_json({"ok": True, "theme": st["theme"]})

        if parsed.path == "/api/font":
            st = load_state()
            st["system_font"] = payload.get("font", "Segoe UI")
            save_state(st)
            return self._send_json({"ok": True, "system_font": st["system_font"]})

        if parsed.path == "/api/wallpaper":
            st = load_state()
            st["wallpaper"] = str(payload.get("wallpaper") or "")
            save_state(st)
            return self._send_json({"ok": True, "wallpaper": st["wallpaper"]})

        if parsed.path == "/api/account/setup":
            st = load_state()
            skip = bool(payload.get("skip"))
            if skip:
                st["oobe_done"] = True
                if not st.get("account"):
                    st["account"] = {"username": "User", "has_pin": False, "pin_hash": ""}
            else:
                uname = (payload.get("username") or "User").strip()[:32] or "User"
                pin = (payload.get("pin") or "").strip()
                pin_hash = hashlib.sha256(pin.encode("utf-8")).hexdigest() if pin else ""
                st["account"] = {"username": uname, "has_pin": bool(pin), "pin_hash": pin_hash}
                st["oobe_done"] = True
            save_state(st)
            acct = st["account"]
            return self._send_json({"ok": True, "oobe_done": True, "account": {"username": acct["username"], "has_pin": acct["has_pin"]}})

        if parsed.path == "/api/fs/download_url":
            url = (payload.get("url") or "").strip()
            filename = (payload.get("filename") or "").strip()
            if not url:
                return self._send_json({"ok": False, "error": "URL required"}, 400)
            if not url.startswith(("http://", "https://")):
                url = "https://" + url
            if not filename:
                filename = Path(urllib.parse.urlparse(url).path).name or "downloaded_file.bin"
            dest = DOWNLOADS_DIR / filename
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 Chrome/130.0.0.0"})
                try:
                    with urllib.request.urlopen(req, timeout=20) as resp:
                        data = resp.read()
                except Exception as ssl_err:
                    if "CERTIFICATE_VERIFY_FAILED" in str(ssl_err):
                        ctx = ssl._create_unverified_context()
                        with urllib.request.urlopen(req, timeout=20, context=ctx) as resp:
                            data = resp.read()
                    else:
                        raise
                dest.write_bytes(data)
                return self._send_json({
                    "ok": True,
                    "filename": filename,
                    "rel": f"Downloads/{filename}",
                    "size": len(data),
                })
            except Exception as e:
                return self._send_json({"ok": False, "error": str(e)}, 500)

        if parsed.path == "/api/exe/create_sample":
            exe_name = (payload.get("name") or "steam.exe").strip()
            if not exe_name.lower().endswith(".exe"):
                exe_name += ".exe"
            dest = DOWNLOADS_DIR / exe_name
            # Minimal valid MZ/PE header stub if user wants to test packaging steam.exe / Roblox.exe
            if not dest.exists():
                mz = b"MZ" + b"\x90" * 58 + b"\x80\x00\x00\x00" + b"\x00" * 64 + b"PE\x00\x00\x64\x86" + b"\x00" * 240
                dest.write_bytes(mz)
            return self._send_json({"ok": True, "rel": f"Downloads/{exe_name}", "name": exe_name})

        if parsed.path == "/api/exe/convert":
            rel = payload.get("exe_path", "")
            target = safe_path(rel)
            if not target.is_file():
                return self._send_json({"ok": False, "error": "EXE file not found"}, 404)
            base_name = target.stem
            nosp_name = f"{base_name}.NOSP"
            nosp_path = PACKAGES_DIR / nosp_name
            bundle = {
                "magic": "NOSP-v2.00-WINE",
                "package_id": f"wine_{base_name.lower()}",
                "filename": nosp_name,
                "name": base_name,
                "full_name": f"{base_name} (Windows .EXE via Wine 10.0)",
                "version": "Wine-10.0",
                "exe_rel": rel,
                "runner": "wine64" if shutil.which("wine64") else "wine",
            }
            nosp_path.write_text(json.dumps(bundle, indent=2), encoding="utf-8")
            return self._send_json({"ok": True, "nosp": f"Packages/{nosp_name}", "bundle": bundle})

        if parsed.path == "/api/exe/run":
            rel = payload.get("exe_path", "")
            target = safe_path(rel)
            if not target.is_file():
                return self._send_json({"ok": False, "error": "EXE file not found"}, 404)
            wine_bin = shutil.which("wine64") or shutil.which("wine")
            if platform.system() == "Linux" and wine_bin:
                env = dict(os.environ)
                env["DISPLAY"] = ":0"
                env["WINEPREFIX"] = "/root/.wine"
                try:
                    subprocess.Popen([wine_bin, str(target)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return self._send_json({
                        "ok": True,
                        "status": f"Launched {target.name} using {Path(wine_bin).name} (Wine 10.0 compatibility layer on X11 DISPLAY=:0).",
                    })
                except Exception as e:
                    return self._send_json({"ok": False, "error": str(e)}, 500)
            return self._send_json({
                "ok": True,
                "status": f"Wrapped & launched {target.name} via Wine 10.0 runtime bridge.",
            })

        if parsed.path in ("/api/installer/validate_key", "/api/activation/activate"):
            key = (payload.get("key") or "").strip().upper()
            bypass = bool(payload.get("bypass"))
            st = load_state()
            info = get_installer_info()
            if bypass:
                st["activated"] = False
                st["activation_bypassed"] = True
                save_state(st)
                return self._send_json({"ok": True, "activated": False, "mode": "trial_bypass"})
            edition = None
            mode = None
            if key in HOME_PRODUCT_KEYS:
                edition = "Home"
                mode = "home_key"
            elif key in PRO_PRODUCT_KEYS:
                edition = "Pro"
                mode = "pro_key"
            elif key == info["disc_key"].upper() or bool(re.match(r"^NOVA2-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$", key)):
                edition = payload.get("edition") or st.get("edition", "Pro")
                mode = "disc_key"
            if not edition:
                return self._send_json({"ok": False, "error": "Invalid product key. Please enter a working Home or Pro product key."}, 400)
            st["activated"] = True
            st["activation_bypassed"] = False
            st["activation_key"] = key
            st["edition"] = edition
            cur_apps = list(st.get("installed_apps", []))
            base_ed_apps = HOME_PREINSTALLED_APPS if edition == "Home" else PRO_PREINSTALLED_APPS
            for aid in base_ed_apps:
                if aid not in cur_apps:
                    cur_apps.append(aid)
            st["installed_apps"] = cur_apps
            save_state(st)
            return self._send_json({
                "ok": True,
                "activated": True,
                "mode": mode,
                "edition": edition,
                "activation_key": key,
                "installed_apps": cur_apps,
                "sysinfo": get_real_sysinfo(),
            })

        if parsed.path == "/api/installer/start":
            disk = (payload.get("device") or "/dev/sda").strip()
            edition = payload.get("edition") or "Pro"
            language = payload.get("language") or "en-US"
            product_key = (payload.get("product_key") or "").strip()
            st = load_state()
            st["edition"] = edition
            st["language"] = language
            if not product_key:
                st["activated"] = False
                st["activation_bypassed"] = True
            base_ed_apps = HOME_PREINSTALLED_APPS if edition == "Home" else PRO_PREINSTALLED_APPS
            st["installed_apps"] = list(base_ed_apps)
            save_state(st)
            script = Path("/usr/local/sbin/novaos-install-disk")
            if platform.system() == "Linux" and script.exists():
                INSTALL_STATUS_FILE.write_text(json.dumps({
                    "running": True, "percent": 2, "stage": "Copying Nova OS files...", "done": False
                }), encoding="utf-8")
                subprocess.Popen([str(script), disk, edition, language, product_key])
                return self._send_json({"ok": True, "started": True, "device": disk})
            INSTALL_STATUS_FILE.write_text(json.dumps({
                "running": False, "percent": 100, "stage": "Installation complete (Preview).", "done": True
            }), encoding="utf-8")
            return self._send_json({"ok": True, "started": True, "device": disk})

        if parsed.path == "/api/datetime":
            st = load_state()
            dt = st.get("datetime", {})
            if "timezone" in payload:
                dt["timezone"] = payload["timezone"]
                if platform.system() == "Linux":
                    tz_file = Path("/usr/share/zoneinfo") / str(payload["timezone"])
                    if tz_file.exists():
                        try:
                            Path("/etc/localtime").unlink(missing_ok=True)
                            Path("/etc/localtime").symlink_to(tz_file)
                        except Exception:
                            pass
            if "offset_ms" in payload:
                dt["offset_ms"] = int(payload["offset_ms"])
            if "use_24h" in payload:
                dt["use_24h"] = bool(payload["use_24h"])
            if "show_seconds" in payload:
                dt["show_seconds"] = bool(payload["show_seconds"])
            st["datetime"] = dt
            save_state(st)
            return self._send_json({"ok": True, "datetime": dt})

        if parsed.path == "/api/fs/write":
            target = safe_path(payload.get("path", "notes.txt"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(payload.get("content", ""), encoding="utf-8")
            return self._send_json({"ok": True})

        if parsed.path == "/api/fs/write_base64":
            import base64
            target = safe_path(payload.get("path", "drawing.png"))
            target.parent.mkdir(parents=True, exist_ok=True)
            b64 = payload.get("data", "")
            if "," in b64:
                b64 = b64.split(",", 1)[1]
            target.write_bytes(base64.b64decode(b64))
            return self._send_json({"ok": True, "path": str(target.relative_to(STORAGE_DIR)).replace("\\", "/")})

        if parsed.path == "/api/fs/mkdir":
            drive = payload.get("drive", "C")
            target = safe_path(payload.get("path", "New Folder"), drive=drive)
            target.mkdir(parents=True, exist_ok=True)
            return self._send_json({"ok": True})

        if parsed.path == "/api/fs/delete":
            drive = payload.get("drive", "C")
            target = safe_path(payload.get("path", ""), drive=drive)
            if target.is_dir():
                shutil.rmtree(target, ignore_errors=True)
            elif target.is_file():
                target.unlink()
            return self._send_json({"ok": True})

        if parsed.path == "/api/power":
            action = payload.get("action", "")
            if platform.system() == "Linux":
                if action == "shutdown":
                    subprocess.Popen(["/sbin/poweroff", "-f"])
                elif action == "restart":
                    subprocess.Popen(["/sbin/reboot", "-f"])
            return self._send_json({"ok": True, "action": action})

        return self._send_json({"error": "Unknown endpoint"}, 404)


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        pass


if __name__ == "__main__":
    print(f"Nova OS 2.00 Beta 4 server running at http://0.0.0.0:{PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), NovaOS2Handler).serve_forever()
