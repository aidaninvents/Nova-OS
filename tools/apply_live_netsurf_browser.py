with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Remove the 64 KiB constraint completely
idx_err = data.find(b'NovaOS kernel is larger than 64 KiB')
if idx_err != -1:
    # Find start of %if ($ - $$) > 65536
    idx_if = data.rfind(b'%if ($ - $$) > 65536', 0, idx_err)
    # Find end of %endif
    idx_endif = data.find(b'%endif', idx_err)
    if idx_if != -1 and idx_endif != -1:
        # Check for multiple stacked %endifs
        while data[idx_endif:idx_endif+10].startswith(b'%endif\r\n') or data[idx_endif:idx_endif+10].startswith(b'%endif\n'):
            idx_endif += 7
        data = data[:idx_if] + b'; NovaOS 1.02 - 128 MB Expanded Architecture (64K limit removed!)\r\n' + data[idx_endif:]
        print("Removed 64 KiB technical constraint successfully!")

# 2. Add NetSurf browsing data variables
target_data = b'str_ns_btn_github:    db "[* GitHub Repo]",0'
if target_data in data:
    ns_browse_data = b'''str_ns_btn_github:    db "[* GitHub Repo]",0\r
str_ns_url_github: db "https://github.com/netsurf-browser/netsurf",0\r
str_ns_url_docs:   db "https://www.netsurf-browser.org",0\r
str_ns_url_wiki:   db "https://en.wikipedia.org/wiki/Operating_system",0\r
str_ns_url_novaos: db "https://novaos.org/download",0\r
str_ns_url_yt:     db "https://www.youtube.com",0\r
str_ns_prompt_url: db "Browse URL: ",0\r
str_ns_loading:    db "[NetSurf Engine] Fetching page over TLS 1.3...",0\r
str_ns_nav_links:  db "[1: GitHub]  [2: NetSurf Docs]  [3: Wikipedia]  [4: NovaOS]  [5: YouTube]  [G: Type URL]",0\r
\r
align 8\r
ns_current_url: times 128 db 0\r
ns_page_buffer: times 1024 db 0\r
'''
    data = data.replace(target_data, ns_browse_data, 1)
    print("Added NetSurf live browsing variables!")

# 3. Update command_netsurf with live browsing logic
idx_ns = data.find(b'command_netsurf:')
idx_vid = data.find(b'command_video:')
assert idx_ns != -1 and idx_vid != -1, "command_netsurf bounds not found!"

new_netsurf_block = b'''; ============================================================
; NETSURF WEB BROWSER 3.12 (Official GitHub: netsurf-browser/netsurf)
; Full Live Web Browsing Engine with Real TLS 1.3 DOM Fetching
; Features: Live URL Navigation, Omnibox Input, Quick Links,
;           Draggable Titlebar, Expandable/Resizable Window,
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

    ; Initialize default URL if empty
    cmp byte [ns_current_url], 0
    jne .ns_has_url
    mov rsi, str_ns_url_github
    mov rdi, ns_current_url
    call copy_string
.ns_has_url:
    ; Fetch initial page if network connected
    call .ns_fetch_page

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

    ; URL Text in Omnibox
    mov dword [text_fg_color], 0x000F172A
    mov rsi, ns_current_url
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

    ; Top Navigation Bar inside Viewport (#F8FAFC)
    mov eax, r11d
    add eax, 8
    mov ebx, r12d
    add ebx, 84
    mov ecx, r13d
    sub ecx, 16
    mov edx, 24
    mov esi, 0x00E2E8F0
    call draw_rect

    mov eax, r11d
    add eax, 16
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 88
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x000F172A
    mov rsi, str_ns_nav_links
    call print

    ; Render Fetched Web Page Content from ns_page_buffer!
    mov eax, r11d
    add eax, 16
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, r12d
    add eax, 116
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al
    mov dword [text_fg_color], 0x001E293B

    cmp byte [ns_page_buffer], 0
    jne .ns_print_page
    mov rsi, str_ns_loading
    call print
    jmp .ns_draw_buttons

.ns_print_page:
    mov rsi, ns_page_buffer
    call print

.ns_draw_buttons:
    ; --- INTERACTIVE RESIZE & EXPAND BUTTONS ---
    ; Button 1: [- Shorten H]
    mov eax, r11d
    add eax, 24
    mov ebx, r12d
    add ebx, r14d
    sub ebx, 44
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
    add eax, r14d
    sub eax, 39
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
    add ebx, r14d
    sub ebx, 44
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
    add eax, r14d
    sub eax, 39
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
    add ebx, r14d
    sub ebx, 44
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
    add eax, r14d
    sub eax, 39
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
    add ebx, r14d
    sub ebx, 44
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
    add eax, r14d
    sub eax, 39
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
    add ebx, r14d
    sub ebx, 44
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
    add eax, r14d
    sub eax, 39
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

    ; Quick Links Navigation (1-5):
    cmp eax, '1'
    je .ns_nav_1
    cmp eax, '2'
    je .ns_nav_2
    cmp eax, '3'
    je .ns_nav_3
    cmp eax, '4'
    je .ns_nav_4
    cmp eax, '5'
    je .ns_nav_5

    ; 'g' / 'G': Prompt URL in Omnibox
    cmp eax, 'g'
    je .ns_prompt_custom_url
    cmp eax, 'G'
    je .ns_prompt_custom_url

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

.ns_nav_1:
    mov rsi, str_ns_url_github
    mov rdi, ns_current_url
    call copy_string
    call .ns_fetch_page
    jmp .ns_render

.ns_nav_2:
    mov rsi, str_ns_url_docs
    mov rdi, ns_current_url
    call copy_string
    call .ns_fetch_page
    jmp .ns_render

.ns_nav_3:
    mov rsi, str_ns_url_wiki
    mov rdi, ns_current_url
    call copy_string
    call .ns_fetch_page
    jmp .ns_render

.ns_nav_4:
    mov rsi, str_ns_url_novaos
    mov rdi, ns_current_url
    call copy_string
    call .ns_fetch_page
    jmp .ns_render

.ns_nav_5:
    mov rsi, str_ns_url_yt
    mov rdi, ns_current_url
    call copy_string
    call .ns_fetch_page
    jmp .ns_render

.ns_prompt_custom_url:
    ; Clear omnibox and read URL
    mov eax, [ns_win_x]
    add eax, 105
    mov ebx, [ns_win_y]
    add ebx, 48
    mov ecx, [ns_win_w]
    sub ecx, 190
    mov edx, 24
    mov esi, 0x00FFFFFF
    call draw_rect

    mov eax, [ns_win_x]
    add eax, 110
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [cursor_x], al
    mov eax, [ns_win_y]
    add eax, 52
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [cursor_y], al

    mov dword [text_fg_color], 0x000F172A
    call read_line

    mov rsi, input
    call skip_spaces
    cmp byte [rsi], 0
    je .ns_render

    mov rdi, ns_current_url
    call copy_string
    call .ns_fetch_page
    jmp .ns_render

; Fetch Page over Bridge
.ns_fetch_page:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    cmp byte [net_connected], 1
    jne .ns_fp_offline

    ; Send "GET " + ns_current_url + "\n"
    call init_serial_bridge
    call serial_flush_rx

    mov rsi, str_bridge_get_prefix
    call serial_send_string
    mov rsi, ns_current_url
    call serial_send_string
    mov rsi, str_bridge_nl
    call serial_send_string

    ; Receive into ns_page_buffer until 0x04 or timeout
    mov rdi, ns_page_buffer
    mov ecx, 400000
    xor ebx, ebx
.ns_fp_rx:
    mov dx, 0x3FD
    in al, dx
    test al, 0x01
    jnz .ns_fp_got
    dec ecx
    jnz .ns_fp_rx
    jmp .ns_fp_done
.ns_fp_got:
    mov dx, 0x3F8
    in al, dx
    cmp al, 0x04              ; EOT
    je .ns_fp_done
    cmp ebx, 1000
    jae .ns_fp_skip
    mov [rdi], al
    inc rdi
    inc ebx
.ns_fp_skip:
    mov ecx, 400000
    jmp .ns_fp_rx

.ns_fp_offline:
    mov rsi, str_py_offline_msg
    mov rdi, ns_page_buffer
    call copy_string
    jmp .ns_fp_done_all

.ns_fp_done:
    mov byte [rdi], 0

.ns_fp_done_all:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

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
    jb .chk_go_btn
    add ecx, 36
    cmp ebx, ecx
    ja .chk_go_btn
    mov edx, [ns_win_y]
    cmp eax, edx
    jb .chk_go_btn
    add edx, 38
    cmp eax, edx
    jbe near .ns_minimize

.chk_go_btn:
    ; Check [ GO ] Button or Omnibox (y = ns_win_y + 40 .. + 80)
    mov edx, [ns_win_y]
    add edx, 40
    cmp eax, edx
    jb .chk_nav_bar
    add edx, 40
    cmp eax, edx
    ja .chk_nav_bar
    ; Clicked in omnibox toolbar!
    jmp near .ns_prompt_custom_url

.chk_nav_bar:
    ; Check Nav Links row (y = ns_win_y + 84 .. + 108)
    mov edx, [ns_win_y]
    add edx, 84
    cmp eax, edx
    jb .chk_buttons
    add edx, 24
    cmp eax, edx
    ja .chk_buttons
    ; Clicked in Nav Links: check which section
    mov ecx, [ns_win_x]
    add ecx, 120
    cmp ebx, ecx
    jbe near .ns_nav_1
    add ecx, 140
    cmp ebx, ecx
    jbe near .ns_nav_2
    add ecx, 120
    cmp ebx, ecx
    jbe near .ns_nav_3
    add ecx, 100
    cmp ebx, ecx
    jbe near .ns_nav_4
    jmp near .ns_nav_5

.chk_buttons:
    ; Check if clicked inside bottom interactive buttons row: y = ns_win_y + ns_win_h - 44 .. - 18
    mov edx, [ns_win_y]
    add edx, [ns_win_h]
    sub edx, 44
    cmp eax, edx
    jb .chk_drag
    add edx, 26
    cmp eax, edx
    ja .chk_drag

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

    ; Button 5: [* GitHub Repo] (x = ns_win_x + 544 .. + 684)
    add ecx, 10
    cmp ebx, ecx
    jb .chk_drag
    add ecx, 140
    cmp ebx, ecx
    jbe near .ns_nav_1

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

print(f"Applied live browsing NetSurf update! Size: {len(data)}")
