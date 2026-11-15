with open("kernel.asm", "rb") as f:
    data = f.read()

crlf = b"\r\n" in data
def nl(s: str) -> bytes:
    return (s.replace("\n", "\r\n") if crlf else s).encode("ascii")

# 1. Remove remaining verified unreferenced db lines (71 bytes)
dead_exact = [
    'fs_name_video:           db "VIDEOHD.NSP",0',
    'gui_files_text:          db "[ Files ]",0',
    'cmd_wifi_nosp:           db "wifi.nosp",0',
    'cmd_browser_short:       db "browser",0',
    'str_py_print:            db "print",0',
    'str_py_help:             db "help",0',
    'java_run_status:         db 0',
    'chr_win_state: db 2',
]
# Also trim trailing whitespace padding inside str_shop_offline_msg and str_fallback_youtube / str_drive_menu
replacements = [
    (
        'str_shop_offline_msg:\n'
        '    db "==========================================================",13,10\n'
        '    db "          NOVAOS APP SHOP - NO INTERNET CONNECTION                ",13,10\n'
        '    db "        ==========================================================",13,10,13,10\n'
        '    db "          Apps are NOT preloaded! You must connect to the         ",13,10\n'
        '    db "          internet before downloading apps from the Shop.         ",13,10,13,10\n'
        '    db "          -> Press [W] or Click to open WiFi/Ethernet Setup       ",13,10\n'
        '    db "          -> Press [ESC] to return to Desktop                     ",0',
        'str_shop_offline_msg:\n'
        '    db "=============================================",13,10\n'
        '    db "  NOVAOS APP SHOP - NO INTERNET CONNECTION",13,10\n'
        '    db "=============================================",13,10,13,10\n'
        '    db "  Connect to internet to download apps.",13,10\n'
        '    db "  [W] Open WiFi Setup | [ESC] Desktop",0'
    ),
    (
        '    db "     -------------------------------------------------------------------",13,10',
        '    db "     -----------------------------------------",13,10'
    ),
    (
        '    db "     ----------------------------------------------------------------------",13,10',
        '    db "     -----------------------------------------",13,10'
    ),
    (
        '    db "     ------------------------------------------------------",13,10',
        '    db "     -----------------------------------------",13,10'
    ),
]

for d in dead_exact:
    # Find line containing exact label
    for prefix in [d.split(":")[0] + ":"]:
        pass

# Line-based exact label removal for the 8 unreferenced db labels
dead_labels = {
    b"fs_name_video", b"gui_files_text", b"cmd_wifi_nosp", b"cmd_browser_short",
    b"str_py_print", b"str_py_help", b"java_run_status", b"chr_win_state"
}
lines = data.splitlines(keepends=True)
new_lines = []
for ln in lines:
    stripped = ln.strip()
    matched = False
    for lbl in dead_labels:
        if stripped.startswith(lbl + b":") or stripped.startswith(lbl + b" "):
            # Make sure it's a declaration line (has db)
            if b" db " in stripped or stripped.endswith(b"db 0") or stripped.endswith(b"db 2"):
                matched = True
                break
    if not matched:
        new_lines.append(ln)
data = b"".join(new_lines)

for old_s, new_s in replacements:
    bo = nl(old_s)
    bn = nl(new_s)
    if bo in data:
        data = data.replace(bo, bn)
        print("Applied replacement:", old_s.splitlines()[0][:50])
    else:
        print("Warning: not found:", old_s.splitlines()[0][:50])

with open("kernel.asm", "wb") as f:
    f.write(data)
print("Trim complete.")
