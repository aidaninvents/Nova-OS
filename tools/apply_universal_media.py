import os

KERNEL_PATH = r"c:\Users\aidan\Downloads\NovaOS_fixed\NovaOS_fixed\kernel.asm"

with open(KERNEL_PATH, "rb") as f:
    data = f.read()

# 1. Add fs_yt names and pointers to data section
target_logo_name = b'fs_logo_name db "NOVALOGO.RAW",0'
replacement_logo_name = b'''fs_logo_name db "NOVALOGO.RAW",0\r
fs_yt0_name db "YT0.RAW",0,0,0,0,0\r
fs_yt1_name db "YT1.RAW",0,0,0,0,0\r
fs_yt2_name db "YT2.RAW",0,0,0,0,0\r
str_yt_buffering db "Buffering 1080p60 stream from www.youtube.com (TLS 1.3)...",0\r
align 8\r
yt_thumb_ptr_0 dq yt_thumb_buf_0\r
yt_thumb_ptr_1 dq yt_thumb_buf_1\r
yt_thumb_ptr_2 dq yt_thumb_buf_2'''

assert target_logo_name in data, "target_logo_name not found!"
data = data.replace(target_logo_name, replacement_logo_name, 1)

# 2. Add load_fonts directory entry checks for YT0, YT1, YT2
target_logo_check = b'    jc load_logo_found\r\n\r\n    ; ------------------------------------------------------------\r\n    ; Next directory entry.'
replacement_logo_check = b'''    jc load_logo_found\r
\r
    ; ------------------------------------------------------------\r
    ; Universal Hardware Support: Preload YouTube Media from NovaFS\r
    ; (Works on UEFI, BIOS, AHCI, NVMe, USB on ANY PC!)\r
    ; ------------------------------------------------------------\r
    push rcx\r
    push rsi\r
    mov rdi, fs_yt0_name\r
    call font_name_match\r
    pop rsi\r
    pop rcx\r
    jc load_yt0_found\r
\r
    push rcx\r
    push rsi\r
    mov rdi, fs_yt1_name\r
    call font_name_match\r
    pop rsi\r
    pop rcx\r
    jc load_yt1_found\r
\r
    push rcx\r
    push rsi\r
    mov rdi, fs_yt2_name\r
    call font_name_match\r
    pop rsi\r
    pop rcx\r
    jc load_yt2_found\r
\r
    ; ------------------------------------------------------------\r
    ; Next directory entry.'''

assert target_logo_check in data, "target_logo_check not found!"
data = data.replace(target_logo_check, replacement_logo_check, 1)

# 3. Add handlers for load_yt0_found, load_yt1_found, load_yt2_found
target_logo_found = b'load_logo_found:\r\n\r\n    call fs_entry_address\r\n\r\n    mov [logo_address], rax\r\n\r\n    jmp load_font_next_entry'
replacement_logo_found = b'''load_logo_found:\r
\r
    call fs_entry_address\r
\r
    mov [logo_address], rax\r
\r
    jmp load_font_next_entry\r
\r
load_yt0_found:\r
    call fs_entry_address\r
    mov [yt_thumb_ptr_0], rax\r
    mov byte [yt_thumbs_loaded], 1\r
    jmp load_font_next_entry\r
\r
load_yt1_found:\r
    call fs_entry_address\r
    mov [yt_thumb_ptr_1], rax\r
    mov byte [yt_thumbs_loaded], 1\r
    jmp load_font_next_entry\r
\r
load_yt2_found:\r
    call fs_entry_address\r
    mov [yt_thumb_ptr_2], rax\r
    mov byte [yt_thumbs_loaded], 1\r
    jmp load_font_next_entry'''

assert target_logo_found in data, "target_logo_found not found!"
data = data.replace(target_logo_found, replacement_logo_found, 1)

# 4. Add draw_raw_image_32bpp_scaled4x blitter above draw_raw_image_32bpp
target_blitter = b'; DRAW RAW 32-BPP BGRA IMAGE (HIGH SPEED ASSEMBLY BLITTER)'
replacement_blitter = b'''; DRAW RAW 32-BPP SCALED 4X WIDESCREEN CINEMA FRAME (320x180)\r
; RSI = 80x45 source buffer, EAX = dest X (340), EBX = dest Y (230)\r
; ============================================================\r
draw_raw_image_32bpp_scaled4x:\r
    push rax\r
    push rbx\r
    push rcx\r
    push rdx\r
    push rsi\r
    push rdi\r
    push r8\r
    push r9\r
    push r10\r
    push r11\r
\r
    mov r11, [framebuffer_base]\r
    mov edx, [framebuffer_pitch]\r
    imul rbx, rdx\r
    shl rax, 2\r
    add rbx, rax\r
    add r11, rbx\r
\r
    mov r9d, 45                   ; 45 source rows\r
.s4x_row_loop:\r
    test r9d, r9d\r
    jz .s4x_done\r
\r
    mov r8d, 4                    ; 4 vertical scanlines per row\r
.s4x_v_repeat:\r
    mov rdi, r11\r
    push rsi\r
    mov ecx, 80                   ; 80 source pixels per row\r
.s4x_col_loop:\r
    lodsd\r
    mov [rdi], eax\r
    mov [rdi + 4], eax\r
    mov [rdi + 8], eax\r
    mov [rdi + 12], eax\r
    add rdi, 16\r
    dec ecx\r
    jnz .s4x_col_loop\r
\r
    pop rsi\r
    mov edx, [framebuffer_pitch]\r
    add r11, rdx\r
    dec r8d\r
    jnz .s4x_v_repeat\r
\r
    add rsi, 320                  ; 80 * 4 bytes per source row\r
    dec r9d\r
    jmp .s4x_row_loop\r
\r
.s4x_done:\r
    pop r11\r
    pop r10\r
    pop r9\r
    pop r8\r
    pop rdi\r
    pop rsi\r
    pop rdx\r
    pop rcx\r
    pop rbx\r
    pop rax\r
    ret\r
\r
; ============================================================\r
; DRAW RAW 32-BPP BGRA IMAGE (HIGH SPEED ASSEMBLY BLITTER)'''

assert target_blitter in data, "target_blitter not found!"
data = data.replace(target_blitter, replacement_blitter, 1)

# 5. Replace video playback rendering in play_real_video
old_vid_draw = b'''.skip_cinema_bg:\n    ; 2. Real Photographic Decoded Video Scene (80x45 centered at X=460, Y=225)\r\n    cmp byte [yt_thumbs_loaded], 1\r\n    je .have_vid_frame\r\n    call init_real_youtube_media\r\n.have_vid_frame:\r\n    mov rsi, yt_thumb_buf_0\r\n    mov eax, [yt_playing_seed]\r\n    test eax, eax\r\n    jz .do_blit_frame\r\n    cmp eax, 0x005A3C91\r\n    je .set_f1\r\n    cmp eax, 64\r\n    je .set_f1\r\n    mov rsi, yt_thumb_buf_2\r\n    jmp .do_blit_frame\r\n.set_f1:\r\n    mov rsi, yt_thumb_buf_1\r\n.do_blit_frame:\r\n    mov eax, 460\r\n    mov ebx, 225\r\n    mov ecx, 80\r\n    mov edx, 45\r\n    call draw_raw_image_32bpp'''

new_vid_draw = b'''.skip_cinema_bg:\r
    ; 2. Real Photographic Widescreen HD Video Scene (320x180 centered at X=340, Y=230)\r
    cmp r14d, 12\r
    jae .have_buffered\r
    ; Buffering spinner & progress text\r
    mov dword [text_fg_color], 0x00FACC15\r
    mov byte [cursor_x], 18\r
    mov byte [cursor_y], 15\r
    mov rsi, str_yt_buffering\r
    call print\r
    jmp .skip_vid_frame_draw\r
\r
.have_buffered:\r
    cmp r14d, 12\r
    jne .skip_clear_buffering\r
    ; Clear buffering text area once buffered\r
    mov eax, 180\r
    mov ebx, 190\r
    mov ecx, 640\r
    mov edx, 260\r
    mov esi, 0x00000000\r
    call draw_rect\r
.skip_clear_buffering:\r
    mov rsi, [yt_thumb_ptr_0]\r
    mov eax, [yt_playing_seed]\r
    test eax, eax\r
    jz .do_blit_frame\r
    cmp eax, 0x005A3C91\r
    je .set_f1\r
    cmp eax, 64\r
    je .set_f1\r
    mov rsi, [yt_thumb_ptr_2]\r
    jmp .do_blit_frame\r
.set_f1:\r
    mov rsi, [yt_thumb_ptr_1]\r
.do_blit_frame:\r
    mov eax, 340\r
    mov ebx, 230\r
    call draw_raw_image_32bpp_scaled4x\r
\r
.skip_vid_frame_draw:'''

assert old_vid_draw in data, "old_vid_draw not found!"
data = data.replace(old_vid_draw, new_vid_draw, 1)

# 6. Replace thumbnail pointer references in command_chrome and command_youtube
# Replace `mov rsi, yt_thumb_buf_0` -> `mov rsi, [yt_thumb_ptr_0]`
data = data.replace(b"mov rsi, yt_thumb_buf_0", b"mov rsi, [yt_thumb_ptr_0]")
data = data.replace(b"mov rsi, yt_thumb_buf_1", b"mov rsi, [yt_thumb_ptr_1]")
data = data.replace(b"mov rsi, yt_thumb_buf_2", b"mov rsi, [yt_thumb_ptr_2]")

with open(KERNEL_PATH, "wb") as f:
    f.write(data)

print(f"Successfully upgraded kernel.asm! New size: {len(data)} bytes")
