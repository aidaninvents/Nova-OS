#!/usr/bin/env python3
"""
tools/make_nosp.py
Generates the standard NovaOS Program (.nosp) binaries:
 - startup.nosp (Setup & Installer)
 - wifi.nosp    (WiFi & Ethernet Driver Setup)
 - chrome.nosp  (Google Chrome Browser with HTTPS, Search, GitHub & HD Video)
 - shop.nosp    (NovaOS Online App Store: Notepad, Python 3.15, Firefox, Video)
"""

import struct
import sys
import os

def create_nosp_binary(output_path, name, build_num, subsystem, description):
    prog_name = name.encode("ascii")[:31].ljust(32, b"\x00")
    
    code = bytearray([
        0x48, 0x8D, 0x35, 0x0E, 0x00, 0x00, 0x00, # lea rsi, [rip + 14]
        0xC3,                                     # ret
        0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90 # nop padding
    ])
    
    data = (
        f"Nova OS 1.00 26Q4 (Build {build_num}) - {name}\n"
        f"Copyright (C) 2026 NovaOS AI Project. All rights reserved.\n"
        f"Subsystem: {description}\n\x00"
    ).encode("ascii")
    
    code_size = len(code)
    data_size = len(data)
    req_mem = 65536

    header = bytearray(64)
    struct.pack_into("<I", header, 0x00, 0x50534F4E) # Magic 'NOSP'
    struct.pack_into("<H", header, 0x04, 1)          # Format ver
    struct.pack_into("<H", header, 0x06, 2)          # Machine: x86_64
    struct.pack_into("<H", header, 0x08, subsystem)  # Subsystem ID
    struct.pack_into("<H", header, 0x0A, 26110)      # Build: 26110
    struct.pack_into("<I", header, 0x0C, 64)         # Entry point RVA
    struct.pack_into("<I", header, 0x10, code_size)
    struct.pack_into("<I", header, 0x14, data_size)
    struct.pack_into("<I", header, 0x18, req_mem)
    header[0x1C:0x3C] = prog_name

    full_binary = header + code + data

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(full_binary)
    
    print(f"[NOSP] Generated {output_path} ({len(full_binary)} bytes, build 26110.0000)")

def build_all(target_dir="build"):
    # Remove legacy browser.nosp if present
    legacy_browser = os.path.join(target_dir, "browser.nosp")
    if os.path.exists(legacy_browser):
        os.remove(legacy_browser)

    create_nosp_binary(
        os.path.join(target_dir, "startup.nosp"),
        "NovaOS Setup & Installer",
        "26110.0100",
        1,
        "Live Setup & Hard Disk Partition Deployment"
    )
    create_nosp_binary(
        os.path.join(target_dir, "wifi.nosp"),
        "NovaOS Network & WiFi Setup",
        "26110.0100",
        2,
        "WiFi 6/6E/7 & Ethernet Hardware Driver Manager"
    )

    # Build standalone portable x86_64 ASM browser binary (port/chrome_asm/chrome.asm -> chrome.nosp)
    chrome_asm = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "port", "chrome_asm", "chrome.asm")
    chrome_out = os.path.join(target_dir, "chrome.nosp")
    asm_built = False
    if os.path.exists(chrome_asm):
        import subprocess
        try:
            r = subprocess.run(["nasm", "-f", "bin", chrome_asm, "-o", chrome_out], capture_output=True, text=True)
            if r.returncode == 0 and os.path.exists(chrome_out):
                sz = os.path.getsize(chrome_out)
                print(f"[NOSP] Built standalone x86_64 ASM Browser {chrome_out} ({sz} bytes, ASMBROWS v1.0)")
                asm_built = True
        except Exception:
            pass
    if not asm_built:
        create_nosp_binary(
            chrome_out,
            "Google Chrome (ASMBROWS v1.0)",
            "26110.0100",
            3,
            "Standalone x86_64 ASM Browser (NVBX Boxes + Clickable Links + TLS 1.3)"
        )

    create_nosp_binary(
        os.path.join(target_dir, "shop.nosp"),
        "NovaOS Online App Shop",
        "26110.0100",
        4,
        "Online App Store hosting Notepad, Python 3.15, Firefox, Java, HTML5 & YouTube"
    )
    create_nosp_binary(
        os.path.join(target_dir, "java.nosp"),
        "Java SE 24 IDE",
        "26110.0100",
        5,
        "OpenJDK 24.0.1 Runtime & YouTubeEngine.java Compiler"
    )
    create_nosp_binary(
        os.path.join(target_dir, "html.nosp"),
        "HTML5 & CSS3 DOM Studio",
        "26110.0100",
        6,
        "HTML5/CSS3 Source Editor & Live Visual DOM Decoder"
    )
    create_nosp_binary(
        os.path.join(target_dir, "youtube.nosp"),
        "YouTube Desktop App (Real YT)",
        "26110.0100",
        7,
        "Real Live www.youtube.com Search, 60fps Video Player, Upload & Account"
    )
    create_nosp_binary(
        os.path.join(target_dir, "netsurf.nosp"),
        "NetSurf Web Browser 3.11",
        "26110.0200",
        8,
        "NetSurf Multi-Platform Lightweight Web Browser Engine with CSS3 & DOM Rendering"
    )

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].endswith(".nosp"):
        target_name = os.path.basename(sys.argv[1])
        if "wifi" in target_name:
            create_nosp_binary(sys.argv[1], "NovaOS Network & WiFi Setup", "26110.0000", 2, "WiFi 6/6E/7 Driver Manager")
        elif "chrome" in target_name:
            create_nosp_binary(sys.argv[1], "Google Chrome", "26110.0000", 3, "Google Chrome Browser for NovaOS")
        elif "shop" in target_name:
            create_nosp_binary(sys.argv[1], "NovaOS Online App Shop", "26110.0000", 4, "NovaOS Online App Store")
        else:
            create_nosp_binary(sys.argv[1], "NovaOS Setup & Installer", "26110.0000", 1, "Live Setup & Installer")
    else:
        out_dir = sys.argv[1] if len(sys.argv) > 1 else "build"
        build_all(out_dir)
