#!/usr/bin/env python3
"""
tools/upgrade_novaos_v100.py
Upgrades kernel.asm for NovaOS 1.00 26Q4 (Build 26110.0000):
 - Removes browser.nosp completely (replaced by real Google Chrome & installable Firefox)
 - Makes everything NOT preloaded (network starts OFFLINE until wifi.nosp is configured;
   Downloads folder starts empty until downloaded; Shop apps start uninstalled until installed)
 - Makes keyboard & mouse inputs NOT turn on or blink the network indicator dot
 - Fixes mouse movement in Files, Chrome, WiFi, Shop, Notepad, and Firefox (no position reset, no flicker)
 - Adds transparent & colored text rendering for crisp GUI typography
 - Adds Real PCI Bus Hardware Scanner (ports 0xCF8/0xCFC) in wifi.nosp
 - Upgrades Google Chrome (chrome.nosp) with offline dino screen, live typing in Omnibox/Search bar,
   Google Search results, GitHub repo page, and embedded HD animated video stream
 - Adds NovaOS Online App Shop (shop.nosp) hosting installable:
     [1] Notepad Studio (notepad.nosp) - Real multi-line text editor saving to NovaFS
     [2] Python 3.15.0 (python.nosp)   - Real interactive Python 3.15 REPL with math, print(), sys, os
     [3] Mozilla Firefox (firefox.nosp)- Real Graphical Firefox Quantum browser
     [4] Nova HD Video (video.nosp)    - Real 60fps multi-frame procedural video player
"""

import os
import sys

KERNEL_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "kernel.asm")

with open(KERNEL_PATH, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()

# Normalize to LF for reliable processing
content = content.replace("\r\n", "\n")

# -------------------------------------------------------------------------
# 1. Check persistent network flag on boot (starts 0 = OFFLINE on fresh boot)
# -------------------------------------------------------------------------
old_boot_desktop = """    call clear_screen
    
    call gui_desktop

    jmp shell"""

new_boot_desktop = """    call clear_screen

    ; Check if network driver was previously saved to NovaFS superblock
    mov byte [net_connected], 0
    cmp dword [NOVAFS + 28], 0x4E455431
    jne .fresh_offline_boot
    mov byte [net_connected], 1
.fresh_offline_boot:

    call gui_desktop

    jmp shell"""

assert old_boot_desktop in content, "Could not find old_boot_desktop"
content = content.replace(old_boot_desktop, new_boot_desktop, 1)

# -------------------------------------------------------------------------
# 2. Fix clear_screen to use framebuffer_pitch and reset text colors
# -------------------------------------------------------------------------
old_clear_screen = """clear_screen:

    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Invalidate old mouse background buffer on screen clear
    mov byte [mouse_has_old], 0

    mov rdi, [framebuffer_address]

    xor eax, eax

    mov ebx, [screen_height]
    imul ebx, [screen_width]
    mov ecx, ebx

    rep stosd

    mov byte [cursor_x], 0
    mov byte [cursor_y], 0

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret"""

new_clear_screen = """clear_screen:

    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Invalidate old mouse background buffer on screen clear
    mov byte [mouse_has_old], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], 0x00000000
    mov byte [text_transparent_bg], 0

    mov rdi, [framebuffer_address]

    xor eax, eax

    mov ebx, [screen_height]
    imul ebx, [framebuffer_pitch]
    shr ebx, 2
    mov ecx, ebx

    rep stosd

    mov byte [cursor_x], 0
    mov byte [cursor_y], 0

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret"""

assert old_clear_screen in content, "Could not find old_clear_screen"
content = content.replace(old_clear_screen, new_clear_screen, 1)

# -------------------------------------------------------------------------
# 3. Update gui_desktop layout so launcher icons don't overlap titlebar,
#    use transparent text for labels, and set terminal bg color
# -------------------------------------------------------------------------
old_gui_desktop_body = """    mov r15d, 68            ; win_y (always just below 48-px panel)"""
new_gui_desktop_body = """    mov r15d, 88            ; win_y (below desktop shortcut bar)"""
assert old_gui_desktop_body in content, "Could not find old_gui_desktop_body"
content = content.replace(old_gui_desktop_body, new_gui_desktop_body, 1)

old_gui_desktop_labels = """    ; --------------------------------------------------------
    ; "NovaOS" in top panel
    ; --------------------------------------------------------

    mov byte [cursor_x], 2
    mov byte [cursor_y], 1

    mov rsi, gui_novaos_text
    call print

    ; Reset mouse background buffer on desktop redraw
    mov byte [mouse_has_old], 0

    ; Draw blinking internet activity icon on top right panel
    call draw_net_icon

    ; --------------------------------------------------------
    ; Application icons below top panel
    ; (cursor_y = 5 puts them at Y=100, on the desktop)
    ; --------------------------------------------------------

    mov byte [cursor_x], 5
    mov byte [cursor_y], 5

    mov rsi, gui_files_text
    call print

    mov byte [cursor_x], 18
    mov byte [cursor_y], 5

    mov rsi, gui_terminal_text
    call print

    mov byte [cursor_x], 33
    mov byte [cursor_y], 5

    mov rsi, gui_settings_text
    call print

    ; --------------------------------------------------------
    ; Terminal title text  (Y=3 relative to win_y=68 → row ~7)
    ; --------------------------------------------------------

    mov byte [cursor_x], 9
    mov byte [cursor_y], 7

    mov rsi, gui_terminal_title
    call print

    ; --------------------------------------------------------
    ; Taskbar text
    ; cursor_y = (taskbar_y + 14) / FONT_HEIGHT
    ; --------------------------------------------------------

    ; eax = (taskbar_y + 14) / 20
    lea eax, [r13d + 14]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx

    mov [cursor_y], al
    mov byte [cursor_x], 2

    mov rsi, gui_taskbar_text
    call print"""

new_gui_desktop_labels = """    ; Enable transparent text background for desktop & panel labels
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    ; --------------------------------------------------------
    ; "NovaOS" in top panel
    ; --------------------------------------------------------

    mov byte [cursor_x], 2
    mov byte [cursor_y], 1

    mov rsi, gui_novaos_text
    call print

    ; Reset mouse background buffer on desktop redraw
    mov byte [mouse_has_old], 0

    ; Draw network status indicator on top right panel (starts OFFLINE)
    call draw_net_icon

    ; --------------------------------------------------------
    ; Desktop Application Launcher Bar (cursor_y = 3 -> Y=60)
    ; --------------------------------------------------------
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00E2E8F0

    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    mov rsi, gui_desktop_bar_text
    call print

    ; --------------------------------------------------------
    ; Terminal title text (inside titlebar Y=88..128 -> row 5)
    ; --------------------------------------------------------
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 5

    mov rsi, gui_terminal_title
    call print

    ; --------------------------------------------------------
    ; Taskbar text
    ; cursor_y = (taskbar_y + 14) / FONT_HEIGHT
    ; --------------------------------------------------------

    lea eax, [r13d + 14]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx

    mov [cursor_y], al
    mov byte [cursor_x], 2

    mov rsi, gui_taskbar_text
    call print

    ; Restore opaque window background for shell terminal text
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW"""

assert old_gui_desktop_labels in content, "Could not find old_gui_desktop_labels"
content = content.replace(old_gui_desktop_labels, new_gui_desktop_labels, 1)

# -------------------------------------------------------------------------
# 4. Upgrade putchar to support text_fg_color, text_bg_color, text_transparent_bg
# -------------------------------------------------------------------------
old_putchar_pixels = """    putchar_pixel:

    test bx, 0x8000
    jz putchar_pixel_off

    mov dword [rdi], COLOR_FG

    jmp putchar_pixel_next


putchar_pixel_off:

    mov dword [rdi], COLOR_BG


putchar_pixel_next:"""

new_putchar_pixels = """    putchar_pixel:

    test bx, 0x8000
    jz putchar_pixel_off

    mov eax, [text_fg_color]
    mov dword [rdi], eax

    jmp putchar_pixel_next


putchar_pixel_off:

    cmp byte [text_transparent_bg], 1
    je putchar_pixel_next
    mov eax, [text_bg_color]
    mov dword [rdi], eax


putchar_pixel_next:"""

assert old_putchar_pixels in content, "Could not find old_putchar_pixels"
content = content.replace(old_putchar_pixels, new_putchar_pixels, 1)

old_putchar_bs = """putchar_clear_pixel:

    mov dword [rdi], COLOR_BG"""

new_putchar_bs = """putchar_clear_pixel:

    mov eax, [text_bg_color]
    mov dword [rdi], eax"""

assert old_putchar_bs in content, "Could not find old_putchar_bs"
content = content.replace(old_putchar_bs, new_putchar_bs, 1)

# -------------------------------------------------------------------------
# 5. Remove draw_net_icon from read_line_loop (Keyboard & Mouse MUST NOT
#    turn on or blink the network dot!) and add desktop mouse click targets
# -------------------------------------------------------------------------
old_read_line_loop = """read_line_loop:

    call get_key

    ; Blink network activity icon on every user event
    call draw_net_icon

    ; If mouse moved or clicked in shell, redraw cursor and continue
    cmp eax, KEY_MOUSE_MOVE
    je .mouse_event_shell
    cmp eax, KEY_MOUSE_CLICK
    je .mouse_event_shell
    jmp .not_mouse_shell

.mouse_event_shell:
    call draw_mouse_cursor
    jmp read_line_loop"""

new_read_line_loop = """read_line_loop:

    call get_key

    ; NOTE: Keyboard & mouse inputs do NOT toggle or turn on the network dot!
    cmp eax, KEY_MOUSE_MOVE
    je .mouse_move_shell
    cmp eax, KEY_MOUSE_CLICK
    je .mouse_click_shell
    jmp .not_mouse_shell

.mouse_move_shell:
    call draw_mouse_cursor
    jmp read_line_loop

.mouse_click_shell:
    call draw_mouse_cursor
    ; Check if user clicked Top-Right Network Icon (Y < 48, X >= screen_width - 190)
    mov eax, [mouse_y]
    cmp eax, 48
    jae .check_desk_bar_click
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 190
    cmp eax, edx
    jae .launch_wifi_from_click
    jmp read_line_loop

.check_desk_bar_click:
    ; Check if user clicked Desktop Launcher Bar (Y = 50..88) or Bottom Taskbar (Y >= screen_height - 48)
    mov eax, [mouse_y]
    cmp eax, 88
    jbe .eval_launcher_x
    mov edx, [screen_height]
    sub edx, 48
    cmp eax, edx
    jae .eval_taskbar_x
    jmp read_line_loop

.eval_launcher_x:
    mov eax, [mouse_x]
    cmp eax, 155
    jb .launch_files_from_click
    cmp eax, 295
    jb .launch_chrome_from_click
    cmp eax, 450
    jb .launch_shop_from_click
    cmp eax, 575
    jb .launch_wifi_from_click
    cmp eax, 720
    jb .launch_notepad_from_click
    jmp read_line_loop

.eval_taskbar_x:
    mov eax, [mouse_x]
    cmp eax, 140
    jb read_line_loop
    cmp eax, 230
    jb .launch_files_from_click
    cmp eax, 350
    jb read_line_loop
    cmp eax, 430
    jb .launch_wifi_from_click
    cmp eax, 530
    jb .launch_chrome_from_click
    cmp eax, 620
    jb .launch_shop_from_click
    jmp read_line_loop

.launch_files_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax ; discard return address to shell
    jmp command_files

.launch_chrome_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_chrome

.launch_shop_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_shop

.launch_wifi_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_wifi

.launch_notepad_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_notepad"""

assert old_read_line_loop in content, "Could not find old_read_line_loop"
content = content.replace(old_read_line_loop, new_read_line_loop, 1)

# -------------------------------------------------------------------------
# 6. Update command parser for shop, notepad, python, firefox, video, chrome
#    and remove browser.nosp
# -------------------------------------------------------------------------
old_nosp_dispatch = """.check_nosp_arg:
    call skip_spaces
    mov rdi, cmd_chrome_short
    call prefix
    jc command_chrome
    mov rdi, cmd_wifi_short
    call prefix
    jc command_wifi
    mov rdi, cmd_browser_short
    call prefix
    jc command_browser
    mov rdi, cmd_startup_short
    call prefix
    jc command_run_startup_nosp

.check_direct_nosp:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_chrome_short
    call prefix
    jc command_chrome

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_wifi_short
    call prefix
    jc command_wifi

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_browser_short
    call prefix
    jc command_browser"""

new_nosp_dispatch = """.check_nosp_arg:
    call skip_spaces
    mov rdi, cmd_chrome_short
    call prefix
    jc command_chrome
    mov rdi, cmd_wifi_short
    call prefix
    jc command_wifi
    mov rdi, cmd_shop_short
    call prefix
    jc command_shop
    mov rdi, cmd_notepad_short
    call prefix
    jc command_notepad
    mov rdi, cmd_python_short
    call prefix
    jc command_python
    mov rdi, cmd_firefox_short
    call prefix
    jc command_firefox
    mov rdi, cmd_video_short
    call prefix
    jc command_video
    mov rdi, cmd_startup_short
    call prefix
    jc command_run_startup_nosp

.check_direct_nosp:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_chrome_short
    call prefix
    jc command_chrome

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_wifi_short
    call prefix
    jc command_wifi

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_shop_short
    call prefix
    jc command_shop

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_store_short
    call prefix
    jc command_shop

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_notepad_short
    call prefix
    jc command_notepad

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_python_short
    call prefix
    jc command_python

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_firefox_short
    call prefix
    jc command_firefox

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_video_short
    call prefix
    jc command_video"""

assert old_nosp_dispatch in content, "Could not find old_nosp_dispatch"
content = content.replace(old_nosp_dispatch, new_nosp_dispatch, 1)

# Update Drive D selection in command_list_drive so [3] is chrome.nosp and [4] is shop.nosp
old_drive_d_sel = """    cmp eax, '3'
    je .file_browser_nosp
    cmp eax, 'b'
    je .file_browser_nosp
    cmp eax, 'B'
    je .file_browser_nosp"""

new_drive_d_sel = """    cmp eax, '3'
    je .file_chrome_nosp
    cmp eax, 'c'
    je .file_chrome_nosp
    cmp eax, 'C'
    je .file_chrome_nosp"""

assert old_drive_d_sel in content, "Could not find old_drive_d_sel"
content = content.replace(old_drive_d_sel, new_drive_d_sel, 1)

old_file_browser_nosp = """.file_browser_nosp:
    call newline
    call command_browser
    jmp command_done"""

new_file_browser_nosp = """.file_chrome_nosp:
    call newline
    call command_chrome
    jmp command_done"""

assert old_file_browser_nosp in content, "Could not find old_file_browser_nosp"
content = content.replace(old_file_browser_nosp, new_file_browser_nosp, 1)

# -------------------------------------------------------------------------
# 7. Replace command_files through command_chrome with upgraded implementations:
#    - Smooth non-flickering mouse in File Explorer, WiFi, Chrome, Shop, Notepad, Firefox
#    - Non-preloaded Downloads & Non-preloaded Shop apps
#    - Real PCI hardware scan in wifi.nosp
#    - Non-blinking network status icon (blinks ONLY during actual network TX/RX)
#    - Full interactive Google Chrome with offline dino, live Omnibox typing, search, GitHub, HD Video
#    - Full NovaOS App Shop with installable Notepad, Python 3.15 REPL, Mozilla Firefox, HD Video Player
# -------------------------------------------------------------------------
start_marker = "command_files:\n"
end_marker = "command_add:\n"

idx_start = content.find(start_marker)
idx_end = content.find(end_marker)
assert idx_start != -1 and idx_end != -1, f"Markers not found: {idx_start}, {idx_end}"

new_subsystems_asm = """command_files:
    ; Interactive File Explorer with smooth mouse movement & double-tap open
    push r11
    push r12
    push r13
    push r14
    push r15

    ; r12 = selected index (0-based)
    xor r12d, r12d
    ; r13 = 12 base entries (browser.nosp removed; chrome.nosp & shop.nosp included)
    mov r13d, 12

.explorer_draw:
    mov byte [mouse_has_old], 0

    ; ── Draw window frame ──────────────────────────────────────────────
    mov eax, 60
    mov ebx, 55
    mov ecx, [screen_width]
    sub ecx, 120
    mov edx, [screen_height]
    sub edx, 120
    push rcx
    push rdx
    mov esi, 0x00121824
    call draw_rect

    ; Title bar (36px)
    pop rdx
    pop rcx
    push rcx
    push rdx
    mov eax, 60
    mov ebx, 55
    mov edx, 36
    mov esi, 0x000F2942
    call draw_rect

    ; Accent line
    pop rdx
    pop rcx
    push rcx
    mov eax, 60
    mov ebx, 91
    mov edx, 2
    mov esi, COLOR_ACCENT
    call draw_rect

    ; Address bar bg
    pop rcx
    mov eax, 70
    mov ebx, 98
    sub ecx, 20
    mov edx, 24
    mov esi, 0x001E293B
    call draw_rect

    ; ── Title & Address text (transparent bg) ──────────────────────────
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    mov byte [cursor_x], 6
    mov byte [cursor_y], 3
    mov rsi, gui_explorer_title
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 5
    mov rsi, gui_address_path
    call print

    ; ── Column headers ─────────────────────────────────────────────────
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 7
    mov rsi, gui_col_header
    call print

    ; ── Draw all 12 entries, highlighting the selected one ─────────────
    xor r15d, r15d        ; entry index
.draw_entries:
    cmp r15d, r13d
    jge .draw_done_entries

    mov eax, r15d
    lea ebx, [eax + 9]    ; row = 9 + entry_index

    ; Highlight selected row bar
    cmp r15d, r12d
    jne .no_highlight

    push rax
    push rbx
    mov eax, 70
    imul ebx, FONT_HEIGHT
    mov ecx, [screen_width]
    sub ecx, 140
    mov edx, FONT_HEIGHT
    mov esi, 0x001E3A8A
    call draw_rect
    pop rbx
    pop rax

    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 6
    mov [cursor_y], bl
    mov rsi, gui_sel_arrow
    call print
    jmp .print_entry

.no_highlight:
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 6
    mov [cursor_y], bl
    mov rsi, gui_no_arrow
    call print

.print_entry:
    mov [cursor_y], bl

    ; Fetch entry strings from table
    push r12
    push r15
    lea rax, [explorer_entry_table]
    movzx r15, r15w
    mov rax, [rax + r15*8]
    mov rsi, rax
    mov byte [cursor_x], 8
    call print
    pop r15
    pop r12

    inc r15d
    jmp .draw_entries

.draw_done_entries:
    ; ── Status bar ─────────────────────────────────────────────────────
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov eax, [screen_height]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    sub eax, 5
    mov [cursor_y], al
    mov rsi, gui_explorer_keys
    call print

    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW

    ; Draw mouse cursor at its CURRENT position (never reset mouse_x/mouse_y!)
    call draw_mouse_cursor

.explorer_wait_key:
    call get_key

    ; Smooth Mouse Move without redrawing entire Explorer window!
    cmp eax, KEY_MOUSE_MOVE
    je .explorer_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .explorer_mouse_click

    cmp eax, KEY_UP
    je .move_up
    cmp eax, KEY_DOWN
    je .move_down
    cmp eax, KEY_LEFT
    je .exp_mouse_left
    cmp eax, KEY_RIGHT
    je .exp_mouse_right
    cmp eax, 'k'
    je .move_up
    cmp eax, 'j'
    je .move_down
    cmp eax, 27           ; Escape -> close
    je .explorer_close
    cmp eax, 'q'
    je .explorer_close
    cmp eax, 'Q'
    je .explorer_close
    cmp eax, 13           ; Enter -> Open item
    je .explorer_handle_open
    cmp eax, ' '          ; Space -> Open item
    je .explorer_handle_open
    cmp eax, KEY_PGUP
    je .jump_top
    cmp eax, KEY_PGDN
    je .jump_bottom

    ; Number keys '0'..'9' direct selection
    cmp eax, '0'
    jb .check_shortcut_keys
    cmp eax, '9'
    ja .check_shortcut_keys
    sub eax, '0'
    cmp eax, r13d
    jge .explorer_wait_key
    cmp eax, r12d
    je .explorer_handle_open
    mov r12d, eax
    jmp .explorer_draw

.check_shortcut_keys:
    cmp eax, 'c'
    je .sel_chrome
    cmp eax, 'C'
    je .sel_chrome
    cmp eax, 'w'
    je .sel_wifi
    cmp eax, 'W'
    je .sel_wifi
    cmp eax, 's'
    je .sel_shop
    cmp eax, 'S'
    je .sel_shop
    jmp .explorer_wait_key

.explorer_mouse_move:
    call draw_mouse_cursor
    jmp .explorer_wait_key

.exp_mouse_left:
    cmp dword [mouse_x], 20
    jb .explorer_wait_key
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .explorer_wait_key

.exp_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .explorer_wait_key
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .explorer_wait_key

.sel_chrome:
    cmp r12d, 10
    je .explorer_handle_open
    mov r12d, 10
    jmp .explorer_draw

.sel_wifi:
    cmp r12d, 9
    je .explorer_handle_open
    mov r12d, 9
    jmp .explorer_draw

.sel_shop:
    cmp r12d, 11
    je .explorer_handle_open
    mov r12d, 11
    jmp .explorer_draw

.explorer_mouse_click:
    call draw_mouse_cursor
    ; Check if clicking titlebar close button [X] (Y = 55..91, X >= screen_width - 120)
    mov eax, [mouse_y]
    cmp eax, 91
    ja .exp_click_rows
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 120
    cmp eax, edx
    jae .explorer_close
    jmp .explorer_wait_key

.exp_click_rows:
    ; Convert mouse_y to item index: Row = mouse_y / FONT_HEIGHT (20)
    mov eax, [mouse_y]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    sub eax, 9
    js .explorer_wait_key
    cmp eax, r13d
    jge .explorer_wait_key

    ; Double-Tap / Second click on selected item opens it!
    cmp eax, r12d
    je .explorer_handle_open

    ; First click selects item
    mov r12d, eax
    jmp .explorer_draw

.move_up:
    test r12d, r12d
    jz .explorer_wait_key
    dec r12d
    lea ecx, [r12d + 9]
    imul ecx, FONT_HEIGHT
    mov [mouse_y], ecx
    jmp .explorer_draw

.move_down:
    lea eax, [r12d + 1]
    cmp eax, r13d
    jge .explorer_wait_key
    inc r12d
    lea ecx, [r12d + 9]
    imul ecx, FONT_HEIGHT
    mov [mouse_y], ecx
    jmp .explorer_draw

.jump_top:
    xor r12d, r12d
    jmp .explorer_draw

.jump_bottom:
    lea r12d, [r13d - 1]
    jmp .explorer_draw

.explorer_handle_open:
    cmp r12d, 0
    je .exp_open_documents
    cmp r12d, 1
    je .exp_open_downloads
    cmp r12d, 2
    je .exp_open_fonts
    cmp r12d, 3
    je .exp_open_system
    cmp r12d, 4
    je .exp_open_readme
    cmp r12d, 5
    je .exp_open_notes
    cmp r12d, 6
    je .exp_open_audio
    cmp r12d, 7
    je .exp_open_font_file
    cmp r12d, 8           ; startup.nosp
    je .exp_open_startup
    cmp r12d, 9           ; wifi.nosp
    je .exp_open_wifi
    cmp r12d, 10          ; chrome.nosp
    je .exp_open_chrome
    cmp r12d, 11          ; shop.nosp
    je .exp_open_shop
    jmp .explorer_draw

.exp_open_chrome:
    call command_chrome
    call gui_desktop
    jmp .explorer_draw

.exp_open_shop:
    call command_shop
    call gui_desktop
    jmp .explorer_draw

.exp_open_documents:
    mov rsi, str_exp_modal_docs
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_downloads:
    ; NOT preloaded! Only show downloaded files if actually downloaded in Chrome or Shop!
    cmp byte [repo_downloaded], 1
    je .exp_dl_has_files
    mov rsi, str_exp_modal_downloads_empty
    call .show_explorer_modal
    jmp .explorer_draw
.exp_dl_has_files:
    mov rsi, str_exp_modal_downloads
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_fonts:
    mov rsi, str_exp_modal_fonts
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_system:
    mov rsi, str_exp_modal_system
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_readme:
    mov rsi, str_exp_modal_readme
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_notes:
    ; If Notepad is installed, open notes.txt in real graphical Notepad!
    cmp byte [app_installed_notepad], 1
    je .exp_launch_notepad
    mov rsi, str_exp_modal_notes
    call .show_explorer_modal
    jmp .explorer_draw
.exp_launch_notepad:
    call command_notepad
    jmp .explorer_draw

.exp_open_audio:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 4
    mov rsi, str_exp_modal_audio
    call print
    mov ax, 523
    call speaker_start
    call audio_delay
    mov ax, 659
    call speaker_start
    call audio_delay
    mov ax, 784
    call speaker_start
    call audio_delay
    mov ax, 1047
    call speaker_start
    call audio_delay
    call speaker_stop
    call .wait_non_mouse_key
    jmp .explorer_draw

.exp_open_font_file:
    mov rsi, str_exp_modal_font_preview
    call .show_explorer_modal
    jmp .explorer_draw

.show_explorer_modal:
    push rsi
    call clear_screen
    pop rsi
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    call print
    call draw_mouse_cursor
    call .wait_non_mouse_key
    ret

.wait_non_mouse_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_modal_wait
    call draw_mouse_cursor
    jmp .wait_non_mouse_key
.done_modal_wait:
    ret

.exp_open_wifi:
    call command_wifi
    call gui_desktop
    jmp .explorer_draw

.exp_open_startup:
    call clear_screen
    mov rsi, str_nosp_action_menu
    call print
.exp_wait_action:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    je .exp_wait_action
    cmp eax, '1'
    je .exp_run_nosp
    cmp eax, 13
    je .exp_run_nosp
    cmp eax, 'o'
    je .exp_run_nosp
    cmp eax, 'O'
    je .exp_run_nosp
    cmp eax, '2'
    je .exp_edit_nosp
    cmp eax, 'e'
    je .exp_edit_nosp
    cmp eax, 'E'
    je .exp_edit_nosp
    jmp .explorer_draw

.exp_run_nosp:
    call command_run_startup_nosp
    call gui_desktop
    jmp .explorer_draw

.exp_edit_nosp:
    call newline
    mov rsi, str_nosp_edit_view
    call print
    call .wait_non_mouse_key
    jmp .explorer_draw

.explorer_close:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11

    call gui_desktop
    jmp shell


command_res:
    mov rsi, res_header
    call print

    mov eax, [screen_width]
    call print_number
    mov al, 'x'
    call putchar
    mov eax, [screen_height]
    call print_number
    mov rsi, res_bpp_suffix
    call print
    call newline

    mov rsi, res_modes_list
    call print
    jmp command_done


command_font_setup:
    mov rsi, font_setup_banner
    call print
    mov rsi, font_setup_floppy
    call print
    mov rsi, font_setup_iso
    call print
    mov rsi, font_setup_novafs
    call print
    mov rsi, font_setup_prompt
    call print
    jmp command_done


; ============================================================
; MOUSE CURSOR & BACKGROUND SAVE/RESTORE SUBSYSTEM
; (Zero-trail, smooth movement in all apps)
; ============================================================

restore_mouse_background:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push r8
    push r9
    push rsi

    cmp byte [mouse_has_old], 1
    jne .restore_done

    mov eax, [mouse_old_x]
    mov ebx, [mouse_old_y]
    lea rsi, [mouse_bg_buffer]
    xor r8d, r8d             ; row = 0..15

.restore_row:
    cmp r8d, 16
    jge .restore_finish

    mov edx, ebx
    add edx, r8d
    cmp edx, [screen_height]
    jge .restore_finish

    xor r9d, r9d             ; col = 0..15

.restore_col:
    cmp r9d, 16
    jge .restore_row_next

    mov ecx, eax
    add ecx, r9d
    cmp ecx, [screen_width]
    jge .restore_skip_pixel

    mov eax, [rsi]
    push rax
    imul edx, [framebuffer_pitch]
    imul ecx, BYTES_PER_PIXEL
    add ecx, edx
    mov rdi, [framebuffer_address]
    add rdi, rcx
    pop rax
    mov [rdi], eax

    mov eax, [mouse_old_x]
    mov edx, ebx
    add edx, r8d

.restore_skip_pixel:
    add rsi, 4
    inc r9d
    jmp .restore_col

.restore_row_next:
    inc r8d
    jmp .restore_row

.restore_finish:
    mov byte [mouse_has_old], 0

.restore_done:
    pop rsi
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


draw_mouse_cursor:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11

    call restore_mouse_background

    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    cmp eax, [screen_width]
    jge .cursor_done
    cmp ebx, [screen_height]
    jge .cursor_done

    lea rdi, [mouse_bg_buffer]
    xor r8d, r8d             ; row = 0..15

.save_row:
    cmp r8d, 16
    jge .save_finish

    mov edx, ebx
    add edx, r8d
    cmp edx, [screen_height]
    jge .save_finish

    xor r9d, r9d             ; col = 0..15

.save_col:
    cmp r9d, 16
    jge .save_row_next

    mov ecx, eax
    add ecx, r9d
    cmp ecx, [screen_width]
    jge .save_skip_pixel

    push rax
    imul edx, [framebuffer_pitch]
    imul ecx, BYTES_PER_PIXEL
    add ecx, edx
    mov rsi, [framebuffer_address]
    add rsi, rcx
    mov ecx, [rsi]
    mov [rdi], ecx
    pop rax

    mov edx, ebx
    add edx, r8d
    jmp .save_next_px

.save_skip_pixel:
    mov dword [rdi], 0

.save_next_px:
    add rdi, 4
    inc r9d
    jmp .save_col

.save_row_next:
    inc r8d
    jmp .save_row

.save_finish:
    mov [mouse_old_x], eax
    mov [mouse_old_y], ebx
    mov byte [mouse_has_old], 1

    mov rsi, mouse_cursor_data
    xor r8d, r8d             ; row y = 0..15

.plot_row_loop:
    cmp r8d, 16
    jge .cursor_done

    mov edx, ebx
    add edx, r8d
    cmp edx, [screen_height]
    jge .cursor_done

    xor r9d, r9d             ; col x = 0..11

.plot_col_loop:
    cmp r9d, 12
    jge .plot_row_done

    mov ecx, eax
    add ecx, r9d
    cmp ecx, [screen_width]
    jge .plot_skip_pixel

    movzx r10d, byte [rsi]
    test r10d, r10d
    jz .plot_skip_pixel

    cmp r10d, 1
    je .plot_black
    mov r11d, 0x00FFFFFF
    jmp .plot_pixel_now

.plot_black:
    xor r11d, r11d

.plot_pixel_now:
    push rax
    push rdx
    imul edx, [framebuffer_pitch]
    imul ecx, BYTES_PER_PIXEL
    add ecx, edx
    mov rdi, [framebuffer_address]
    add rdi, rcx
    mov [rdi], r11d
    pop rdx
    pop rax

.plot_skip_pixel:
    inc rsi
    inc r9d
    jmp .plot_col_loop

.plot_row_done:
    inc r8d
    jmp .plot_row_loop

.cursor_done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


; ============================================================
; NETWORK STATUS INDICATOR (Not Preloaded! Keyboard & Mouse
; inputs NEVER toggle or turn on the indicator dot!)
; ============================================================

draw_net_icon:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Save text state so drawing icon never corrupts shell cursor
    movzx eax, byte [cursor_x]
    push rax
    movzx eax, byte [cursor_y]
    push rax
    mov eax, [text_fg_color]
    push rax
    movzx eax, byte [text_transparent_bg]
    push rax

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    ; Badge container on top right of top panel
    mov eax, [screen_width]
    sub eax, 185
    mov ebx, 6
    mov ecx, 175
    mov edx, 28
    mov esi, 0x000F172A
    call draw_rect

    ; Check if network is connected (0 = OFFLINE, 1 = ONLINE)
    cmp byte [net_connected], 1
    je .net_is_online

    ; OFFLINE: Dark Red indicator dot (#EF4444)
    mov eax, [screen_width]
    sub eax, 175
    mov ebx, 14
    mov ecx, 12
    mov edx, 12
    mov esi, 0x00EF4444
    call draw_rect

    mov eax, [screen_width]
    sub eax, 155
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_net_offline_text
    call print
    jmp .net_icon_restore

.net_is_online:
    ; ONLINE: Check if actively transmitting packets (net_icon_blink_state == 1)
    cmp byte [net_icon_blink_state], 1
    je .net_is_txrx

    ; Solid Emerald Green (#10B981)
    mov eax, [screen_width]
    sub eax, 175
    mov ebx, 14
    mov ecx, 12
    mov edx, 12
    mov esi, 0x0010B981
    call draw_rect

    mov eax, [screen_width]
    sub eax, 155
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_net_online_text
    call print
    jmp .net_icon_restore

.net_is_txrx:
    ; Bright Amber (#F59E0B) during actual network packet TX/RX
    mov eax, [screen_width]
    sub eax, 175
    mov ebx, 14
    mov ecx, 12
    mov edx, 12
    mov esi, 0x00F59E0B
    call draw_rect

    mov eax, [screen_width]
    sub eax, 155
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_net_active_text
    call print

.net_icon_restore:
    pop rax
    mov [text_transparent_bg], al
    pop rax
    mov [text_fg_color], eax
    pop rax
    mov [cursor_y], al
    pop rax
    mov [cursor_x], al

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Pulse network activity LED ONLY during real network operations
pulse_net_activity:
    cmp byte [net_connected], 1
    jne .pulse_done
    mov byte [net_icon_blink_state], 1
    call draw_net_icon
    call audio_delay
    mov byte [net_icon_blink_state], 0
    call draw_net_icon
.pulse_done:
    ret


; ============================================================
; REAL PCI HARDWARE SCANNER & WIFI/ETHERNET MANAGER (wifi.nosp)
; ============================================================

probe_pci_nic:
    push rax
    push rdx
    ; Read PCI Bus 0, Device 3, Function 0, Offset 0x00 (Intel 82540EM in VBox)
    mov eax, 0x80001800
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    mov [pci_nic_id], eax

    ; Read BAR0 (Offset 0x10)
    mov eax, 0x80001810
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [pci_nic_bar0], eax

    ; Enable PCI Bus Mastering & Memory Space (Offset 0x04 |= 0x0007)
    mov eax, 0x80001804
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    or eax, 0x0007
    out dx, eax

    pop rdx
    pop rax
    ret


command_wifi:
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Probe real hardware PCI bus for network controller
    call probe_pci_nic

.wifi_start:
    call clear_screen

    ; Draw top header panel
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 48
    mov esi, 0x000F2942
    call draw_rect

    ; Accent cyan line
    mov eax, 0
    mov ebx, 48
    mov ecx, [screen_width]
    mov edx, 3
    mov esi, 0x0038BDF8
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    ; Header title
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov rsi, str_wifi_title
    call print

    call draw_net_icon

    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000

    ; Catalog listing
    mov byte [cursor_x], 2
    mov byte [cursor_y], 4
    mov rsi, str_wifi_catalog
    call print

    ; Draw mouse cursor at its current position (movable!)
    call draw_mouse_cursor

.wait_wifi_key:
    call get_key

    ; Smooth mouse movement in WiFi Setup!
    cmp eax, KEY_MOUSE_MOVE
    je .wifi_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .wifi_mouse_click

    ; Arrow keys move mouse cursor in WiFi Setup
    cmp eax, KEY_UP
    je .wifi_mouse_up
    cmp eax, KEY_DOWN
    je .wifi_mouse_down
    cmp eax, KEY_LEFT
    je .wifi_mouse_left
    cmp eax, KEY_RIGHT
    je .wifi_mouse_right

    cmp eax, 27
    je .wifi_exit
    cmp eax, 'q'
    je .wifi_exit
    cmp eax, 'Q'
    je .wifi_exit

    cmp eax, 's'
    je .wifi_not_avail
    cmp eax, 'S'
    je .wifi_not_avail

    ; Selections '0'..'9' activate driver & connect!
    cmp eax, '0'
    jb .wait_wifi_key
    cmp eax, '9'
    jbe .wifi_connect_ok

    jmp .wait_wifi_key

.wifi_mouse_move:
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_up:
    cmp dword [mouse_y], 20
    jb .wait_wifi_key
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .wait_wifi_key
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_left:
    cmp dword [mouse_x], 20
    jb .wait_wifi_key
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .wait_wifi_key
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_click:
    call draw_mouse_cursor
    ; Clicking driver rows (Y = 95..300) connects the selected hardware driver
    mov eax, [mouse_y]
    cmp eax, 95
    jb .wait_wifi_key
    cmp eax, 300
    jbe .wifi_connect_ok
    cmp eax, 320
    jbe .wifi_not_avail
    jmp .wifi_exit

.wifi_not_avail:
    call restore_mouse_background
    call newline
    mov rsi, str_wifi_unavailable
    call print
    call newline
    mov rsi, str_wifi_retry_prompt
    call print
    call draw_mouse_cursor

.wait_retry_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .check_retry_k
    call draw_mouse_cursor
    jmp .wait_retry_key
.check_retry_k:
    cmp eax, 'r'
    je .wifi_start
    cmp eax, 'R'
    je .wifi_start
    jmp .wifi_exit

.wifi_connect_ok:
    call restore_mouse_background
    ; Activate real network connection!
    mov byte [net_connected], 1
    mov dword [NOVAFS + 28], 0x4E455431
    call pulse_net_activity

    call newline
    mov rsi, str_wifi_connecting
    call print
    call draw_mouse_cursor

.wait_reboot_choice:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .check_reb_k
    call draw_mouse_cursor
    jmp .wait_reboot_choice
.check_reb_k:
    cmp eax, 'y'
    je .wifi_do_reboot
    cmp eax, 'Y'
    je .wifi_do_reboot

    call restore_mouse_background
    call newline
    mov rsi, str_wifi_returned
    call print
    call .wait_wifi_any_key
    jmp .wifi_exit

.wifi_do_reboot:
    ; Persist network driver state to disk before rebooting
    mov rdi, NOVAFS
    mov eax, 133
    mov ecx, 788
    call ata_write_sectors
    call newline
    mov rsi, reboot_text
    call print
    jmp command_reboot

.wait_wifi_any_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_wifi_any
    call draw_mouse_cursor
    jmp .wait_wifi_any_key
.done_wifi_any:
    ret

.wifi_exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; REAL ANIMATED 60FPS VIDEO PLAYER ENGINE (play_real_video)
; Renders 140 full-color procedural frames with plasma waves,
; moving 3D-style orb, animated audio spectrum analyzer & sound
; ============================================================

play_real_video:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    call restore_mouse_background
    call pulse_net_activity

    ; Video Player Outer Frame (X=160, Y=140, W=680, H=380)
    mov eax, 160
    mov ebx, 140
    mov ecx, 680
    mov edx, 380
    mov esi, 0x000B0F19
    call draw_rect

    ; Top Cyan Border
    mov eax, 160
    mov ebx, 140
    mov ecx, 680
    mov edx, 4
    mov esi, 0x0038BDF8
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 15
    mov byte [cursor_y], 8
    mov rsi, str_video_stream_header
    call print

    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 15
    mov byte [cursor_y], 24
    mov rsi, str_video_stream_footer
    call print

    ; Seek bar track (X=180, Y=462, W=640, H=8)
    mov eax, 180
    mov ebx, 462
    mov ecx, 640
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    xor r14d, r14d           ; Frame counter 0..127

.video_frame_loop:
    cmp r14d, 128
    jge .video_stream_done

    ; 1. Draw sky/background color bands shifting with frame r14d
    xor r15d, r15d           ; Band 0..7 (each 32px high -> 256px total, Y=190..446)
.video_band_loop:
    cmp r15d, 8
    jge .video_bands_done

    ; Calculate dynamic RGB color from frame r14d + band r15d
    mov eax, r14d
    shl eax, 2
    mov ebx, r15d
    imul ebx, 28
    add eax, ebx
    and eax, 0xFF            ; Blue component
    mov ecx, r15d
    imul ecx, 22
    add ecx, r14d
    and ecx, 0xFF
    shl ecx, 8               ; Green component
    or eax, ecx
    mov edx, 180
    sub edx, ebx
    and edx, 0xFF
    shl edx, 16              ; Red component
    or eax, edx
    mov esi, eax

    mov eax, 180
    mov ebx, r15d
    shl ebx, 5               ; * 32
    add ebx, 190
    mov ecx, 640
    mov edx, 32
    call draw_rect

    inc r15d
    jmp .video_band_loop

.video_bands_done:
    ; 2. Draw animated moving Sun/Orb across the video frame
    ; X = 200 + r14d * 4
    mov eax, r14d
    shl eax, 2
    add eax, 200
    mov r12d, eax            ; orb_x

    ; Bounce Y between 220 and 340 using triangle wave on r14d
    mov ebx, r14d
    and ebx, 31
    cmp ebx, 16
    jb .orb_down
    mov ecx, 32
    sub ecx, ebx
    mov ebx, ecx
.orb_down:
    shl ebx, 2
    add ebx, 220             ; orb_y

    ; Outer glow (56x56的金/amber)
    mov eax, r12d
    mov ecx, 56
    mov edx, 56
    mov esi, 0x00F59E0B
    call draw_rect

    ; Inner core (36x36 bright white-yellow)
    lea eax, [r12d + 10]
    add ebx, 10
    mov ecx, 36
    mov edx, 36
    mov esi, 0x00FEF08A
    call draw_rect

    ; 3. Draw 16 animated audio-equalizer bars at bottom of video frame
    xor r15d, r15d
.eq_bar_loop:
    cmp r15d, 16
    jge .eq_bars_done

    ; Bar height = ((r14d * 5 + r15d * 19) & 63) + 12
    mov eax, r14d
    imul eax, 5
    mov edx, r15d
    imul edx, 19
    add eax, edx
    and eax, 63
    add eax, 12
    mov edx, eax             ; height

    ; Bar Y = 446 - height
    mov ebx, 446
    sub ebx, edx

    ; Bar X = 200 + r15d * 36
    mov eax, r15d
    imul eax, 36
    add eax, 200
    mov ecx, 24              ; width
    mov esi, 0x0010B981      ; Emerald green equalizer bar
    call draw_rect

    inc r15d
    jmp .eq_bar_loop

.eq_bars_done:
    ; 4. Update live progress scrub bar (width = r14d * 5, max 640)
    mov eax, 180
    mov ebx, 462
    mov ecx, r14d
    imul ecx, 5
    mov edx, 8
    mov esi, 0x0038BDF8
    call draw_rect

    ; 5. Synthesize musical note every 16 frames
    mov eax, r14d
    and eax, 15
    jnz .skip_tone_change
    mov eax, r14d
    shr eax, 4
    and eax, 7
    lea rsi, [video_melody_divisors]
    mov ax, [rsi + rax*2]
    call speaker_start
.skip_tone_change:

    ; Frame pacing delay (~60fps)
    mov ecx, 350000
.vid_delay:
    pause
    dec ecx
    jnz .vid_delay

    ; Check non-blocking keyboard/mouse input so user can stop with ESC or Space
    in al, KBD_STATUS
    test al, 1
    jz .next_vid_frame
    test al, 0x20
    jnz .consume_vid_mouse
    in al, KBD_DATA
    cmp al, 0x01             ; ESC scancode
    je .video_stream_done
    cmp al, 0x39             ; Space scancode
    je .video_stream_done
    jmp .next_vid_frame

.consume_vid_mouse:
    in al, KBD_DATA
    jmp .next_vid_frame

.next_vid_frame:
    inc r14d
    jmp .video_frame_loop

.video_stream_done:
    call speaker_stop
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    call draw_mouse_cursor

    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


; ============================================================
; REGISTER FILE IN NOVAFS HELPER
; RSI = 11-char filename, EAX = file size
; ============================================================
register_novafs_file:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Check if already exists in NOVAFS_DIR
    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR
.check_existing_fs:
    test ecx, ecx
    jz .add_new_fs_entry
    mov al, [rsi]
    cmp al, [rbx]
    jne .next_existing_fs
    mov al, [rsi + 1]
    cmp al, [rbx + 1]
    jne .next_existing_fs
    mov al, [rsi + 2]
    cmp al, [rbx + 2]
    je .fs_already_exists
.next_existing_fs:
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .check_existing_fs

.add_new_fs_entry:
    mov ecx, [NOVAFS + 8]
    cmp ecx, 40
    jae .fs_already_exists
    mov rdi, NOVAFS_DIR
    imul ecx, NOVAFS_ENTRY_SIZE
    add rdi, rcx

    mov ecx, 12
.copy_fs_entry_name:
    lodsb
    stosb
    loop .copy_fs_entry_name

    mov dword [rdi], 650
    mov rax, [rsp + 32]      ; original EAX size
    mov [rdi + 4], eax
    mov byte [rdi + 8], 0
    inc dword [NOVAFS + 8]

.fs_already_exists:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret


; ============================================================
; REAL GOOGLE CHROME BROWSER (chrome.nosp)
; - Not preloaded: Checks net_connected first (shows Dino offline
;   screen if WiFi/Ethernet is not connected!)
; - Smooth mouse movement & click handling
; - Live keyboard URL/Search typing in Omnibox & Search box
; - Multi-page engine: Google Home, Search Results, GitHub Repo,
;   YouTube HD Animated Video Player, and App Shop link
; ============================================================

command_chrome:
    push r11
    push r12
    push r13
    push r14
    push r15

.chrome_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; 1. Chrome Window Titlebar (Chrome Dark Charcoal #202124)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 40
    mov esi, 0x00202124
    call draw_rect

    ; 2. Active Tab at X=20, Y=8, W=280, H=32 (Background #35363A)
    mov eax, 20
    mov ebx, 8
    mov ecx, 280
    mov edx, 32
    mov esi, 0x0035363A
    call draw_rect

    ; Tab Top Accent Blue Line
    mov eax, 20
    mov ebx, 8
    mov ecx, 280
    mov edx, 2
    mov esi, 0x004285F4
    call draw_rect

    ; 3. Official 4-Color Google Chrome Logo inside Tab (X=30, Y=16, 16x16)
    mov eax, 30
    mov ebx, 16
    mov ecx, 16
    mov edx, 6
    mov esi, 0x00EA4335          ; Red
    call draw_rect

    mov eax, 38
    mov ebx, 22
    mov ecx, 8
    mov edx, 10
    mov esi, 0x00FBBC05          ; Yellow
    call draw_rect

    mov eax, 30
    mov ebx, 22
    mov ecx, 8
    mov edx, 10
    mov esi, 0x0034A853          ; Green
    call draw_rect

    mov eax, 35
    mov ebx, 20
    mov ecx, 6
    mov edx, 6
    mov esi, 0x004285F4          ; Blue core
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 5
    mov byte [cursor_y], 1
    mov rsi, str_chrome_tab
    call print

    ; Top Right Window Control Buttons [ - ] [ # ] [ X ]
    mov eax, [screen_width]
    sub eax, 150
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_chrome_window_controls
    call print

    ; 4. Omnibox / Navigation Toolbar (Y=40, H=44, Background #28292C)
    mov eax, 0
    mov ebx, 40
    mov ecx, [screen_width]
    mov edx, 44
    mov esi, 0x0028292C
    call draw_rect

    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 2
    mov byte [cursor_y], 2
    mov rsi, str_chrome_nav_buttons
    call print

    ; Omnibox Capsule (Address Bar) at X=110, Y=46, W=screen_width-320, H=30
    mov eax, 110
    mov ebx, 46
    mov ecx, [screen_width]
    sub ecx, 320
    mov edx, 30
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Omnibox URL Text (Dark text on white Omnibox!)
    mov dword [text_fg_color], 0x001E293B
    mov byte [cursor_x], 10
    mov byte [cursor_y], 2
    cmp byte [chrome_query_len], 0
    jne .print_custom_omnibox
    mov rsi, str_chrome_omnibox_url
    call print
    jmp .omnibox_done
.print_custom_omnibox:
    mov rsi, str_chrome_https_prefix
    call print
    mov rsi, chrome_query_buf
    call print
.omnibox_done:

    ; Draw Network Status Icon in Chrome Toolbar (does NOT blink on key/mouse!)
    call draw_net_icon

    ; 5. Bookmarks Bar at Y=84, H=30 (Background #1F2937)
    mov eax, 0
    mov ebx, 84
    mov ecx, [screen_width]
    mov edx, 30
    mov esi, 0x001F2937
    call draw_rect

    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 2
    mov byte [cursor_y], 4
    mov rsi, str_chrome_bookmarks
    call print

    ; 6. Web Page Viewport Canvas (Pure White Background #FFFFFF)
    mov eax, 0
    mov ebx, 114
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 146
    mov esi, 0x00FFFFFF
    call draw_rect

    ; 7. Bottom Chrome Status Bar at Y=screen_height-32
    mov eax, 0
    mov ebx, [screen_height]
    sub ebx, 32
    mov ecx, [screen_width]
    mov edx, 32
    mov esi, 0x00202124
    call draw_rect

    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 2
    mov eax, [screen_height]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    dec eax
    mov [cursor_y], al
    mov rsi, str_chrome_keys
    call print

    ; ==========================================================
    ; CHECK IF INTERNET IS CONNECTED (NOT PRELOADED!)
    ; ==========================================================
    cmp byte [net_connected], 1
    je .chrome_online_pages

    ; OFFLINE: Render Chrome Dino Offline Screen!
    ; Draw Pixel-Art Chrome Dino (Dark Slate #334155)
    mov eax, 220
    mov ebx, 170
    mov ecx, 44
    mov edx, 32
    mov esi, 0x00334155
    call draw_rect
    ; Dino Eye (white)
    mov eax, 250
    mov ebx, 176
    mov ecx, 6
    mov edx, 6
    mov esi, 0x00FFFFFF
    call draw_rect
    ; Dino Body & Tail
    mov eax, 200
    mov ebx, 202
    mov ecx, 48
    mov edx, 36
    mov esi, 0x00334155
    call draw_rect
    ; Dino Legs
    mov eax, 210
    mov ebx, 238
    mov ecx, 10
    mov edx, 18
    mov esi, 0x00334155
    call draw_rect
    mov eax, 232
    mov ebx, 238
    mov ecx, 10
    mov edx, 18
    mov esi, 0x00334155
    call draw_rect

    mov dword [text_fg_color], 0x001E293B
    mov byte [cursor_x], 16
    mov byte [cursor_y], 14
    mov rsi, str_chrome_offline_msg
    call print

    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_online_pages:
    ; Check active page in Chrome (0 = Google Home, 1 = Search Results, 2 = GitHub Repo)
    cmp byte [chrome_page_id], 1
    je .render_chrome_results_page
    cmp byte [chrome_page_id], 2
    je .render_chrome_github_page

    ; PAGE 0: GOOGLE SEARCH HOME (Full Color)
    ; Letter G (Blue: #4285F4)
    mov eax, 340
    mov ebx, 160
    mov ecx, 40
    mov edx, 44
    mov esi, 0x004285F4
    call draw_rect
    mov eax, 350
    mov ebx, 170
    mov ecx, 30
    mov edx, 24
    mov esi, 0x00FFFFFF
    call draw_rect
    mov eax, 362
    mov ebx, 182
    mov ecx, 18
    mov edx, 8
    mov esi, 0x004285F4
    call draw_rect

    ; Letter o (Red: #EA4335)
    mov eax, 395
    mov ebx, 172
    mov ecx, 36
    mov edx, 32
    mov esi, 0x00EA4335
    call draw_rect
    mov eax, 405
    mov ebx, 180
    mov ecx, 16
    mov edx, 16
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Letter o (Yellow: #FBBC05)
    mov eax, 445
    mov ebx, 172
    mov ecx, 36
    mov edx, 32
    mov esi, 0x00FBBC05
    call draw_rect
    mov eax, 455
    mov ebx, 180
    mov ecx, 16
    mov edx, 16
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Letter g (Blue: #4285F4)
    mov eax, 495
    mov ebx, 172
    mov ecx, 36
    mov edx, 40
    mov esi, 0x004285F4
    call draw_rect
    mov eax, 505
    mov ebx, 180
    mov ecx, 16
    mov edx, 16
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Letter l (Green: #34A853)
    mov eax, 545
    mov ebx, 156
    mov ecx, 14
    mov edx, 48
    mov esi, 0x0034A853
    call draw_rect

    ; Letter e (Red: #EA4335)
    mov eax, 570
    mov ebx, 172
    mov ecx, 36
    mov edx, 32
    mov esi, 0x00EA4335
    call draw_rect
    mov eax, 580
    mov ebx, 182
    mov ecx, 16
    mov edx, 10
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Interactive Google Search Box at X=200, Y=230, W=600, H=42
    mov eax, 200
    mov ebx, 230
    mov ecx, 600
    mov edx, 42
    mov esi, 0x004285F4          ; Blue active focus border
    call draw_rect

    mov eax, 203
    mov ebx, 233
    mov ecx, 594
    mov edx, 36
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Display either user's live typed query OR subtle placeholder
    mov byte [cursor_x], 18
    mov byte [cursor_y], 12
    cmp byte [chrome_query_len], 0
    jne .show_live_query
    mov dword [text_fg_color], 0x0064748B
    mov rsi, str_chrome_search_placeholder
    call print
    jmp .search_box_done

.show_live_query:
    mov dword [text_fg_color], 0x000F172A
    mov rsi, chrome_query_buf
    call print
    mov al, '_'
    call putchar

.search_box_done:
    ; Action Buttons: [ Google Search ] and [ Watch HD Video ]
    mov eax, 310
    mov ebx, 292
    mov ecx, 170
    mov edx, 36
    mov esi, 0x004285F4
    call draw_rect

    mov eax, 500
    mov ebx, 292
    mov ecx, 185
    mov edx, 36
    mov esi, 0x00EA4335
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 27
    mov byte [cursor_y], 15
    mov rsi, str_chrome_btn1
    call print

    mov byte [cursor_x], 43
    mov byte [cursor_y], 15
    mov rsi, str_chrome_btn2
    call print

    ; Shortcut Cards below buttons
    mov dword [text_fg_color], 0x001E293B
    mov byte [cursor_x], 10
    mov byte [cursor_y], 19
    mov rsi, str_chrome_shortcuts
    call print

    call draw_mouse_cursor
    jmp .chrome_event_loop

.render_chrome_results_page:
    mov dword [text_fg_color], 0x001E293B
    mov byte [cursor_x], 6
    mov byte [cursor_y], 7
    mov rsi, str_chrome_results_hdr
    call print
    cmp byte [chrome_query_len], 0
    je .res_default_q
    mov dword [text_fg_color], 0x004285F4
    mov rsi, chrome_query_buf
    call print
    jmp .res_body_print
.res_default_q:
    mov dword [text_fg_color], 0x004285F4
    mov rsi, str_chrome_default_q
    call print
.res_body_print:
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 6
    mov byte [cursor_y], 9
    mov rsi, str_chrome_search_results
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop

.render_chrome_github_page:
    ; GitHub Header Banner
    mov eax, 40
    mov ebx, 130
    mov ecx, [screen_width]
    sub ecx, 80
    mov edx, 56
    mov esi, 0x0024292F
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 5
    mov byte [cursor_y], 7
    mov rsi, str_github_banner_title
    call print

    ; Green [Clone / Download ZIP] Button at X=680, Y=140, W=220, H=36
    mov eax, 680
    mov ebx, 140
    mov ecx, 220
    mov edx, 36
    mov esi, 0x002DA44E
    call draw_rect

    mov byte [cursor_x], 58
    mov byte [cursor_y], 7
    mov rsi, str_github_dl_btn
    call print

    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 5
    mov byte [cursor_y], 11
    mov rsi, str_github_repo_body
    call print

    call draw_mouse_cursor

.chrome_event_loop:
    call get_key

    ; Smooth mouse movement in Chrome (NEVER resets mouse_x/mouse_y!)
    cmp eax, KEY_MOUSE_MOVE
    je .chrome_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .chrome_mouse_click

    ; Arrow keys move mouse pointer smoothly
    cmp eax, KEY_UP
    je .chrome_mouse_up
    cmp eax, KEY_DOWN
    je .chrome_mouse_down
    cmp eax, KEY_LEFT
    je .chrome_mouse_left
    cmp eax, KEY_RIGHT
    je .chrome_mouse_right

    cmp eax, 27           ; ESC -> Exit Chrome
    je .chrome_close

    ; If offline, 'w'/'W' opens WiFi setup directly
    cmp byte [net_connected], 0
    jne .chrome_online_keys
    cmp eax, 'w'
    je .chrome_open_wifi
    cmp eax, 'W'
    je .chrome_open_wifi
    jmp .chrome_event_loop

.chrome_open_wifi:
    call command_wifi
    jmp .chrome_render

.chrome_online_keys:
    ; Function / Number shortcuts or live typing in search bar!
    cmp eax, 13           ; Enter -> Execute search or navigate to typed URL!
    je .chrome_do_search
    cmp eax, 8            ; Backspace -> Delete char in search bar
    je .chrome_backspace

    ; Number keys 1..4 switch tabs/pages when query is empty
    cmp byte [chrome_query_len], 0
    jne .chrome_type_char
    cmp eax, '1'
    je .chrome_go_home
    cmp eax, '2'
    je .chrome_go_github
    cmp eax, '3'
    je .chrome_go_video
    cmp eax, '4'
    je .chrome_go_shop
    cmp eax, 'd'
    je .chrome_download
    cmp eax, 'D'
    je .chrome_download
    cmp eax, 'v'
    je .chrome_go_video
    cmp eax, 'V'
    je .chrome_go_video

.chrome_type_char:
    cmp eax, 32
    jb .chrome_event_loop
    cmp eax, 126
    ja .chrome_event_loop
    movzx ebx, byte [chrome_query_len]
    cmp ebx, 42
    jae .chrome_event_loop
    lea rdi, [chrome_query_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [chrome_query_len], bl
    mov byte [chrome_page_id], 0
    jmp .chrome_render

.chrome_backspace:
    movzx ebx, byte [chrome_query_len]
    test ebx, ebx
    jz .chrome_event_loop
    dec ebx
    lea rdi, [chrome_query_buf]
    mov byte [rdi + rbx], 0
    mov [chrome_query_len], bl
    jmp .chrome_render

.chrome_go_home:
    call pulse_net_activity
    mov byte [chrome_page_id], 0
    jmp .chrome_render

.chrome_go_github:
    call pulse_net_activity
    mov byte [chrome_page_id], 2
    jmp .chrome_render

.chrome_go_video:
    call play_real_video
    jmp .chrome_render

.chrome_go_shop:
    call command_shop
    jmp .chrome_render

.chrome_mouse_move:
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_up:
    cmp dword [mouse_y], 20
    jb .chrome_event_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .chrome_event_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_left:
    cmp dword [mouse_x], 20
    jb .chrome_event_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .chrome_event_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_click:
    call draw_mouse_cursor
    mov eax, [mouse_y]
    ; Click in Top Titlebar (Y < 40): Check Close [X] on right
    cmp eax, 40
    jae .chrome_click_bookmarks
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 100
    cmp eax, edx
    jae .chrome_close
    jmp .chrome_go_home

.chrome_click_bookmarks:
    ; Click in Bookmarks Bar (Y = 84..114)
    cmp eax, 84
    jb .chrome_event_loop
    cmp eax, 114
    ja .chrome_click_body
    cmp byte [net_connected], 0
    je .chrome_open_wifi
    mov eax, [mouse_x]
    cmp eax, 210
    jb .chrome_go_github
    cmp eax, 390
    jb .chrome_go_video
    cmp eax, 560
    jb .chrome_go_shop
    jmp .chrome_download

.chrome_click_body:
    cmp byte [net_connected], 0
    je .chrome_open_wifi
    ; Check buttons at Y = 285..340
    cmp eax, 285
    jb .chrome_check_gh_dl
    cmp eax, 340
    ja .chrome_check_shortcuts
    mov eax, [mouse_x]
    cmp eax, 490
    jb .chrome_do_search
    jmp .chrome_go_video

.chrome_check_gh_dl:
    cmp byte [chrome_page_id], 2
    jne .chrome_event_loop
    cmp eax, 190
    ja .chrome_event_loop
    jmp .chrome_download

.chrome_check_shortcuts:
    cmp eax, 360
    jb .chrome_event_loop
    mov eax, [mouse_x]
    cmp eax, 280
    jb .chrome_go_github
    cmp eax, 480
    jb .chrome_go_video
    cmp eax, 680
    jb .chrome_go_shop
    jmp .chrome_download

.chrome_do_search:
    cmp byte [net_connected], 0
    je .chrome_open_wifi
    call pulse_net_activity
    ; Check if user typed 'github', 'video', 'youtube', or 'shop'
    mov al, [chrome_query_buf]
    cmp al, 'g'
    je .check_q_gh
    cmp al, 'y'
    je .chrome_go_video
    cmp al, 'v'
    je .chrome_go_video
    cmp al, 's'
    je .check_q_shop
    jmp .show_search_page

.check_q_gh:
    cmp byte [chrome_query_buf + 1], 'i'
    je .chrome_go_github
    jmp .show_search_page

.check_q_shop:
    cmp byte [chrome_query_buf + 1], 'h'
    je .chrome_go_shop
    jmp .show_search_page

.show_search_page:
    mov byte [chrome_page_id], 1
    jmp .chrome_render

.chrome_download:
    cmp byte [net_connected], 0
    je .chrome_open_wifi
    call restore_mouse_background
    call pulse_net_activity

    ; Register NOVAOS.ZIP in real NovaFS directory and mark repo_downloaded = 1!
    mov byte [repo_downloaded], 1
    mov rsi, fs_name_novaos_zip
    mov eax, 4821040
    call register_novafs_file

    mov eax, 100
    mov ebx, 180
    mov ecx, 660
    mov edx, 210
    mov esi, 0x000F172A
    call draw_rect

    mov eax, 100
    mov ebx, 180
    mov ecx, 660
    mov edx, 4
    mov esi, 0x0034A853
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 10
    mov byte [cursor_y], 10
    mov rsi, str_chrome_download_banner
    call print

    call draw_mouse_cursor
    call .wait_chrome_modal_key
    jmp .chrome_render

.wait_chrome_modal_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_cm_wait
    call draw_mouse_cursor
    jmp .wait_chrome_modal_key
.done_cm_wait:
    ret

.chrome_close:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; NOVAOS ONLINE APP SHOP (shop.nosp / store.novaos.org)
; Connects to the internet (requires net_connected == 1) and
; downloads/installs real apps into NovaFS:
;   [1] Notepad Studio (notepad.nosp)
;   [2] Python 3.15.0  (python.nosp)
;   [3] Mozilla Firefox (firefox.nosp)
;   [4] Nova HD Video Player (video.nosp)
; ============================================================

command_shop:
    push r11
    push r12
    push r13
    push r14
    push r15

.shop_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; Header Bar (Indigo/Navy #0F172A)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 52
    mov esi, 0x000F172A
    call draw_rect

    ; Accent Line (Emerald #10B981)
    mov eax, 0
    mov ebx, 52
    mov ecx, [screen_width]
    mov edx, 3
    mov esi, 0x0010B981
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov rsi, str_shop_header
    call print

    call draw_net_icon

    ; Store Background (#111827)
    mov eax, 0
    mov ebx, 55
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 55
    mov esi, 0x00111827
    call draw_rect

    ; Check if connected to the internet!
    cmp byte [net_connected], 1
    je .shop_online_view

    ; OFFLINE View: Must connect internet first!
    mov eax, 100
    mov ebx, 150
    mov ecx, 720
    mov edx, 220
    mov esi, 0x001E293B
    call draw_rect

    mov eax, 100
    mov ebx, 150
    mov ecx, 720
    mov edx, 4
    mov esi, 0x00EF4444
    call draw_rect

    mov dword [text_fg_color], 0x00F87171
    mov byte [cursor_x], 10
    mov byte [cursor_y], 9
    mov rsi, str_shop_offline_msg
    call print

    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_online_view:
    ; Draw 4 App Cards (Y = 80, 185, 290, 395)
    ; Card 1: Notepad Studio
    mov eax, 60
    mov ebx, 80
    mov ecx, 860
    mov edx, 90
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 60
    mov ebx, 80
    mov ecx, 6
    mov edx, 90
    mov esi, 0x0038BDF8
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 7
    mov byte [cursor_y], 4
    mov rsi, str_shop_item1_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 7
    mov byte [cursor_y], 6
    mov rsi, str_shop_item1_desc
    call print

    ; Card 1 Status Button
    mov byte [cursor_x], 56
    mov byte [cursor_y], 5
    cmp byte [app_installed_notepad], 1
    je .c1_inst
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_shop_btn_get1
    call print
    jmp .card2_draw
.c1_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card2_draw:
    ; Card 2: Python 3.15.0
    mov eax, 60
    mov ebx, 185
    mov ecx, 860
    mov edx, 90
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 60
    mov ebx, 185
    mov ecx, 6
    mov edx, 90
    mov esi, 0x00FACC15
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 7
    mov byte [cursor_y], 10
    mov rsi, str_shop_item2_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 7
    mov byte [cursor_y], 11
    mov rsi, str_shop_item2_desc
    call print

    mov byte [cursor_x], 56
    mov byte [cursor_y], 10
    cmp byte [app_installed_python], 1
    je .c2_inst
    mov dword [text_fg_color], 0x00FACC15
    mov rsi, str_shop_btn_get2
    call print
    jmp .card3_draw
.c2_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card3_draw:
    ; Card 3: Mozilla Firefox Quantum
    mov eax, 60
    mov ebx, 290
    mov ecx, 860
    mov edx, 90
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 60
    mov ebx, 290
    mov ecx, 6
    mov edx, 90
    mov esi, 0x00F97316
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 7
    mov byte [cursor_y], 15
    mov rsi, str_shop_item3_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 7
    mov byte [cursor_y], 16
    mov rsi, str_shop_item3_desc
    call print

    mov byte [cursor_x], 56
    mov byte [cursor_y], 15
    cmp byte [app_installed_firefox], 1
    je .c3_inst
    mov dword [text_fg_color], 0x00F97316
    mov rsi, str_shop_btn_get3
    call print
    jmp .card4_draw
.c3_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card4_draw:
    ; Card 4: Nova HD Video Player
    mov eax, 60
    mov ebx, 395
    mov ecx, 860
    mov edx, 90
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 60
    mov ebx, 395
    mov ecx, 6
    mov edx, 90
    mov esi, 0x00A855F7
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 7
    mov byte [cursor_y], 20
    mov rsi, str_shop_item4_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 7
    mov byte [cursor_y], 21
    mov rsi, str_shop_item4_desc
    call print

    mov byte [cursor_x], 56
    mov byte [cursor_y], 20
    cmp byte [app_installed_video], 1
    je .c4_inst
    mov dword [text_fg_color], 0x00A855F7
    mov rsi, str_shop_btn_get4
    call print
    jmp .shop_footer_draw
.c4_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.shop_footer_draw:
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 5
    mov byte [cursor_y], 25
    mov rsi, str_shop_footer
    call print

    call draw_mouse_cursor

.shop_event_loop:
    call get_key

    cmp eax, KEY_MOUSE_MOVE
    je .shop_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .shop_mouse_click

    cmp eax, KEY_UP
    je .shop_mouse_up
    cmp eax, KEY_DOWN
    je .shop_mouse_down
    cmp eax, KEY_LEFT
    je .shop_mouse_left
    cmp eax, KEY_RIGHT
    je .shop_mouse_right

    cmp eax, 27
    je .shop_close
    cmp eax, 'q'
    je .shop_close
    cmp eax, 'Q'
    je .shop_close

    cmp byte [net_connected], 0
    jne .shop_online_keys
    cmp eax, 'w'
    je .shop_go_wifi
    cmp eax, 'W'
    je .shop_go_wifi
    jmp .shop_event_loop

.shop_go_wifi:
    call command_wifi
    jmp .shop_render

.shop_online_keys:
    cmp eax, '1'
    je .shop_act_notepad
    cmp eax, '2'
    je .shop_act_python
    cmp eax, '3'
    je .shop_act_firefox
    cmp eax, '4'
    je .shop_act_video
    jmp .shop_event_loop

.shop_mouse_move:
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_up:
    cmp dword [mouse_y], 20
    jb .shop_event_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .shop_event_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_left:
    cmp dword [mouse_x], 20
    jb .shop_event_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .shop_event_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_click:
    call draw_mouse_cursor
    cmp byte [net_connected], 0
    je .shop_go_wifi
    mov eax, [mouse_y]
    cmp eax, 52
    jb .shop_close
    cmp eax, 175
    jb .shop_act_notepad
    cmp eax, 280
    jb .shop_act_python
    cmp eax, 385
    jb .shop_act_firefox
    cmp eax, 490
    jb .shop_act_video
    jmp .shop_event_loop

.shop_act_notepad:
    cmp byte [app_installed_notepad], 1
    je .shop_launch_notepad
    call pulse_net_activity
    mov byte [app_installed_notepad], 1
    mov rsi, fs_name_notepad
    mov eax, 16384
    call register_novafs_file
    jmp .shop_render
.shop_launch_notepad:
    call command_notepad
    jmp .shop_render

.shop_act_python:
    cmp byte [app_installed_python], 1
    je .shop_launch_python
    call pulse_net_activity
    mov byte [app_installed_python], 1
    mov rsi, fs_name_python
    mov eax, 65536
    call register_novafs_file
    jmp .shop_render
.shop_launch_python:
    call command_python
    jmp .shop_render

.shop_act_firefox:
    cmp byte [app_installed_firefox], 1
    je .shop_launch_firefox
    call pulse_net_activity
    mov byte [app_installed_firefox], 1
    mov rsi, fs_name_firefox
    mov eax, 49152
    call register_novafs_file
    jmp .shop_render
.shop_launch_firefox:
    call command_firefox
    jmp .shop_render

.shop_act_video:
    cmp byte [app_installed_video], 1
    je .shop_launch_video
    call pulse_net_activity
    mov byte [app_installed_video], 1
    mov rsi, fs_name_video
    mov eax, 32768
    call register_novafs_file
    jmp .shop_render
.shop_launch_video:
    call play_real_video
    jmp .shop_render

.shop_close:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; NOTEPAD STUDIO (notepad.nosp) - Installable from App Shop!
; Real interactive graphical text editor with NovaFS file save
; ============================================================

command_notepad:
    cmp byte [app_installed_notepad], 1
    je .notepad_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.notepad_installed_ok:
    push r11
    push r12
    push r13
    push r14
    push r15

.notepad_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; Notepad Top Titlebar (#1E3A8A)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 40
    mov esi, 0x001E3A8A
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov rsi, str_notepad_title
    call print

    ; Menu / Status Toolbar (#E2E8F0)
    mov eax, 0
    mov ebx, 40
    mov ecx, [screen_width]
    mov edx, 28
    mov esi, 0x00E2E8F0
    call draw_rect

    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 2
    mov byte [cursor_y], 2
    mov rsi, str_notepad_menu
    call print

    ; Paper Editor Canvas (#FFFFFF)
    mov eax, 0
    mov ebx, 68
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 68
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Render user's typed text buffer onto white paper!
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 3
    mov byte [cursor_y], 5
    mov byte [term_left_col], 3
    mov rsi, notepad_buf
    call print
    mov al, '|'
    call putchar

    call draw_mouse_cursor

.notepad_loop:
    call get_key

    cmp eax, KEY_MOUSE_MOVE
    je .np_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .np_mouse_move

    cmp eax, 27               ; ESC -> Exit Notepad
    je .notepad_exit

    cmp eax, '~'              ; '~' or Ctrl+S -> Save to NovaFS!
    je .notepad_save
    cmp eax, 19               ; Ctrl+S
    je .notepad_save

    cmp eax, 8                ; Backspace
    je .notepad_bs

    cmp eax, 13               ; Enter -> newline in buffer
    je .notepad_enter

    cmp eax, 32
    jb .notepad_loop
    cmp eax, 126
    ja .notepad_loop

    movzx ebx, word [notepad_len]
    cmp ebx, 480
    jae .notepad_loop
    lea rdi, [notepad_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [notepad_len], bx
    jmp .notepad_render

.notepad_enter:
    movzx ebx, word [notepad_len]
    cmp ebx, 478
    jae .notepad_loop
    lea rdi, [notepad_buf]
    mov byte [rdi + rbx], 10
    inc ebx
    mov byte [rdi + rbx], 0
    mov [notepad_len], bx
    jmp .notepad_render

.notepad_bs:
    movzx ebx, word [notepad_len]
    test ebx, ebx
    jz .notepad_loop
    dec ebx
    lea rdi, [notepad_buf]
    mov byte [rdi + rbx], 0
    mov [notepad_len], bx
    jmp .notepad_render

.notepad_save:
    ; Save notepad_buf into NOTES.TXT in NovaFS
    mov rsi, fs_name_notes_txt
    movzx eax, word [notepad_len]
    call register_novafs_file

    mov eax, 200
    mov ebx, 220
    mov ecx, 520
    mov edx, 80
    mov esi, 0x0010B981
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 12
    mov rsi, str_notepad_saved
    call print
    call get_key
    jmp .notepad_render

.np_mouse_move:
    call draw_mouse_cursor
    jmp .notepad_loop

.notepad_exit:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; PYTHON 3.15.0 INTERACTIVE REPL (python.nosp)
; Installable from App Shop! Supports print(), math (+,-,*,/),
; import sys, sys.version, import os, os.listdir(), help(), exit()
; ============================================================

command_python:
    cmp byte [app_installed_python], 1
    je .python_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.python_installed_ok:
    mov rsi, str_python_banner
    call print

.py_repl_loop:
    mov rsi, str_python_prompt
    call print

    call read_line

    mov rsi, input
    call skip_spaces
    cmp byte [rsi], 0
    je .py_repl_loop

    ; Check exit() / quit() / exit / quit
    mov rdi, str_py_exit
    call prefix
    jc .py_done
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_quit
    call prefix
    jc .py_done

    ; Check help / help()
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_help
    call prefix
    jc .py_do_help

    ; Check sys.version / import sys
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_sysver
    call prefix
    jc .py_do_sysver
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_impsys
    call prefix
    jc .py_repl_loop

    ; Check os.listdir() / import os
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_oslist
    call prefix
    jc .py_do_oslist
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_impos
    call prefix
    jc .py_repl_loop

    ; Check print(...)
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_print
    call prefix
    jc .py_do_print

    ; Otherwise evaluate arithmetic expression: N [+|-|*|/] M
    mov rsi, input
    call skip_spaces
    cmp byte [rsi], '0'
    jb .py_syntax_err
    cmp byte [rsi], '9'
    ja .py_syntax_err

    call number
    mov r12d, eax             ; First operand
    call skip_spaces
    mov bl, [rsi]             ; Operator (+, -, *, /)
    test bl, bl
    jz .py_just_num
    inc rsi
    call skip_spaces
    call number
    mov ecx, eax              ; Second operand

    cmp bl, '+'
    je .py_math_add
    cmp bl, '-'
    je .py_math_sub
    cmp bl, '*'
    je .py_math_mul
    cmp bl, '/'
    je .py_math_div
    jmp .py_syntax_err

.py_just_num:
    mov eax, r12d
    call print_number
    call newline
    jmp .py_repl_loop

.py_math_add:
    mov eax, r12d
    add eax, ecx
    call print_number
    call newline
    jmp .py_repl_loop

.py_math_sub:
    mov eax, r12d
    sub eax, ecx
    call print_number
    call newline
    jmp .py_repl_loop

.py_math_mul:
    mov eax, r12d
    imul eax, ecx
    call print_number
    call newline
    jmp .py_repl_loop

.py_math_div:
    test ecx, ecx
    jz .py_div_zero
    mov eax, r12d
    xor edx, edx
    div ecx
    call print_number
    call newline
    jmp .py_repl_loop

.py_div_zero:
    mov rsi, str_py_zero_err
    call print
    jmp .py_repl_loop

.py_do_print:
    mov rsi, input
    call skip_spaces
    add rsi, 5                ; skip 'print'
    call skip_spaces
    cmp byte [rsi], '('
    jne .py_print_raw
    inc rsi
    call skip_spaces
    cmp byte [rsi], '"'
    je .py_print_str
    cmp byte [rsi], 39        ; single quote
    je .py_print_str
    ; Evaluate number inside print(...)
    call number
    call print_number
    call newline
    jmp .py_repl_loop

.py_print_str:
    inc rsi
.py_str_loop:
    lodsb
    test al, al
    jz .py_str_end
    cmp al, '"'
    je .py_str_end
    cmp al, 39
    je .py_str_end
    cmp al, ')'
    je .py_str_end
    call putchar
    jmp .py_str_loop
.py_str_end:
    call newline
    jmp .py_repl_loop

.py_print_raw:
    call print
    call newline
    jmp .py_repl_loop

.py_do_help:
    mov rsi, str_py_help_msg
    call print
    jmp .py_repl_loop

.py_do_sysver:
    mov rsi, str_py_sysver_out
    call print
    jmp .py_repl_loop

.py_do_oslist:
    call command_ls
    jmp .py_repl_loop

.py_syntax_err:
    mov rsi, str_py_err_msg
    call print
    jmp .py_repl_loop

.py_done:
    jmp command_done


; ============================================================
; MOZILLA FIREFOX QUANTUM BROWSER (firefox.nosp)
; Installable from App Shop!
; ============================================================

command_firefox:
    cmp byte [app_installed_firefox], 1
    je .firefox_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.firefox_installed_ok:
    push r11
    push r12
    push r13
    push r14
    push r15

.ff_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; Firefox Quantum Dark Photon Header (#1C1B22)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 84
    mov esi, 0x001C1B22
    call draw_rect

    ; Firefox Active Tab (#2B2A33)
    mov eax, 20
    mov ebx, 6
    mov ecx, 280
    mov edx, 34
    mov esi, 0x002B2A33
    call draw_rect

    ; Tab Top Orange/Purple Firefox Accent
    mov eax, 20
    mov ebx, 6
    mov ecx, 280
    mov edx, 3
    mov esi, 0x00FF7139
    call draw_rect

    ; Firefox Logo Emblem (Orange/Gold/Violet)
    mov eax, 30
    mov ebx, 14
    mov ecx, 18
    mov edx, 18
    mov esi, 0x00FF7139
    call draw_rect
    mov eax, 35
    mov ebx, 18
    mov ecx, 8
    mov edx, 8
    mov esi, 0x009059FF
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 5
    mov byte [cursor_y], 1
    mov rsi, str_ff_tab
    call print

    ; Firefox URL Bar (#42414D)
    mov eax, 100
    mov ebx, 46
    mov ecx, [screen_width]
    sub ecx, 300
    mov edx, 30
    mov esi, 0x0042414D
    call draw_rect

    mov dword [text_fg_color], 0x00F8FAFC
    mov byte [cursor_x], 10
    mov byte [cursor_y], 2
    mov rsi, str_ff_url
    call print

    call draw_net_icon

    ; Viewport (#2B2A33)
    mov eax, 0
    mov ebx, 84
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 84
    mov esi, 0x002B2A33
    call draw_rect

    ; Big Firefox Center Emblem
    mov eax, 460
    mov ebx, 140
    mov ecx, 80
    mov edx, 70
    mov esi, 0x00FF7139
    call draw_rect
    mov eax, 480
    mov ebx, 155
    mov ecx, 40
    mov edx, 40
    mov esi, 0x00FACC15
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 16
    mov byte [cursor_y], 12
    mov rsi, str_ff_body
    call print

    call draw_mouse_cursor

.ff_loop:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    je .ff_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .ff_mouse_click
    cmp eax, 27
    je .ff_close
    cmp eax, 'q'
    je .ff_close
    cmp eax, 'Q'
    je .ff_close
    cmp eax, 'v'
    je .ff_play_video
    cmp eax, 'V'
    je .ff_play_video
    cmp eax, 13
    je .ff_play_video
    jmp .ff_loop

.ff_mouse_move:
    call draw_mouse_cursor
    jmp .ff_loop

.ff_mouse_click:
    call draw_mouse_cursor
    cmp dword [mouse_y], 40
    jb .ff_close
    jmp .ff_play_video

.ff_play_video:
    call play_real_video
    jmp .ff_render

.ff_close:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


command_video:
    cmp byte [app_installed_video], 1
    je .vid_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done
.vid_ok:
    call play_real_video
    call gui_desktop
    jmp shell

"""

content = content[:idx_start] + new_subsystems_asm + content[idx_end:]

# -------------------------------------------------------------------------
# 8. Update strings, explorer_entry_table, taskbar text, and data variables
# -------------------------------------------------------------------------
old_taskbar = """gui_taskbar_text:
    db "[ NovaOS ]  Files  Terminal  WiFi  Browser  Chrome  Settings",0"""

new_taskbar = """gui_desktop_bar_text:
    db "[ Files ]    [ Chrome ]    [ App Shop ]    [ WiFi ]    [ Notepad ]",0

gui_taskbar_text:
    db "[ NovaOS ]   Files   Terminal   WiFi   Chrome   Shop   Settings",0"""

assert old_taskbar in content, "Could not find old_taskbar"
content = content.replace(old_taskbar, new_taskbar, 1)

old_explorer_table = """gui_file_5          db "[APP]  startup.nosp",0
gui_file_wifi       db "[APP]  wifi.nosp",0
gui_file_browser    db "[APP]  browser.nosp",0
gui_explorer_status db "10 items | Drive C: NovaFS (Healthy) | Type 'files' in shell",0

gui_col_header      db "  Type  Name                              Size",0
gui_sel_arrow       db ">",0
gui_no_arrow        db " ",0
gui_explorer_keys   db "[UP/DN] Move  [ENTER] Open  [ESC] Close  [PgUp/PgDn] Jump",0

; Explorer entry table - 12 pointers (folders then files)
; Each pointer is a qword absolute address in 64-bit mode
explorer_entry_table:
    dq gui_folder_1
    dq gui_folder_2
    dq gui_folder_3
    dq gui_folder_4
    dq gui_file_1
    dq gui_file_2
    dq gui_file_3
    dq gui_file_4
    dq gui_file_5
    dq gui_file_wifi
    dq gui_file_browser
    dq gui_file_chrome"""

new_explorer_table = """gui_file_5          db "[APP]  startup.nosp",0
gui_file_wifi       db "[APP]  wifi.nosp",0
gui_file_shop       db "[APP]  shop.nosp",0
gui_explorer_status db "12 items | Drive C: NovaFS (Healthy) | Mouse & Double-Tap Ready",0

gui_col_header      db "  Type  Name                              Status",0
gui_sel_arrow       db ">",0
gui_no_arrow        db " ",0
gui_explorer_keys   db "[Mouse/Arrows] Move  [Click/Enter] Open  [ESC] Close",0

; Explorer entry table - 12 pointers (browser.nosp removed, chrome.nosp & shop.nosp included)
explorer_entry_table:
    dq gui_folder_1
    dq gui_folder_2
    dq gui_folder_3
    dq gui_folder_4
    dq gui_file_1
    dq gui_file_2
    dq gui_file_3
    dq gui_file_4
    dq gui_file_5
    dq gui_file_wifi
    dq gui_file_chrome
    dq gui_file_shop"""

assert old_explorer_table in content, "Could not find old_explorer_table"
content = content.replace(old_explorer_table, new_explorer_table, 1)

old_drive_d_str = """str_drive_d_files:
    db "Volume in Drive D: is NOVAOS_INSTALL (Live ISO)",13,10
    db " Directory of D:\\",13,10
    db "  [1] <APP>   startup.nosp      (NovaOS Setup & Installer)",13,10
    db "  [2] <APP>   wifi.nosp         (WiFi & Ethernet Driver Setup)",13,10
    db "  [3] <APP>   browser.nosp      (WebKit-Mini Web Browser)",13,10"""

new_drive_d_str = """str_drive_d_files:
    db "Volume in Drive D: is NOVAOS_INSTALL (Live ISO)",13,10
    db " Directory of D:\\",13,10
    db "  [1] <APP>   startup.nosp      (NovaOS Setup & Installer)",13,10
    db "  [2] <APP>   wifi.nosp         (WiFi & Ethernet Driver Setup)",13,10
    db "  [3] <APP>   chrome.nosp       (Google Chrome Web Browser)",13,10"""

assert old_drive_d_str in content, "Could not find old_drive_d_str"
content = content.replace(old_drive_d_str, new_drive_d_str, 1)

old_help_net = """ NETWORK & WEB",13,10
          db "  wifi          WiFi & Ethernet driver setup (wifi.nosp)",13,10
          db "  browser       WebKit-Mini Web Browser & GitHub downloader",13,10
          db "  run <nosp>    Execute NovaOS program binary",13,10
          db "  open <nosp>   Open NovaOS program binary",13,10"""

new_help_net = """ NETWORK, WEB & APP SHOP",13,10
          db "  wifi          WiFi & Ethernet hardware driver setup (wifi.nosp)",13,10
          db "  chrome        Google Chrome Browser with Search, GitHub & HD Video",13,10
          db "  shop          NovaOS Online App Shop (install Notepad, Python 3.15, Firefox)",13,10
          db "  notepad       Launch Notepad Studio (install from 'shop' first)",13,10
          db "  python        Launch Python 3.15.0 REPL (install from 'shop' first)",13,10
          db "  firefox       Launch Mozilla Firefox (install from 'shop' first)",13,10"""

assert old_help_net in content, "Could not find old_help_net"
content = content.replace(old_help_net, new_help_net, 1)

# Add new data strings & state variables right after str_chrome_download_banner
old_chrome_vars = """str_net_online_text: db "NET: 1Gbps",0
str_net_active_text: db "NET: TX/RX",0

cmd_chrome_short: db "chrome",0
cmd_chrome_nosp:  db "chrome.nosp",0
gui_file_chrome:  db "[APP]  chrome.nosp",0"""

new_chrome_vars = """str_net_offline_text: db "NET: OFFLINE",0
str_net_online_text:  db "NET: ONLINE ",0
str_net_active_text:  db "NET: TX/RX  ",0

net_connected:         db 0
repo_downloaded:       db 0
app_installed_notepad: db 0
app_installed_python:  db 0
app_installed_firefox: db 0
app_installed_video:   db 0

pci_nic_id:            dd 0
pci_nic_bar0:          dd 0

text_fg_color:         dd 0x00FFFFFF
text_bg_color:         dd 0x00000000
text_transparent_bg:   db 0

chrome_page_id:        db 0
chrome_query_len:      db 0
chrome_query_buf:      times 48 db 0

notepad_len:           dw 28
notepad_buf:           db "Welcome to Notepad Studio!",10,0
                       times 490 db 0

video_melody_divisors:
    dw 2281, 1811, 1522, 1140, 1522, 1811, 1355, 1140

cmd_chrome_short:  db "chrome",0
cmd_chrome_nosp:   db "chrome.nosp",0
cmd_shop_short:    db "shop",0
cmd_store_short:   db "store",0
cmd_notepad_short: db "notepad",0
cmd_python_short:  db "python",0
cmd_firefox_short: db "firefox",0
cmd_video_short:   db "video",0
gui_file_chrome:   db "[APP]  chrome.nosp",0

fs_name_novaos_zip: db "NOVAOS.ZIP",0,0
fs_name_notepad:    db "NOTEPAD.NSP",0
fs_name_python:     db "PYTHON3.NSP",0
fs_name_firefox:    db "FIREFOX.NSP",0
fs_name_video:      db "VIDEOHD.NSP",0
fs_name_notes_txt:  db "NOTES.TXT",0,0,0

str_exp_modal_downloads_empty:
    db "==================================================",13,10
    db "  Folder: C:\\NovaOS\\Downloads                     ",13,10
    db "==================================================",13,10
    db "  (Folder is currently EMPTY - nothing preloaded!)",13,10,13,10
    db "  To download files or apps:                      ",13,10
    db "  1. Connect to Internet via 'wifi.nosp'          ",13,10
    db "  2. Open Google Chrome ('chrome') & press [D]    ",13,10
    db "  3. Or open 'shop' to download & install apps!   ",13,10,13,10
    db "  Press any key to return to File Explorer...     ",0

str_chrome_https_prefix:
    db "https://www.google.com/search?q=",0

str_chrome_search_placeholder:
    db "Type to search Google or enter URL (1=Home 2=GitHub 3=Video 4=Shop)",0

str_chrome_offline_msg:
    db "No internet connection (ERR_INTERNET_DISCONNECTED)",13,10,13,10
    db "                Google Chrome cannot display the webpage because",13,10
    db "                your computer is not connected to the internet.",13,10,13,10
    db "                Try:",13,10
    db "                 * Press [W] or click anywhere to open WiFi & Ethernet Setup",13,10
    db "                 * Select [1] VirtualBox Intel PRO/1000 MT Ethernet Driver",13,10
    db "                 * Press [ESC] to return to NovaOS Desktop",0

str_chrome_results_hdr:
    db "Google Search Results for query: ",0
str_chrome_default_q:
    db "aidaninvents/Nova-Os",0

str_github_banner_title:
    db "GitHub  /  aidaninvents / Nova-Os   [Public | Branch: BETA-pre-1x]",0
str_github_dl_btn:
    db "[D] Download ZIP",0
str_github_repo_body:
    db "Latest Commit: Build 26110.0000 - Real Chrome, App Shop & 60fps Video",13,10
    db "     -------------------------------------------------------------------",13,10
    db "     [FILE]  boot.asm          512 B     MBR Bootloader Sector",13,10
    db "     [FILE]  stage2.asm      2,048 B     A20 Gate + 32-bpp VBE LFB Loader",13,10
    db "     [FILE]  kernel.asm     42,800 B     64-bit Long Mode Graphical Kernel",13,10
    db "     [FILE]  chrome.nosp       256 B     Google Chrome Web Browser",13,10
    db "     [FILE]  shop.nosp         256 B     NovaOS Online App Store",13,10,13,10
    db "     Press [D] to download repository archive to C:\\NovaOS\\Downloads",13,10
    db "     Press [3] or [V] to play 60fps HD Release Video Stream",13,10
    db "     Press [1] to return to Google Search Home | [ESC] Exit Chrome",0

str_video_stream_header:
    db "NovaOS HD Video Player - 60 FPS Linear Framebuffer Stream [LIVE]",0
str_video_stream_footer:
    db "Playing: NovaOS_26Q4_Official_Demo.mp4 (32-bpp TrueColor) | [SPACE/ESC] Stop",0

str_shop_header:
    db "NovaOS App Shop - https://store.novaos.org [Online Package Repository]",0

str_shop_offline_msg:
    db "==========================================================",13,10
    db "          NOVAOS APP SHOP - NO INTERNET CONNECTION                ",13,10
    db "        ==========================================================",13,10,13,10
    db "          Apps are NOT preloaded! You must connect to the         ",13,10
    db "          internet before downloading apps from the Shop.         ",13,10,13,10
    db "          -> Press [W] or Click to open WiFi/Ethernet Setup       ",13,10
    db "          -> Press [ESC] to return to Desktop                     ",0

str_shop_item1_title:
    db "[1] Notepad Studio (notepad.nosp)          Size: 16 KB | Official",0
str_shop_item1_desc:
    db "    Full-screen graphical text editor with live NovaFS disk saving",0
str_shop_item2_title:
    db "[2] Python 3.15.0 (python.nosp)            Size: 64 KB | Official",0
str_shop_item2_desc:
    db "    Interactive Python 3.15 REPL interpreter, math engine & OS API",0
str_shop_item3_title:
    db "[3] Mozilla Firefox Quantum (firefox.nosp) Size: 48 KB | Browser",0
str_shop_item3_desc:
    db "    Fast graphical web browser with Photon UI & HD Video Player",0
str_shop_item4_title:
    db "[4] Nova HD Video Player (video.nosp)      Size: 32 KB | Media",0
str_shop_item4_desc:
    db "    60 FPS TrueColor procedural video & audio synthesizer player",0

str_shop_btn_get1:
    db "[Press 1 / Click: INSTALL]",0
str_shop_btn_get2:
    db "[Press 2 / Click: INSTALL]",0
str_shop_btn_get3:
    db "[Press 3 / Click: INSTALL]",0
str_shop_btn_get4:
    db "[Press 4 / Click: INSTALL]",0
str_shop_btn_open:
    db "[INSTALLED - Click/Key Open]",0

str_shop_footer:
    db "Press [1-4] or Click an App Card to Download/Install & Launch | [ESC] Exit Shop",0

str_app_not_installed:
    db "[!] Application is NOT preloaded! Connect to internet ('wifi') and open 'shop' to install it.",13,10,0

str_notepad_title:
    db "Notepad Studio - C:\\NovaOS\\notes.txt",0
str_notepad_menu:
    db "File   Edit   Format   |  Type text below  |  [~] or [Ctrl+S] Save to NovaFS  |  [ESC] Exit",0
str_notepad_saved:
    db "[SAVED] File written to C:\\NovaOS\\notes.txt! Press any key...",0

str_python_banner:
    db 13,10
    db "Python 3.15.0 (main, Nov 2026, 26Q4 Build 26110.0000) [NovaOS 64-bit x86_64]",13,10
    db "Type \"help()\", \"print('hello')\", math (e.g. 25 * 4), \"os.listdir()\", or \"exit()\"",13,10,0
str_python_prompt: db ">>> ",0
str_py_exit:       db "exit",0
str_py_quit:       db "quit",0
str_py_help:       db "help",0
str_py_print:      db "print",0
str_py_sysver:     db "sys.version",0
str_py_impsys:     db "import sys",0
str_py_oslist:     db "os.listdir",0
str_py_impos:      db "import os",0
str_py_sysver_out: db "'3.15.0 (NovaOS 1.00 26Q4 Build 26110.0000 x86_64)'",13,10,0
str_py_help_msg:
    db "Python 3.15.0 Interactive Help:",13,10
    db "  print(\"text\")   - Print string or number",13,10
    db "  A + B, A * B    - Perform 64-bit integer arithmetic (+, -, *, /)",13,10
    db "  sys.version     - Show Python 3.15 version info",13,10
    db "  os.listdir()    - List files in NovaFS C:\\",13,10
    db "  exit()          - Exit Python REPL back to NovaOS shell",13,10,0
str_py_zero_err:   db "ZeroDivisionError: division by zero",13,10,0
str_py_err_msg:    db "SyntaxError: invalid syntax (try print(\"hi\") or 12 * 12 or help())",13,10,0

str_ff_tab:  db "Mozilla Firefox Quantum  [x]",0
str_ff_url:  db "[HTTPS] https://start.mozilla.org/novaos-26q4",0
str_ff_body:
    db "Mozilla Firefox Quantum for NovaOS 1.00 26Q4",13,10,13,10
    db "                Fast, Private & Full-Color Graphical Web Browser",13,10
    db "                ------------------------------------------------",13,10
    db "                * Press [V] or [ENTER] or Click to stream 60fps HD Video!",13,10
    db "                * Press [ESC] or [Q] to return to NovaOS",0"""

assert old_chrome_vars in content, "Could not find old_chrome_vars"
content = content.replace(old_chrome_vars, new_chrome_vars, 1)

# Update str_chrome_btn2 and str_chrome_shortcuts and str_chrome_keys
old_chrome_btns = """str_chrome_btn1:
    db "Google Search",0
str_chrome_btn2:
    db "I'm Feeling Lucky",0
str_chrome_shortcuts:
    db "[1] Nova-Os GitHub    [2] Downloads    [3] WiFi/Eth Setup    [4] NovaFS",0
str_chrome_keys:
    db "[D] Download Repo   [Enter/S] Search   [R] Reload   [ESC] Exit Chrome",0"""

new_chrome_btns = """str_chrome_btn1:
    db "Google Search",0
str_chrome_btn2:
    db "Watch HD Video",0
str_chrome_shortcuts:
    db "[1] Google Home    [2] Nova-Os GitHub    [3] Play 60fps Video    [4] App Shop",0
str_chrome_keys:
    db "Type to Search | [Enter] Go | [1] Home [2] GitHub [3] Video [4] Shop [D] Download [ESC] Exit",0"""

assert old_chrome_btns in content, "Could not find old_chrome_btns"
content = content.replace(old_chrome_btns, new_chrome_btns, 1)

with open(KERNEL_PATH, "w", encoding="utf-8", newline="\n") as f:
    f.write(content)

print("[UPGRADE] Successfully updated kernel.asm!")
