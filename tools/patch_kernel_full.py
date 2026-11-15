import sys
from pathlib import Path

kpath = Path("NovaOS_fixed/kernel.asm")
content = kpath.read_text(encoding="utf-8")

# 1. Update variables: add window terminal boundary variables
var_target = "term_top_row"
if var_target not in content:
    content = content.replace(
        "cursor_x db 0\ncursor_y db 0\ntext_cols db 80\ntext_rows db 25",
        "cursor_x db 0\ncursor_y db 0\ntext_cols db 80\ntext_rows db 25\nterm_top_row db 7\nterm_bottom_row db 35\nterm_left_col db 2\nterm_right_col db 78\nactive_app db 0"
    )

# 2. Update spinner animation pacing
# Change add edx, 2 -> inc edx, add rsi, SPINNER_FRAME_SIZE * 2 -> add rsi, SPINNER_FRAME_SIZE
old_anim = """; Step by 2 frames for smooth, fixed-duration boot (~1.2s total)
    add rsi, SPINNER_FRAME_SIZE * 2
    add edx, 2"""
new_anim = """; Windows 10 paced 60 FPS rotation (1 frame per tick)
    add rsi, SPINNER_FRAME_SIZE
    inc edx"""
if old_anim in content:
    content = content.replace(old_anim, new_anim)

# 3. Update spinner_delay
old_delay = """.do_delay:
    mov ecx, 15000
.wait_loop:
    pause
    dec ecx
    jnz .wait_loop"""
new_delay = """.do_delay:
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
if old_delay in content:
    content = content.replace(old_delay, new_delay)

# 4. Update gui_desktop cursor initialization to set term_left_col, term_top_row, term_bottom_row, term_right_col
old_gui_cursor = """    lea eax, [r15d + 40 + 3 + FONT_HEIGHT]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    mov [cursor_y], al

    mov eax, r14d
    add eax, FONT_WIDTH
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al"""

new_gui_cursor = """    lea eax, [r15d + 40 + 3 + FONT_HEIGHT]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    mov [cursor_y], al
    mov [term_top_row], al

    mov eax, r14d
    add eax, FONT_WIDTH
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov [term_left_col], al

    ; term_bottom_row = (taskbar_y - 8) / FONT_HEIGHT
    mov eax, r13d
    sub eax, 8
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    mov [term_bottom_row], al

    ; term_right_col = (win_x + win_w - FONT_WIDTH) / FONT_WIDTH
    mov eax, r14d
    add eax, r8d
    sub eax, FONT_WIDTH
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [term_right_col], al"""
if old_gui_cursor in content:
    content = content.replace(old_gui_cursor, new_gui_cursor)

# 5. Update putchar_newline and putchar_backspace
old_nl = """putchar_newline:

    mov byte [cursor_x], 0

    inc byte [cursor_y]

    call scroll"""
new_nl = """putchar_newline:

    mov al, [term_left_col]
    mov [cursor_x], al

    inc byte [cursor_y]

    call scroll"""
if old_nl in content:
    content = content.replace(old_nl, new_nl)

# 6. Update scroll function for windowed terminal
old_scroll = """scroll:

    mov al, [text_rows]
    cmp byte [cursor_y], al
    jb scroll_done

    push rax
    push rbx
    push rcx
    push rsi
    push rdi

    mov rsi, [framebuffer_address]
    mov rdi, [framebuffer_address]

    mov eax, [framebuffer_pitch]

    imul eax, FONT_HEIGHT

    add rsi, rax

    mov eax, [framebuffer_pitch]

    mov ebx, [screen_height]

    sub ebx, FONT_HEIGHT

    imul eax, ebx

    mov ecx, eax

    rep movsb

    ; ------------------------------------------------------------
    ; Clear bottom line.
    ; ------------------------------------------------------------

    mov rdi, [framebuffer_address]

    mov eax, [framebuffer_pitch]

    mov ebx, [screen_height]

    sub ebx, FONT_HEIGHT

    imul eax, ebx

    add rdi, rax

    mov eax, [framebuffer_pitch]

    imul eax, FONT_HEIGHT

    mov ecx, eax

    xor eax, eax

    rep stosb

    mov al, [text_rows]
    dec al
    mov byte [cursor_y], al

    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax


scroll_done:

    ret"""

new_scroll = """scroll:

    mov al, [term_bottom_row]
    cmp byte [cursor_y], al
    jb scroll_done

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Scroll rows inside terminal window only
    movzx ebx, byte [term_top_row]

.row_scroll_loop:
    movzx eax, byte [term_bottom_row]
    dec eax
    cmp ebx, eax
    jae .clear_bottom_term_row

    xor ecx, ecx
.scanline_scroll_loop:
    mov eax, ebx
    imul eax, FONT_HEIGHT
    add eax, ecx
    imul eax, [framebuffer_pitch]
    movzx edx, byte [term_left_col]
    imul edx, FONT_WIDTH * BYTES_PER_PIXEL
    add eax, edx
    mov rdi, [framebuffer_address]
    add rdi, rax

    mov rsi, rdi
    mov eax, [framebuffer_pitch]
    imul eax, FONT_HEIGHT
    add rsi, rax

    push rcx
    movzx ecx, byte [term_right_col]
    movzx edx, byte [term_left_col]
    sub ecx, edx
    imul ecx, FONT_WIDTH
    rep movsd
    pop rcx

    inc ecx
    cmp ecx, FONT_HEIGHT
    jb .scanline_scroll_loop

    inc ebx
    jmp .row_scroll_loop

.clear_bottom_term_row:
    xor ecx, ecx
.clear_scanline_loop:
    mov eax, ebx
    imul eax, FONT_HEIGHT
    add eax, ecx
    imul eax, [framebuffer_pitch]
    movzx edx, byte [term_left_col]
    imul edx, FONT_WIDTH * BYTES_PER_PIXEL
    add eax, edx
    mov rdi, [framebuffer_address]
    add rdi, rax

    push rcx
    movzx ecx, byte [term_right_col]
    movzx edx, byte [term_left_col]
    sub ecx, edx
    imul ecx, FONT_WIDTH
    mov eax, COLOR_WINDOW
    rep stosd
    pop rcx

    inc ecx
    cmp ecx, FONT_HEIGHT
    jb .clear_scanline_loop

    mov al, [term_bottom_row]
    dec al
    mov byte [cursor_y], al
    mov al, [term_left_col]
    mov byte [cursor_x], al

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

scroll_done:

    ret"""

if old_scroll in content:
    content = content.replace(old_scroll, new_scroll)

kpath.write_text(content, encoding="utf-8")
print("Successfully patched scrolling, GUI boundaries, and spinner in kernel.asm")
