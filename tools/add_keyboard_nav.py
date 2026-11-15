from pathlib import Path

kpath = Path("NovaOS_fixed/kernel.asm")
content = kpath.read_text(encoding="utf-8")

# ── 1. Add extended scancode (E0 prefix) detection to get_key ────────────
# Insert after the Escape handler and before the normal key lookup
old_get_key_normal = """    movzx eax, al

    cmp eax, 128
    jae get_key

    cmp byte [shift], 0
    je get_key_normal

    mov al, [shift_table + rax]

    jmp get_key_character


get_key_normal:

    mov al, [key_table + rax]"""

new_get_key_normal = """    ; Check for E0 extended prefix (arrow keys, PgUp, PgDn, Home, End, Ins, Del)
    cmp al, 0xE0
    je get_key_extended

    movzx eax, al

    cmp eax, 128
    jae get_key

    cmp byte [shift], 0
    je get_key_normal

    mov al, [shift_table + rax]

    jmp get_key_character


get_key_normal:

    mov al, [key_table + rax]"""

if old_get_key_normal in content:
    content = content.replace(old_get_key_normal, new_get_key_normal)
    print("OK: Added E0 prefix detection")
else:
    print("SKIP: get_key_normal not found")

# ── 2. Add get_key_extended handler after get_key_escape ─────────────────
old_after_escape = """get_key_escape:

    mov eax, 27

    ret


; ============================================================
; INPUT"""

new_after_escape = """get_key_escape:

    mov eax, 27

    ret


get_key_extended:
    ; Read the actual extended key scancode
    ; Must wait for next byte from keyboard
.ext_wait:
    in al, KBD_STATUS
    test al, 1
    jz .ext_wait
    in al, KBD_DATA

    ; Arrow keys
    cmp al, 0x48   ; Up arrow
    je .ext_up
    cmp al, 0x50   ; Down arrow
    je .ext_down
    cmp al, 0x4B   ; Left arrow
    je .ext_left
    cmp al, 0x4D   ; Right arrow
    je .ext_right
    cmp al, 0x49   ; Page Up
    je .ext_pgup
    cmp al, 0x51   ; Page Down
    je .ext_pgdn
    cmp al, 0x47   ; Home
    je .ext_home
    cmp al, 0x4F   ; End
    je .ext_end
    cmp al, 0x53   ; Delete
    je .ext_del
    ; Ignore unknown extended
    jmp get_key

.ext_up:
    mov eax, KEY_UP
    ret
.ext_down:
    mov eax, KEY_DOWN
    ret
.ext_left:
    mov eax, KEY_LEFT
    ret
.ext_right:
    mov eax, KEY_RIGHT
    ret
.ext_pgup:
    mov eax, KEY_PGUP
    ret
.ext_pgdn:
    mov eax, KEY_PGDN
    ret
.ext_home:
    mov eax, KEY_HOME
    ret
.ext_end:
    mov eax, KEY_END
    ret
.ext_del:
    mov eax, KEY_DEL
    ret


; ============================================================
; INPUT"""

if old_after_escape in content:
    content = content.replace(old_after_escape, new_after_escape)
    print("OK: Added get_key_extended")
else:
    print("SKIP: escape handler not found")

# ── 3. Add key constants near the top (after COLOR defines) ─────────────
old_color_bg = "COLOR_BG        equ 0x00000000"
new_color_bg = """COLOR_BG        equ 0x00000000

; Extended key codes (virtual - returned by get_key)
KEY_UP          equ 0x80
KEY_DOWN        equ 0x81
KEY_LEFT        equ 0x82
KEY_RIGHT       equ 0x83
KEY_PGUP        equ 0x84
KEY_PGDN        equ 0x85
KEY_HOME        equ 0x86
KEY_END         equ 0x87
KEY_DEL         equ 0x88"""

if old_color_bg in content:
    content = content.replace(old_color_bg, new_color_bg)
    print("OK: Added KEY_ constants")
else:
    print("SKIP: COLOR_BG not found")

# ── 4. Replace command_files with full interactive arrow-key explorer ─────
old_files = """command_files:
    ; Draw Windows 10 style Graphical File Explorer window
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Explorer Window coordinates
    mov r14d, 60            ; win_x
    mov r15d, 70            ; win_y
    mov ecx, [screen_width]
    sub ecx, 120            ; win_w
    mov edx, [screen_height]
    sub edx, 180            ; win_h

    push rcx
    push rdx

    ; Window background
    mov eax, r14d
    mov ebx, r15d
    mov esi, 0x001F1F1F     ; Windows 10 Dark theme window bg
    call draw_rect

    ; Title Bar
    pop rdx
    pop rcx
    push rcx
    push rdx
    mov eax, r14d
    mov ebx, r15d
    mov edx, 36
    mov esi, 0x002D2D2D     ; Dark title bar
    call draw_rect

    ; Accent border line
    pop rdx
    pop rcx
    push rcx
    mov eax, r14d
    lea ebx, [r15d + 36]
    mov edx, 2
    mov esi, COLOR_ACCENT
    call draw_rect

    ; Address Bar background
    pop rcx
    mov eax, r14d
    add eax, 10
    lea ebx, [r15d + 44]
    sub ecx, 20
    mov edx, 28
    mov esi, 0x00141414     ; Address bar dark fill
    call draw_rect

    ; Text in File Explorer
    mov byte [cursor_x], 8
    mov byte [cursor_y], 4
    mov rsi, gui_explorer_title
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 6
    mov rsi, gui_address_path
    call print

    ; Folder Icons and Names
    mov byte [cursor_x], 7
    mov byte [cursor_y], 9
    mov rsi, gui_folder_1
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 11
    mov rsi, gui_folder_2
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 13
    mov rsi, gui_folder_3
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 15
    mov rsi, gui_folder_4
    call print

    ; Files list
    mov byte [cursor_x], 30
    mov byte [cursor_y], 9
    mov rsi, gui_file_1
    call print

    mov byte [cursor_x], 30
    mov byte [cursor_y], 11
    mov rsi, gui_file_2
    call print

    mov byte [cursor_x], 30
    mov byte [cursor_y], 13
    mov rsi, gui_file_3
    call print

    mov byte [cursor_x], 30
    mov byte [cursor_y], 15
    mov rsi, gui_file_4
    call print

    ; Status Bar
    mov byte [cursor_x], 7
    mov byte [cursor_y], 18
    mov rsi, gui_explorer_status
    call print

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11

    ; Restore shell cursor
    mov al, [term_bottom_row]
    dec al
    mov [cursor_y], al
    mov al, [term_left_col]
    mov [cursor_x], al

    jmp command_done"""

new_files = """command_files:
    ; Interactive File Explorer with arrow-key navigation
    push r11
    push r12
    push r13
    push r14
    push r15

    ; r12 = selected index (0-based)
    xor r12d, r12d
    ; r13 = total entries
    mov r13d, 8

.explorer_draw:
    ; ── Draw window frame ──────────────────────────────────────────────
    mov eax, 60
    mov ebx, 55
    mov ecx, [screen_width]
    sub ecx, 120
    mov edx, [screen_height]
    sub edx, 160
    push rcx
    push rdx
    mov esi, 0x00121212
    call draw_rect

    ; Title bar (36px)
    pop rdx
    pop rcx
    push rcx
    push rdx
    mov eax, 60
    mov ebx, 55
    mov edx, 36
    mov esi, 0x00003780
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
    mov ebx, 99
    sub ecx, 20
    mov edx, 24
    mov esi, 0x001A1A1A
    call draw_rect

    ; ── Title text ─────────────────────────────────────────────────────
    mov byte [cursor_x], 6
    mov byte [cursor_y], 3
    mov rsi, gui_explorer_title
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 6
    mov rsi, gui_address_path
    call print

    ; ── Column headers ─────────────────────────────────────────────────
    mov byte [cursor_x], 6
    mov byte [cursor_y], 8
    mov rsi, gui_col_header
    call print

    ; ── Draw all 8 entries, highlighting the selected one ──────────────
    xor r15d, r15d        ; entry index
.draw_entries:
    cmp r15d, r13d
    jge .draw_done_entries

    mov eax, r15d
    lea ebx, [eax + 9]    ; row = 9 + entry_index

    ; Highlight selected row
    cmp r15d, r12d
    jne .no_highlight

    mov byte [cursor_x], 6
    mov [cursor_y], bl
    mov rsi, gui_sel_arrow
    call print
    jmp .print_entry

.no_highlight:
    mov byte [cursor_x], 6
    mov [cursor_y], bl
    mov rsi, gui_no_arrow
    call print

.print_entry:
    mov [cursor_y], bl

    ; Fetch entry strings from table
    push r12
    push r15
    lea rax, [rel explorer_entry_table]
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
    mov byte [cursor_x], 6
    mov eax, [screen_height]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    sub eax, 6
    mov [cursor_y], al
    mov rsi, gui_explorer_keys
    call print

    ; ── Wait for keypress ──────────────────────────────────────────────
    call get_key

    cmp eax, KEY_UP
    je .move_up
    cmp eax, KEY_DOWN
    je .move_down
    cmp eax, 27           ; Escape -> close
    je .explorer_close
    cmp eax, 13           ; Enter -> "open" (just redraw for now)
    je .explorer_draw
    cmp eax, KEY_PGUP
    je .jump_top
    cmp eax, KEY_PGDN
    je .jump_bottom
    jmp .explorer_draw

.move_up:
    test r12d, r12d
    jz .explorer_draw
    dec r12d
    jmp .explorer_draw

.move_down:
    lea eax, [r12d + 1]
    cmp eax, r13d
    jge .explorer_draw
    inc r12d
    jmp .explorer_draw

.jump_top:
    xor r12d, r12d
    jmp .explorer_draw

.jump_bottom:
    lea r12d, [r13d - 1]
    jmp .explorer_draw

.explorer_close:
    pop rdx
    pop rcx
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11

    ; Redraw desktop (clear explorer window area)
    call gui_desktop

    jmp shell"""

if old_files in content:
    content = content.replace(old_files, new_files)
    print("OK: Replaced command_files with interactive explorer")
else:
    print("SKIP: command_files not found")

# ── 5. Add PgUp/PgDn scroll in read_line (shell input) ──────────────────
old_readline_enter = """    cmp al, 13
    je read_line_done

    cmp al, 8
    je read_line_backspace

    cmp al, 27
    je read_line_clear"""

new_readline_enter = """    cmp al, 13
    je read_line_done

    cmp al, 8
    je read_line_backspace

    cmp al, 27
    je read_line_clear

    ; PgUp - scroll terminal up (manual scroll back not buffered, just visual cue)
    cmp eax, KEY_PGUP
    je read_line_loop
    ; PgDn - scroll to bottom
    cmp eax, KEY_PGDN
    je read_line_loop"""

if old_readline_enter in content:
    content = content.replace(old_readline_enter, new_readline_enter)
    print("OK: Added PgUp/PgDn in read_line")
else:
    print("SKIP: read_line cmp al,13 not found")

kpath.write_text(content, encoding="utf-8")
print("Patched kernel.asm successfully")
