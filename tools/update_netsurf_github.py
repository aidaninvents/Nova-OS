with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Update NetSurf Strings
old_strings = b'''str_ns_title: db "NetSurf Web Browser 3.11",0\r
str_ns_badge: db "TLS 1.3",0\r
str_ns_default_url: db "https://www.netsurf-browser.org",0\r
str_ns_page_header: db "NetSurf 3.11 for NovaOS 1.02 (CSS3 & DOM Engine)",0\r
str_ns_page_body1:  db "Lightweight multi-platform C browser with draggable & resizable window manager.",0\r
str_ns_page_body2:  db "Features: Pull-up bottom grip resize, min/max/restore, and fast HTML rendering.",0'''

if old_strings not in data:
    # check LF version
    old_strings = old_strings.replace(b'\r\n', b'\n')

new_strings = b'''str_ns_title: db "NetSurf 3.12 (GitHub: netsurf-browser/netsurf)",0\r
str_ns_badge: db "TLS 1.3",0\r
str_ns_default_url: db "https://github.com/netsurf-browser/netsurf",0\r
str_ns_page_header: db "NetSurf 3.12 Dev [Git: d06cd9d] (Hubbub + LibDOM + LibCSS Engine)",0\r
str_ns_page_body1:  db "Official NetSurf C Browser from GitHub! Frontends: Framebuffer /dev/fb0, GTK.",0\r
str_ns_page_body2:  db "Features: CSS3, HTML5 Canvas, DOM Tree, Duktape JS, and LibCURL HTTP/HTTPS.",0\r
str_ns_btn_shorten_h: db "[- Shorten H]",0\r
str_ns_btn_expand_h:  db "[+ Expand H]",0\r
str_ns_btn_narrow_w:  db "[< Narrow W]",0\r
str_ns_btn_expand_w:  db "[> Expand W]",0\r
str_ns_btn_github:    db "[* GitHub Repo]",0'''

assert old_strings in data, "old_strings not found!"
data = data.replace(old_strings, new_strings, 1)

# 2. Update command_netsurf to render the interactive expand/shorten buttons and handle their clicks
idx_ns = data.find(b'command_netsurf:')
idx_vid = data.find(b'command_video:')
assert idx_ns != -1 and idx_vid != -1, "command_netsurf boundaries not found!"

new_netsurf_block = b'''; ============================================================
; NETSURF WEB BROWSER 3.12 (Official GitHub: netsurf-browser/netsurf)
; Features: Draggable Titlebar, Expandable/Resizable Window,
;           [- Shorten H] [+ Expand H] [< Narrow W] [> Expand W],
;           Minimize (-), Maximize/Restore ([ ]), Close (X)
; ============================================================
command_netsurf:
    push r11
    push r12
    push r13
    push r14
    push r15

    mov byte [ns_win_state], 1         ; 1 = Windowed
    mov dword [ns_win_x], 60
    mov dword [ns_win_y], 40
    mov dword [ns_win_w], 904
    mov dword [ns_win_h], 640

.ns_render:
    call clear_screen

    cmp byte [ns_win_state], 0
    je near .ns_minimized_desktop

    mov r11d, [ns_win_x]
    mov r12d, [ns_win_y]
    mov r13d, [ns_win_w]
    mov r14d, [ns_win_h]

    ; 1. Window Frame (#1E293B)
    mov eax, r11d
    mov ebx, r12d
    mov ecx, r13d
    mov edx, r14d
    mov esi, 0x001E293B
    call draw_rect

    ; 2. NetSurf Teal Title Bar (#0F766E)
    mov eax, r11d
    mov ebx, r12d
    mov ecx, r13d
    mov edx, 38
    mov esi, 0x000F766E
    call draw_rect

    ; Emerald Accent Line (#10B981)
    mov eax, r11d
    mov ebx, r12d
    add ebx, 38
    mov ecx, r13d
    mov edx, 2
    mov esi, 0x0010B981
    call draw_rect

    ; Green Leaf Logo in tab
    mov eax, r11d
    add eax, 12
    mov ebx, r12d
    add ebx, 10
    mov ecx, 16
    mov edx, 16
    mov esi, 0x0022C55E
    call draw_rect

    ; NetSurf Title Text
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov eax, r11d
    add eax, 36
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 10
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov rsi, str_ns_title
    call print

    ; Close Button [ X ] at right edge (#EF4444)
    mov eax, r11d
    add eax, r13d
    sub eax, 36
    mov ebx, r12d
    mov ecx, 36
    mov edx, 38
    mov esi, 0x00EF4444
    call draw_rect

    mov eax, r11d
    add eax, r13d
    sub eax, 24
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 10
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_win_btn_x
    call print

    ; Maximize / Restore Button [ ]
    mov eax, r11d
    add eax, r13d
    sub eax, 72
    mov ebx, r12d
    mov ecx, 36
    mov edx, 38
    mov esi, 0x00115E59
    call draw_rect

    mov eax, r11d
    add eax, r13d
    sub eax, 66
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 10
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00E2E8F0
    cmp byte [ns_win_state], 2
    je .ns_show_res
    mov rsi, str_win_btn_max
    call print
    jmp .ns_draw_min
.ns_show_res:
    mov rsi, str_win_btn_res
    call print

.ns_draw_min:
    ; Minimize Button [ - ]
    mov eax, r11d
    add eax, r13d
    sub eax, 108
    mov ebx, r12d
    mov ecx, 36
    mov edx, 38
    mov esi, 0x00134E4A
    call draw_rect

    mov eax, r11d
    add eax, r13d
    sub eax, 96
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 10
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00E2E8F0
    mov rsi, str_win_btn_min
    call print

    ; 4. Omnibox Toolbar
    mov eax, r11d
    mov ebx, r12d
    add ebx, 40
    mov ecx, r13d
    mov edx, 40
    mov esi, 0x00F1F5F9
    call draw_rect

    mov eax, r11d
    add eax, 12
    mov ebx, r12d
    add ebx, 46
    mov ecx, r13d
    sub ecx, 100
    mov edx, 28
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Green TLS Badge
    mov eax, r11d
    add eax, 15
    mov ebx, r12d
    add ebx, 48
    mov ecx, 85
    mov edx, 24
    mov esi, 0x00059669
    call draw_rect

    mov eax, r11d
    add eax, 20
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 52
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_ns_badge
    call print

    ; URL Text
    mov dword [text_fg_color], 0x000F172A
    mov rsi, str_ns_default_url
    call print

    ; Blue [ GO ] Button
    mov eax, r11d
    add eax, r13d
    sub eax, 78
    mov ebx, r12d
    add ebx, 46
    mov ecx, 66
    mov edx, 28
    mov esi, 0x000284C7
    call draw_rect
    mov eax, r11d
    add eax, r13d
    sub eax, 64
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_chrome_go_btn
    call print

    ; 5. Content Viewport
    mov eax, r11d
    mov ebx, r12d
    add ebx, 80
    mov ecx, r13d
    mov edx, r14d
    sub edx, 88
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Text Line 1: Header
    mov eax, r11d
    add eax, 24
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 96
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x000F766E
    mov rsi, str_ns_page_header
    call print

    ; Text Line 2: Body 1
    mov eax, r11d
    add eax, 24
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 126
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00334155
    mov rsi, str_ns_page_body1
    call print

    ; Text Line 3: Body 2
    mov eax, r11d
    add eax, 24
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 156
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov rsi, str_ns_page_body2
    call print

    ; --- INTERACTIVE RESIZE & EXPAND BUTTONS ---
    ; Button 1: [- Shorten H]
    mov eax, r11d
    add eax, 24
    mov ebx, r12d
    add ebx, 190
    mov ecx, 120
    mov edx, 26
    mov esi, 0x00475569
    call draw_rect

    mov eax, r11d
    add eax, 30
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 195
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_ns_btn_shorten_h
    call print

    ; Button 2: [+ Expand H]
    mov eax, r11d
    add eax, 154
    mov ebx, r12d
    add ebx, 190
    mov ecx, 120
    mov edx, 26
    mov esi, 0x00059669
    call draw_rect

    mov eax, r11d
    add eax, 160
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 195
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_ns_btn_expand_h
    call print

    ; Button 3: [< Narrow W]
    mov eax, r11d
    add eax, 284
    mov ebx, r12d
    add ebx, 190
    mov ecx, 120
    mov edx, 26
    mov esi, 0x00475569
    call draw_rect

    mov eax, r11d
    add eax, 290
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 195
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_ns_btn_narrow_w
    call print

    ; Button 4: [> Expand W]
    mov eax, r11d
    add eax, 414
    mov ebx, r12d
    add ebx, 190
    mov ecx, 120
    mov edx, 26
    mov esi, 0x000284C7
    call draw_rect

    mov eax, r11d
    add eax, 420
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 195
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_ns_btn_expand_w
    call print

    ; Button 5: [* GitHub Repo]
    mov eax, r11d
    add eax, 544
    mov ebx, r12d
    add ebx, 190
    mov ecx, 140
    mov edx, 26
    mov esi, 0x007C3AED
    call draw_rect

    mov eax, r11d
    add eax, 550
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 195
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_ns_btn_github
    call print

    ; 6. Resizable Bottom Border & Bottom-Right Resize Grip Handle!
    mov eax, r11d
    mov ebx, r12d
    add ebx, r14d
    sub ebx, 8
    mov ecx, r13d
    mov edx, 8
    mov esi, 0x0064748B
    call draw_rect

    ; Amber Resize Grip Handle
    mov eax, r11d
    add eax, r13d
    sub eax, 18
    mov ebx, r12d
    add ebx, r14d
    sub ebx, 18
    mov ecx, 18
    mov edx, 18
    mov esi, 0x00F59E0B
    call draw_rect

    ; Diagonal lines
    mov eax, r11d
    add eax, r13d
    sub eax, 14
    mov ebx, r12d
    add ebx, r14d
    sub ebx, 6
    mov ecx, 10
    mov edx, 2
    mov esi, 0x00FFFFFF
    call draw_rect

    ; 7. Desktop Taskbar
    call draw_desktop_taskbar_state

    call draw_mouse_cursor

.ns_event_loop:
    call get_key

    cmp eax, KEY_MOUSE_MOVE
    je .ns_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je near .ns_mouse_click

    cmp eax, KEY_UP
    je .ns_key_up
    cmp eax, KEY_DOWN
    je .ns_key_down
    cmp eax, KEY_LEFT
    je .ns_key_left
    cmp eax, KEY_RIGHT
    je .ns_key_right

    cmp eax, 27
    je near .ns_close
    cmp eax, 'q'
    je near .ns_close
    cmp eax, 'Q'
    je near .ns_close

    cmp eax, 'm'
    je near .ns_minimize
    cmp eax, 'M'
    je near .ns_minimize
    cmp eax, 'x'
    je near .ns_toggle_maximize
    cmp eax, 'X'
    je near .ns_toggle_maximize

    ; Pull-up/pull-down/expand resize keys:
    cmp eax, '-'
    je .ns_pull_up_shorten
    cmp eax, '_'
    je .ns_pull_up_shorten
    cmp eax, '+'
    je .ns_pull_down_lengthen
    cmp eax, '='
    je .ns_pull_down_lengthen
    cmp eax, '['
    je .ns_pull_left_shorten
    cmp eax, ']'
    je .ns_pull_right_lengthen

    jmp .ns_event_loop

.ns_pull_up_shorten:
    cmp dword [ns_win_h], 320
    jbe .ns_event_loop
    sub dword [ns_win_h], 40
    jmp .ns_render

.ns_pull_down_lengthen:
    cmp dword [ns_win_h], 680
    jae .ns_event_loop
    add dword [ns_win_h], 40
    jmp .ns_render

.ns_pull_left_shorten:
    cmp dword [ns_win_w], 500
    jbe .ns_event_loop
    sub dword [ns_win_w], 40
    jmp .ns_render

.ns_pull_right_lengthen:
    cmp dword [ns_win_w], 980
    jae .ns_event_loop
    add dword [ns_win_w], 40
    jmp .ns_render

.ns_key_up:
    cmp byte [ns_is_dragging], 1
    jne .ns_up_norm
    cmp dword [ns_win_y], 20
    jbe .ns_event_loop
    sub dword [ns_win_y], 20
    jmp .ns_render
.ns_up_norm:
    cmp dword [mouse_y], 20
    jb .ns_mouse_move
    sub dword [mouse_y], 20
    jmp .ns_mouse_move

.ns_key_down:
    cmp byte [ns_is_dragging], 1
    jne .ns_dn_norm
    cmp dword [ns_win_y], 400
    jae .ns_event_loop
    add dword [ns_win_y], 20
    jmp .ns_render
.ns_dn_norm:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .ns_mouse_move
    add dword [mouse_y], 20
    jmp .ns_mouse_move

.ns_key_left:
    cmp byte [ns_is_dragging], 1
    jne .ns_lt_norm
    cmp dword [ns_win_x], 20
    jbe .ns_event_loop
    sub dword [ns_win_x], 20
    jmp .ns_render
.ns_lt_norm:
    cmp dword [mouse_x], 20
    jb .ns_mouse_move
    sub dword [mouse_x], 20
    jmp .ns_mouse_move

.ns_key_right:
    cmp byte [ns_is_dragging], 1
    jne .ns_rt_norm
    cmp dword [ns_win_x], 400
    jae .ns_event_loop
    add dword [ns_win_x], 20
    jmp .ns_render
.ns_rt_norm:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .ns_mouse_move
    add dword [mouse_x], 20
    jmp .ns_mouse_move

.ns_mouse_move:
    call draw_mouse_cursor
    jmp .ns_event_loop

.ns_mouse_click:
    call draw_mouse_cursor
    mov eax, [mouse_y]
    mov ebx, [mouse_x]

    cmp eax, 728
    jae near .ns_taskbar_click

    cmp byte [ns_win_state], 0
    je near .ns_event_loop

    ; Close [ X ]
    mov ecx, [ns_win_x]
    add ecx, [ns_win_w]
    sub ecx, 36
    cmp ebx, ecx
    jb .chk_max
    mov edx, [ns_win_y]
    cmp eax, edx
    jb .chk_max
    add edx, 38
    cmp eax, edx
    jbe near .ns_close

.chk_max:
    ; Maximize / Restore [ ]
    mov ecx, [ns_win_x]
    add ecx, [ns_win_w]
    sub ecx, 72
    cmp ebx, ecx
    jb .chk_min
    add ecx, 36
    cmp ebx, ecx
    ja .chk_min
    mov edx, [ns_win_y]
    cmp eax, edx
    jb .chk_min
    add edx, 38
    cmp eax, edx
    jbe near .ns_toggle_maximize

.chk_min:
    ; Minimize [ - ]
    mov ecx, [ns_win_x]
    add ecx, [ns_win_w]
    sub ecx, 108
    cmp ebx, ecx
    jb .chk_buttons
    add ecx, 36
    cmp ebx, ecx
    ja .chk_buttons
    mov edx, [ns_win_y]
    cmp eax, edx
    jb .chk_buttons
    add edx, 38
    cmp eax, edx
    jbe near .ns_minimize

.chk_buttons:
    ; Check if clicked inside the interactive buttons row: y = ns_win_y + 190 .. + 216
    mov edx, [ns_win_y]
    add edx, 190
    cmp eax, edx
    jb .chk_drag
    add edx, 26
    cmp eax, edx
    ja .chk_drag

    ; Inside button row!
    ; Button 1: [- Shorten H] (x = ns_win_x + 24 .. + 144)
    mov ecx, [ns_win_x]
    add ecx, 24
    cmp ebx, ecx
    jb .chk_drag
    add ecx, 120
    cmp ebx, ecx
    jbe near .ns_pull_up_shorten

    ; Button 2: [+ Expand H] (x = ns_win_x + 154 .. + 274)
    add ecx, 10
    cmp ebx, ecx
    jb .chk_drag
    add ecx, 120
    cmp ebx, ecx
    jbe near .ns_pull_down_lengthen

    ; Button 3: [< Narrow W] (x = ns_win_x + 284 .. + 404)
    add ecx, 10
    cmp ebx, ecx
    jb .chk_drag
    add ecx, 120
    cmp ebx, ecx
    jbe near .ns_pull_left_shorten

    ; Button 4: [> Expand W] (x = ns_win_x + 414 .. + 534)
    add ecx, 10
    cmp ebx, ecx
    jb .chk_drag
    add ecx, 120
    cmp ebx, ecx
    jbe near .ns_pull_right_lengthen

.chk_drag:
    ; Titlebar Drag
    mov ecx, [ns_win_x]
    cmp ebx, ecx
    jb .chk_grip
    add ecx, [ns_win_w]
    sub ecx, 110
    cmp ebx, ecx
    ja .chk_grip
    mov edx, [ns_win_y]
    cmp eax, edx
    jb .chk_grip
    add edx, 38
    cmp eax, edx
    ja .chk_grip
    ; Drag titlebar: reposition window
    mov edx, [mouse_x]
    sub edx, 200
    test edx, edx
    js .d_x0
    mov [ns_win_x], edx
    jmp .d_y
.d_x0:
    mov dword [ns_win_x], 0
.d_y:
    mov edx, [mouse_y]
    sub edx, 18
    test edx, edx
    js .d_y0
    mov [ns_win_y], edx
    jmp near .ns_render
.d_y0:
    mov dword [ns_win_y], 0
    jmp near .ns_render

.chk_grip:
    ; Bottom-Right Corner Resize Grip Handle
    mov edx, [ns_win_y]
    add edx, [ns_win_h]
    sub edx, 28
    cmp eax, edx
    jb .chk_done
    mov edx, [mouse_y]
    sub edx, [ns_win_y]
    cmp edx, 240
    jl near .ns_render
    cmp edx, 680
    jg near .ns_render
    mov [ns_win_h], edx
    mov ecx, [mouse_x]
    sub ecx, [ns_win_x]
    cmp ecx, 400
    jl near .ns_render
    cmp ecx, 1000
    jg near .ns_render
    mov [ns_win_w], ecx
    jmp near .ns_render

.chk_done:
    jmp near .ns_event_loop

.ns_toggle_maximize:
    cmp byte [ns_win_state], 2
    je .ns_restore
    mov eax, [ns_win_x]
    mov [ns_saved_x], eax
    mov eax, [ns_win_y]
    mov [ns_saved_y], eax
    mov eax, [ns_win_w]
    mov [ns_saved_w], eax
    mov eax, [ns_win_h]
    mov [ns_saved_h], eax
    mov dword [ns_win_x], 0
    mov dword [ns_win_y], 0
    mov dword [ns_win_w], 1024
    mov dword [ns_win_h], 728
    mov byte [ns_win_state], 2
    jmp near .ns_render

.ns_restore:
    mov eax, [ns_saved_x]
    mov [ns_win_x], eax
    mov eax, [ns_saved_y]
    mov [ns_win_y], eax
    mov eax, [ns_saved_w]
    mov [ns_win_w], eax
    mov eax, [ns_saved_h]
    mov [ns_win_h], eax
    mov byte [ns_win_state], 1
    jmp near .ns_render

.ns_minimize:
    mov byte [ns_win_state], 0
    jmp near .ns_render

.ns_minimized_desktop:
    call draw_desktop_taskbar_state
    call draw_mouse_cursor
.ns_min_loop:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    je .ns_min_move
    cmp eax, KEY_MOUSE_CLICK
    je .ns_min_click
    cmp eax, 27
    je .ns_close
    cmp eax, 'q'
    je .ns_close
    cmp eax, 'm'
    je .ns_restore
    cmp eax, 'M'
    je .ns_restore
    jmp .ns_min_loop

.ns_min_move:
    call draw_mouse_cursor
    jmp .ns_min_loop

.ns_min_click:
    mov eax, [mouse_y]
    cmp eax, 728
    jae .ns_restore
    jmp .ns_min_loop

.ns_taskbar_click:
    cmp byte [ns_win_state], 0
    je .ns_restore
    jmp .ns_minimize

.ns_close:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell

; Desktop Taskbar Status Bar
draw_desktop_taskbar_state:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    mov eax, 0
    mov ebx, 728
    mov ecx, [screen_width]
    mov edx, 40
    mov esi, 0x000F172A
    call draw_rect

    mov eax, 0
    mov ebx, 728
    mov ecx, [screen_width]
    mov edx, 2
    mov esi, 0x0038BDF8
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 2
    mov byte [cursor_y], 46
    mov rsi, str_taskbar_items_102
    call print
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

'''

data = data[:idx_ns] + new_netsurf_block + data[idx_vid:]

with open("kernel.asm", "wb") as f:
    f.write(data)

print(f"Applied NetSurf GitHub update & Expand/Resize controls! Size: {len(data)}")
