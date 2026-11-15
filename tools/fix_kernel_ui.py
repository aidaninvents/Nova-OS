from pathlib import Path

kpath = Path("NovaOS_fixed/kernel.asm")
content = kpath.read_text(encoding="utf-8")

# ── 1. Fix spinner_delay ────────────────────────────────────────────────────
old_delay = """.do_delay:
    ; Wait ~16 ms per frame using port 0x61 refresh timer (Windows 10 timing)
    mov edx, 800
    in al, 0x61
    and al, 0x10
    mov ah, al
    mov ecx, 300000
.toggle_loop:
    in al, 0x61
    and al, 0x10
    cmp al, ah
    je .no_toggle
    mov ah, al
    dec edx
    jz .delay_done
.no_toggle:
    pause
    dec ecx
    jnz .toggle_loop"""

new_delay = """.do_delay:
    ; Simple calibrated busy-wait: ~16 ms / frame on modern hardware
    mov ecx, 200000
.spin_loop:
    pause
    dec ecx
    jnz .spin_loop"""

if old_delay in content:
    content = content.replace(old_delay, new_delay)
    print("OK: Fixed spinner_delay")
else:
    print("SKIP: spinner_delay target not found")

# ── 2. Fix boot text cursor_x underflow ─────────────────────────────────────
old_cx = """    ; cursor_x = (screen_width / 2) / FONT_WIDTH - 22
    mov eax, [screen_width]
    shr eax, 1
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    sub eax, 22
    mov [cursor_x], al
    mov [boot_left_col], al"""

new_cx = """    ; cursor_x = (screen_width / 2) / FONT_WIDTH - 22  (clamped to 0)
    mov eax, [screen_width]
    shr eax, 1
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    cmp eax, 22
    jae .cx_ok
    xor eax, eax
    jmp .cx_set
.cx_ok:
    sub eax, 22
.cx_set:
    mov [cursor_x], al
    mov [boot_left_col], al"""

if old_cx in content:
    content = content.replace(old_cx, new_cx)
    print("OK: Fixed boot cursor_x underflow")
else:
    print("SKIP: boot cursor_x target not found")

# ── 3. Update help_text ─────────────────────────────────────────────────────
old_help = """help_text db 13,10
          db \"Available Commands:\",13,10
          db \"  help         Show this command list\",13,10
          db \"  about        About NovaOS\",13,10
          db \"  version      Show OS version\",13,10
          db \"  cpu          Show CPU vendor and processor brand\",13,10
          db \"  mem          Show system RAM detected\",13,10
          db \"  drives       List Floppy, Hard Disk, and CD-ROM\",13,10
          db \"  floppy       Test and inspect Floppy Drive A:\",13,10
          db \"  iso          Inspect CD-ROM / Live ISO Drive D:\",13,10
          db \"  savefont     Save font to Hard Disk C: (persistent)\",13,10
          db \"  loadfont     Load font from Floppy / NovaFS\",13,10
          db \"  font list    List available NovaFS fonts\",13,10
          db \"  font current Show active font\",13,10
          db \"  font use X   Switch font (regular/bold/italic)\",13,10
          db \"  time / date  Show system clock\",13,10
          db \"  clear / cls  Clear terminal window\",13,10
          db \"  reboot       Restart computer\",13,10
          db \"  halt         Halt CPU\",13,10
          db 13,10,0"""

new_help = """help_text db 13,10
          db \"NovaOS Shell Commands\",13,10
          db \"==============================================\",13,10
          db \" SYSTEM\",13,10
          db \"  help          Show this list\",13,10
          db \"  about         About NovaOS\",13,10
          db \"  version       OS version\",13,10
          db \"  cpu           CPU vendor & model\",13,10
          db \"  mem           System RAM info\",13,10
          db \"  time          Show/set hardware clock  (time HH:MM:SS)\",13,10
          db \"  date          Show/set system date     (date YYYY/MM/DD)\",13,10
          db \"  reboot        Restart the computer\",13,10
          db \"  halt          Halt CPU\",13,10
          db \" DISPLAY\",13,10
          db \"  clear / cls   Clear terminal\",13,10
          db \"  res           Show active resolution\",13,10
          db \" FILE SYSTEM  (changes persist after 'savefs')\",13,10
          db \"  ls / dir      List files\",13,10
          db \"  mkdir <n>     Create folder\",13,10
          db \"  touch <n>     Create empty file\",13,10
          db \"  write <n> <t> Write text to file\",13,10
          db \"  cat <n>       Print file contents\",13,10
          db \"  rm / rmdir    Delete file or folder\",13,10
          db \"  savefs        Commit FS to Hard Disk C:\",13,10
          db \" GUI\",13,10
          db \"  files         Open File Explorer window\",13,10
          db \" DRIVES\",13,10
          db \"  drives        List drives\",13,10
          db \"  floppy        Floppy Drive A: info\",13,10
          db \"  iso           Optical Drive D: info\",13,10
          db \" FONT\",13,10
          db \"  font list     List NovaFS fonts\",13,10
          db \"  font current  Active font\",13,10
          db \"  font use X    Switch font (regular/bold/italic)\",13,10
          db \"  font setup    Scan floppy/ISO for TTF fonts\",13,10
          db \"  savefont      Persist font to Hard Disk C:\",13,10
          db \"  loadfont      Load font from floppy/NovaFS\",13,10
          db \" MATH\",13,10
          db \"  add N M  /  sub N M\",13,10
          db \"  echo <text>\",13,10
          db \"==============================================\",13,10
          db 13,10,0"""

if old_help in content:
    content = content.replace(old_help, new_help)
    print("OK: Fixed help_text")
else:
    print("SKIP: help_text target not found")

kpath.write_text(content, encoding="utf-8")
print("Done patching kernel.asm")
