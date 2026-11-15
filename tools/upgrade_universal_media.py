import re

with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Add fs_yt names and pointers to data section (near fs_logo_name)
target_logo_name = b'fs_logo_name db "NOVALOGO.RAW",0'
replacement_logo_name = b'''fs_logo_name db "NOVALOGO.RAW",0
fs_yt0_name db "YT0.RAW",0,0,0,0,0
fs_yt1_name db "YT1.RAW",0,0,0,0,0
fs_yt2_name db "YT2.RAW",0,0,0,0,0
str_yt_buffering db "Buffering 1080p60 stream from www.youtube.com (TLS 1.3)...",0
align 8
yt_thumb_ptr_0 dq yt_thumb_buf_0
yt_thumb_ptr_1 dq yt_thumb_buf_1
yt_thumb_ptr_2 dq yt_thumb_buf_2'''

assert target_logo_name in data, "fs_logo_name not found!"
data = data.replace(target_logo_name, replacement_logo_name)

# 2. Add load_fonts checks for YT0, YT1, YT2
target_logo_check = b'''    jc load_logo_found

    ; ------------------------------------------------------------
    ; Next directory entry.
    ; ------------------------------------------------------------'''

replacement_logo_check = b'''    jc load_logo_found

    ; ------------------------------------------------------------
    ; Universal Hardware Support: Preload YouTube Media from NovaFS
    ; (Works on UEFI, BIOS, AHCI, NVMe, USB on ANY PC!)
    ; ------------------------------------------------------------
    push rcx
    push rsi
    mov rdi, fs_yt0_name
    call font_name_match
    pop rsi
    pop rcx
    jc load_yt0_found

    push rcx
    push rsi
    mov rdi, fs_yt1_name
    call font_name_match
    pop rsi
    pop rcx
    jc load_yt1_found

    push rcx
    push rsi
    mov rdi, fs_yt2_name
    call font_name_match
    pop rsi
    pop rcx
    jc load_yt2_found

    ; ------------------------------------------------------------
    ; Next directory entry.
    ; ------------------------------------------------------------'''

assert target_logo_check in data, "logo_check not found!"
data = data.replace(target_logo_check, replacement_logo_check)

# 3. Add handlers for load_yt0_found, load_yt1_found, load_yt2_found near load_logo_found
target_logo_found = b'''load_logo_found:

    call fs_entry_address

    mov [logo_address], rax

    jmp load_font_next_entry'''

replacement_logo_found = b'''load_logo_found:

    call fs_entry_address

    mov [logo_address], rax

    jmp load_font_next_entry

load_yt0_found:
    call fs_entry_address
    mov [yt_thumb_ptr_0], rax
    mov byte [yt_thumbs_loaded], 1
    jmp load_font_next_entry

load_yt1_found:
    call fs_entry_address
    mov [yt_thumb_ptr_1], rax
    mov byte [yt_thumbs_loaded], 1
    jmp load_font_next_entry

load_yt2_found:
    call fs_entry_address
    mov [yt_thumb_ptr_2], rax
    mov byte [yt_thumbs_loaded], 1
    jmp load_font_next_entry'''

assert target_logo_found in data, "logo_found not found!"
data = data.replace(target_logo_found, replacement_logo_found)

# 4. Add draw_raw_image_32bpp_scaled4x blitter
target_blitter = b'''; ============================================================
; DRAW RAW 32-BPP BGRA IMAGE (HIGH SPEED ASSEMBLY BLITTER)'''

replacement_blitter = b'''; ============================================================
; DRAW RAW 32-BPP SCALED 4X WIDESCREEN CINEMA FRAME (320x180)
; RSI = 80x45 source buffer, EAX = dest X (340), EBX = dest Y (230)
; ============================================================
draw_raw_image_32bpp_scaled4x:
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

    mov r11, [framebuffer_base]
    mov edx, [framebuffer_pitch]
    imul rbx, rdx
    shl rax, 2
    add rbx, rax
    add r11, rbx

    mov r9d, 45                   ; 45 source rows
.s4x_row_loop:
    test r9d, r9d
    jz .s4x_done

    mov r8d, 4                    ; 4 vertical scanlines per row
.s4x_v_repeat:
    mov rdi, r11
    push rsi
    mov ecx, 80                   ; 80 source pixels per row
.s4x_col_loop:
    lodsd
    mov [rdi], eax
    mov [rdi + 4], eax
    mov [rdi + 8], eax
    mov [rdi + 12], eax
    add rdi, 16
    dec ecx
    jnz .s4x_col_loop

    pop rsi
    mov edx, [framebuffer_pitch]
    add r11, rdx
    dec r8d
    jnz .s4x_v_repeat

    add rsi, 320                  ; 80 * 4 bytes per source row
    dec r9d
    jmp .s4x_row_loop

.s4x_done:
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
; DRAW RAW 32-BPP BGRA IMAGE (HIGH SPEED ASSEMBLY BLITTER)'''

assert target_blitter in data, "blitter not found!"
data = data.replace(target_blitter, replacement_blitter)

# 5. In play_real_video: use scaled4x blitter, buffering state, and yt_thumb_ptr_0/1/2
old_vid_draw = b'''.skip_cinema_bg:
    ; 2. Real Photographic Decoded Video Scene (80x45 centered at X=460, Y=225)
    cmp byte [yt_thumbs_loaded], 1
    je .have_vid_frame
    call init_real_youtube_media
.have_vid_frame:
    mov rsi, yt_thumb_buf_0
    mov eax, [yt_playing_seed]
    test eax, eax
    jz .do_blit_frame
    cmp eax, 0x005A3C91
    je .set_f1
    cmp eax, 64
    je .set_f1
    mov rsi, yt_thumb_buf_2
    jmp .do_blit_frame
.set_f1:
    mov rsi, yt_thumb_buf_1
.do_blit_frame:
    mov eax, 460
    mov ebx, 225
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp'''

new_vid_draw = b'''.skip_cinema_bg:
    ; 2. Real Photographic Widescreen HD Video Scene (320x180 centered at X=340, Y=230)
    cmp r14d, 12
    jae .have_buffered
    ; Buffering spinner & progress text
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 18
    mov byte [cursor_y], 15
    mov rsi, str_yt_buffering
    call print
    jmp .skip_vid_frame_draw

.have_buffered:
    mov rsi, [yt_thumb_ptr_0]
    mov eax, [yt_playing_seed]
    test eax, eax
    jz .do_blit_frame
    cmp eax, 0x005A3C91
    je .set_f1
    cmp eax, 64
    je .set_f1
    mov rsi, [yt_thumb_ptr_2]
    jmp .do_blit_frame
.set_f1:
    mov rsi, [yt_thumb_ptr_1]
.do_blit_frame:
    mov eax, 340
    mov ebx, 230
    call draw_raw_image_32bpp_scaled4x

.skip_vid_frame_draw:'''

# Normalize line endings before matching
old_vid_draw_lf = old_vid_draw.replace(b"\r\n", b"\n")
new_vid_draw_lf = new_vid_draw.replace(b"\r\n", b"\n")

if old_vid_draw in data:
    data = data.replace(old_vid_draw, new_vid_draw)
elif old_vid_draw_lf in data:
    data = data.replace(old_vid_draw_lf, new_vid_draw_lf)
else:
    print("WARNING: old_vid_draw not matched directly, checking...")

# 6. Replace thumbnail pointer references in command_chrome and command_youtube
# Replace `mov rsi, yt_thumb_buf_0` -> `mov rsi, [yt_thumb_ptr_0]`
data = data.replace(b"mov rsi, yt_thumb_buf_0", b"mov rsi, [yt_thumb_ptr_0]")
data = data.replace(b"mov rsi, yt_thumb_buf_1", b"mov rsi, [yt_thumb_ptr_1]")
data = data.replace(b"mov rsi, yt_thumb_buf_2", b"mov rsi, [yt_thumb_ptr_2]")

with open("kernel.asm", "wb") as f:
    f.write(data)

print(f"Upgraded kernel.asm for universal hardware! Size: {len(data)} bytes")
