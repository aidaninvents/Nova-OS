import sys

with open("kernel.asm", "rb") as f:
    data = f.read()

crlf = b"\r\n" in data

def nl(s: str) -> bytes:
    return (s.replace("\n", "\r\n") if crlf else s).encode("ascii")

# 1. Remove dead unreferenced strings verified by find_unref_strings.py
dead_lines = [
    'str_py_sysver:     db "sys.version",0',
    'str_py_impsys:     db "import sys",0',
    'str_py_oslist:     db "os.listdir",0',
    'str_py_impos:      db "import os",0',
    'str_ns_default_url: db "https://github.com/netsurf-browser/netsurf",0',
    'str_ns_page_header: db "NetSurf 3.12 Dev [Git: d06cd9d] (Hubbub + LibDOM + LibCSS Engine)",0',
    'str_ns_page_body1:  db "Official NetSurf C Browser from GitHub! Frontends: Framebuffer /dev/fb0, GTK.",0',
    'str_ns_page_body2:  db "Features: CSS3, HTML5 Canvas, DOM Tree, Duktape JS, and LibCURL HTTP/HTTPS.",0',
    'str_ns_prompt_url: db "Browse URL: ",0',
]
freed = 0
for dl in dead_lines:
    b_dl = nl(dl + "\n")
    if b_dl in data:
        data = data.replace(b_dl, b"", 1)
        freed += len(b_dl)
print(f"Freed {freed} bytes of dead unreferenced strings.")

# 2. Replace play_real_video .. clear_video_region .. yt_handle_input
start_marker = b"play_real_video:"
end_marker = nl("; ============================================================\n; REGISTER FILE IN NOVAFS HELPER")
s_idx = data.find(start_marker)
e_idx = data.find(end_marker)
assert s_idx != -1 and e_idx != -1, f"Markers not found: {s_idx}, {e_idx}"

new_video_subsystem = """VIDEO_YUV_BUF        equ 0x03000000
VIDEO_U_BUF          equ 0x0303CC00
VIDEO_V_BUF          equ 0x0304BF00
VIDEO_FRAME_SECTORS  equ 729
VIDEO_PCM_LBA        equ 10000
VIDEO_PCM_SECTORS    equ 7125
VIDEO_PCM_BYTES      equ 3648000
VIDEO_YUV_LBA        equ 18000
VIDEO_TOTAL_FRAMES   equ 284

play_real_video:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    push r14
    push r15

    call restore_mouse_background
    call pulse_net_activity
    mov byte [yt_video_paused], 0
    mov byte [yt_prev_mouse_btn], 1  ; Ignore held launch click until released

    ; Outer Cinema Player Frame (X=160, Y=80, W=704, H=600)
    mov eax, 160
    mov ebx, 80
    mov ecx, 704
    mov edx, 600
    mov esi, 0x000B0F19
    call draw_rect

    ; Top YouTube Red Accent Border
    mov eax, 160
    mov ebx, 80
    mov ecx, 704
    mov edx, 4
    mov esi, 0x00FF0000
    call draw_rect

    ; Close [X] Button (X=810, Y=86, W=48, H=24)
    mov eax, 810
    mov ebx, 86
    mov ecx, 48
    mov edx, 24
    mov esi, 0x00DC2626
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 68
    mov byte [cursor_y], 4
    mov rsi, str_yt_close_x
    call print

    ; Header & Title (Y=100, cursor_y=5)
    mov dword [text_fg_color], 0x00FF0000
    mov byte [cursor_x], 15
    mov byte [cursor_y], 5
    mov rsi, str_video_stream_header
    call print
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, [yt_playing_title_ptr]
    call print

    ; Video Metadata Row (Y=640, cursor_y=32)
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 15
    mov byte [cursor_y], 32
    mov rsi, [yt_playing_meta_ptr]
    call print

    ; Black Cinema Viewport Mat (X=180, Y=126, W=664, H=444)
    mov eax, 180
    mov ebx, 126
    mov ecx, 664
    mov edx, 444
    mov esi, 0x00000000
    call draw_rect

    ; Check which video is selected: Video 1 (seed == 0) uses Real 576x432 15fps HD Stream!
    cmp dword [yt_playing_seed], 0
    jne near .fallback_thumb_video

    ; Show fast buffering prompt while loading 19s Stereo PCM Audio from disk
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 24
    mov byte [cursor_y], 17
    mov rsi, str_yt_buffering
    call print

    ; Load real 19s 48kHz 16-bit stereo PCM audio (LBA 10000, 7125 sectors -> 0x00600000)
    mov eax, VIDEO_PCM_LBA
    mov ecx, VIDEO_PCM_SECTORS
    mov rdi, AUDIO_DMA_BUFFER
    call ata_read_sectors
    mov dword [audio_size], VIDEO_PCM_BYTES

    ; Clear buffering text in black cinema mat
    mov eax, 180
    mov ebx, 126
    mov ecx, 664
    mov edx, 444
    mov esi, 0x00000000
    call draw_rect

    ; Start Intel AC'97 Stereo DMA Playback!
    mov eax, [audio_bm]
    test eax, eax
    jz .hd_no_audio
    call audio_start_dma
.hd_no_audio:
    ; Initialize PIT Ch0 snapshot for exact 15.00 FPS (79,545 PIT ticks / frame)
    call pit_read_ch0
    mov [yt_last_pit], ax

    xor r14d, r14d           ; Frame index 0..283

.hd_frame_loop:
    cmp r14d, VIDEO_TOTAL_FRAMES
    jge near .video_stream_done

    ; Compute LBA = 18000 + r14d * 729 and load 576x432 YUV420P frame into VIDEO_YUV_BUF
    mov eax, r14d
    imul eax, VIDEO_FRAME_SECTORS
    add eax, VIDEO_YUV_LBA
    mov ecx, VIDEO_FRAME_SECTORS
    mov rdi, VIDEO_YUV_BUF
    call ata_read_sectors

    ; Render crisp 576x432 TrueColor frame directly to (X=224, Y=132)
    call draw_yuv420_frame_576x432

    ; Update Seek Bar Track, Red Elapsed Bar & White Scrubber Knob (clean redraw!)
    mov eax, 176
    mov ebx, 578
    mov ecx, 674
    mov edx, 16
    mov esi, 0x000B0F19
    call draw_rect

    mov eax, 180
    mov ebx, 582
    mov ecx, 664
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    mov eax, r14d
    imul eax, 664
    xor edx, edx
    mov ecx, VIDEO_TOTAL_FRAMES
    div ecx
    cmp eax, 664
    jbe .hd_prog_ok
    mov eax, 664
.hd_prog_ok:
    push rax
    mov ecx, eax
    test ecx, ecx
    jz .hd_skip_red
    mov eax, 180
    mov ebx, 582
    mov edx, 8
    mov esi, 0x00FF0000
    call draw_rect
.hd_skip_red:
    pop rax
    add eax, 176
    mov ebx, 579
    mov ecx, 8
    mov edx, 14
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Clear Transport Row (Y=598..622) & draw crisp status + non-overlapping timecode
    mov eax, 176
    mov ebx, 598
    mov ecx, 674
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect

    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 30
    mov rsi, str_yt_playing_badge
    call print

    ; Timecode 00:XX / 00:19 (sec = r14d / 15)
    mov eax, r14d
    xor edx, edx
    mov ecx, 15
    div ecx
    cmp eax, 19
    jbe .sec_ok
    mov eax, 19
.sec_ok:
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [str_yt_timecode + 3], al
    add dl, '0'
    mov [str_yt_timecode + 4], dl

    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 31
    mov byte [cursor_y], 30
    mov rsi, str_yt_timecode
    call print

    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 47
    mov byte [cursor_y], 30
    mov rsi, str_yt_hd_keys
    call print

    ; Frame Pacer: wait until 79,545 PIT ticks (66.67ms = 15fps) elapsed since yt_last_pit
    xor r15d, r15d           ; accumulated PIT ticks
.hd_wait_tick:
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .hd_not_paused

    ; Draw amber [ || PAUSED ] badge cleanly while paused
    mov eax, 176
    mov ebx, 598
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 15
    mov byte [cursor_y], 30
    mov rsi, str_yt_paused_badge
    call print

.hd_pause_spin:
    pause
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    je .hd_pause_spin

    ; Reset PIT baseline on resume and redraw green [ > PLAYING ] badge
    call pit_read_ch0
    mov [yt_last_pit], ax
    jmp .hd_next_frame

.hd_not_paused:
    call pit_read_ch0
    movzx edx, word [yt_last_pit]
    mov [yt_last_pit], ax
    sub dx, ax               ; PIT counts down: prev - curr (mod 65536)
    movzx edx, dx
    add r15d, edx
    cmp r15d, 79545
    jb .hd_wait_tick

.hd_next_frame:
    inc r14d
    jmp .hd_frame_loop

; Fallback high-res thumbnail visualizer for Video 2 & Video 3
.fallback_thumb_video:
    mov eax, [audio_bm]
    test eax, eax
    jz .fb_no_audio
    call audio_start_dma
.fb_no_audio:
    mov rsi, [yt_thumb_ptr_1]
    cmp dword [yt_playing_seed], 0x005A3C91
    je .fb_draw
    cmp dword [yt_playing_seed], 64
    je .fb_draw
    mov rsi, [yt_thumb_ptr_2]
.fb_draw:
    mov eax, 352
    mov ebx, 250
    call draw_raw_image_32bpp_scaled4x
.fb_wait:
    mov ecx, 1500000
.fb_dly:
    pause
    dec ecx
    jnz .fb_dly
    call yt_handle_input
    cmp eax, 1
    jne .fb_wait

.video_stream_done:
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_done_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 2
    out dx, al
.skip_done_dma:
    call speaker_stop
    mov byte [yt_video_paused], 0
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    call draw_mouse_cursor

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------
; pit_read_ch0: Latch and return current 16-bit PIT Ch0 counter in AX
; ------------------------------------------------------------
pit_read_ch0:
    push rdx
    xor al, al
    out 0x43, al
    in al, 0x40
    mov dl, al
    in al, 0x40
    mov ah, al
    mov al, dl
    pop rdx
    ret

; ------------------------------------------------------------
; draw_yuv420_frame_576x432:
; Converts full-range 576x432 YUV420P at VIDEO_YUV_BUF directly to
; 32-bit BGRA framebuffer pixels at (X=224, Y=132) with zero scaling blur!
; ------------------------------------------------------------
draw_yuv420_frame_576x432:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov rsi, VIDEO_YUV_BUF
    lea r10, [rsi + 576]
    mov r11, VIDEO_U_BUF
    mov r12, VIDEO_V_BUF

    ; rdi = framebuffer_address + 132 * pitch + 224 * 4
    mov eax, 132
    imul eax, [framebuffer_pitch]
    add eax, 224 * 4
    add rax, [framebuffer_address]
    mov rdi, rax
    mov edx, [framebuffer_pitch]
    lea r13, [rdi + rdx]

    mov r8d, 216             ; 216 row pairs = 432 scanlines
.yuv_row_loop:
    mov r9d, 288             ; 288 col pairs = 576 pixels/row
.yuv_col_loop:
    movzx eax, byte [r11]    ; U
    sub eax, 128             ; cb
    movzx ecx, byte [r12]    ; V
    sub ecx, 128             ; cr

    ; r14d = (359 * cr) >> 8
    imul r14d, ecx, 359
    sar r14d, 8

    ; r15d = (-88 * cb - 183 * cr) >> 8
    imul r15d, eax, -88
    imul edx, ecx, -183
    add r15d, edx
    sar r15d, 8

    ; ebp = (454 * cb) >> 8
    imul ebp, eax, 454
    sar ebp, 8

    ; Convert 2x2 pixel block directly into framebuffer
    movzx eax, byte [rsi]
    call .yuv_px
    mov [rdi], eax

    movzx eax, byte [rsi + 1]
    call .yuv_px
    mov [rdi + 4], eax

    movzx eax, byte [r10]
    call .yuv_px
    mov [r13], eax

    movzx eax, byte [r10 + 1]
    call .yuv_px
    mov [r13 + 4], eax

    add rsi, 2
    add r10, 2
    add rdi, 8
    add r13, 8
    inc r11
    inc r12
    dec r9d
    jnz .yuv_col_loop

    ; Advance Y by extra 576 bytes to skip odd scanline
    add rsi, 576
    lea r10, [rsi + 576]
    ; Advance fb_row0 = r13 + pitch - 2304, fb_row1 = fb_row0 + pitch
    mov edx, [framebuffer_pitch]
    lea rdi, [r13 + rdx - 2304]
    lea r13, [rdi + rdx]

    dec r8d
    jnz .yuv_row_loop

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Input: EAX = Y (0..255), R14D = r_off, R15D = g_off, EBP = b_off
; Output: EAX = 0x00RRGGBB
.yuv_px:
    xor ebx, ebx
    lea ecx, [rax + r14]
    test ecx, ecx
    cmovs ecx, ebx
    cmp ecx, 255
    jbe .rk
    mov ecx, 255
.rk:
    shl ecx, 16
    lea edx, [rax + r15]
    test edx, edx
    cmovs edx, ebx
    cmp edx, 255
    jbe .gk
    mov edx, 255
.gk:
    shl edx, 8
    or ecx, edx
    add eax, ebp
    test eax, eax
    cmovs eax, ebx
    cmp eax, 255
    jbe .bk
    mov eax, 255
.bk:
    or eax, ecx
    ret

; ------------------------------------------------------------
; clear_video_region: Clears video playback canvas to desktop slate
; ------------------------------------------------------------
clear_video_region:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    mov eax, 160
    mov ebx, 80
    mov ecx, 704
    mov edx, 600
    mov esi, 0x000F172A
    call draw_rect
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------
; serial_send_char: Send single byte in AL over COM1 / TCP bridge
; ------------------------------------------------------------
serial_send_char:
    push rax
    push rdx
    mov ah, al
    mov dx, 0x3FD
.tx_wait:
    in al, dx
    test al, 0x20
    jz .tx_wait
    mov dx, 0x3F8
    mov al, ah
    out dx, al
    pop rdx
    pop rax
    ret

align 4
yt_video_paused:   db 0
yt_prev_mouse_btn: db 0
yt_last_pit:       dw 0
str_yt_paused_badge: db "[ || PAUSED ]",0
str_yt_hd_keys:      db "[Space:Pause] [Esc:Close]",0
str_yt_close_x:      db " X ",0

; ------------------------------------------------------------
; yt_handle_input:
;   - Space / Pause Button: toggles playback, pauses audio DMA, sends 0x01/0x02
;   - Escape / Close [X]: stops audio DMA, sends 0x00, clears canvas, returns EAX=1
; ------------------------------------------------------------
yt_handle_input:
    in al, KBD_STATUS
    test al, 1
    jz .check_mouse_click
    test al, 0x20
    jnz .consume_mouse_byte
    in al, KBD_DATA
    test al, 0x80
    jnz .check_mouse_click
    cmp al, 0x01             ; ESC scancode
    je .do_close_player
    cmp al, 0x39             ; Space scancode
    je .toggle_pause_play
    jmp .check_mouse_click

.consume_mouse_byte:
    in al, KBD_DATA

.check_mouse_click:
    mov al, [mouse_byte0]
    and al, 1
    mov ah, [yt_prev_mouse_btn]
    mov [yt_prev_mouse_btn], al
    test al, al
    jz .input_continue
    test ah, ah              ; Only trigger on rising edge of left click
    jnz .input_continue

    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    ; Close [X] Button (X=810..864, Y=80..115)
    cmp eax, 810
    jb .check_pause_btn
    cmp eax, 864
    ja .check_pause_btn
    cmp ebx, 80
    jb .check_pause_btn
    cmp ebx, 115
    jbe .do_close_player

.check_pause_btn:
    ; Pause/Play Badge Button (X=170..350, Y=595..630)
    cmp eax, 170
    jb .input_continue
    cmp eax, 350
    ja .input_continue
    cmp ebx, 595
    jb .input_continue
    cmp ebx, 630
    jbe .toggle_pause_play

.input_continue:
    xor eax, eax
    ret

.toggle_pause_play:
    xor byte [yt_video_paused], 1
    cmp byte [yt_video_paused], 1
    je .do_pause
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_resume_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 1
    out dx, al
.skip_resume_dma:
    mov al, 0x02
    call serial_send_char
    xor eax, eax
    ret

.do_pause:
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_pause_dma
    add eax, PO_CR
    mov dx, ax
    xor al, al
    out dx, al
.skip_pause_dma:
    call speaker_stop
    mov al, 0x01
    call serial_send_char
    xor eax, eax
    ret

.do_close_player:
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_stop_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 2
    out dx, al
.skip_stop_dma:
    call speaker_stop
    mov al, 0x00
    call serial_send_char
    call clear_video_region
    mov byte [yt_video_paused], 0
    mov eax, 1
    ret

"""

data = data[:s_idx] + nl(new_video_subsystem) + data[e_idx:]

# 3. Replace ata_read_sectors with multi-sector batch ATA PIO reader
ata_start = b"ata_read_sectors:"
ata_end = nl("; ============================================================\n; LOAD REAL YOUTUBE MEDIA FROM DISK INTO RAM BUFFERS")
as_idx = data.find(ata_start)
ae_idx = data.find(ata_end)
assert as_idx != -1 and ae_idx != -1, "ata markers not found"

new_ata_read = """ata_read_sectors:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    cld

.ata_r_loop:
    test ecx, ecx
    jz .ata_r_done

    mov r8d, ecx
    cmp r8d, 128
    jbe .batch_ok
    mov r8d, 128
.batch_ok:
    push rcx
    push rax
    push rdi

    mov edx, 0x1F6
    mov ebx, eax
    shr ebx, 24
    and bl, 0x0F
    or bl, 0xE0
    mov al, bl
    out dx, al

    mov edx, 0x1F2
    mov eax, r8d
    out dx, al

    pop rdi
    pop rax
    push rax
    push rdi
    mov edx, 0x1F3
    out dx, al

    mov edx, 0x1F4
    mov al, ah
    out dx, al

    mov edx, 0x1F5
    push rax
    shr eax, 16
    out dx, al
    pop rax

    mov edx, 0x1F7
    mov al, 0x20
    out dx, al

    mov esi, r8d
.batch_sector:
    mov edx, 0x1F7
    mov ebx, 50000
.wait_read_drq:
    in al, dx
    cmp al, 0xFF
    je .ata_r_abort
    test al, 0x80
    jnz .still_wait_r
    test al, 0x08
    jnz .ready_read
.still_wait_r:
    pause
    dec ebx
    jnz .wait_read_drq
    jmp .ata_r_abort

.ready_read:
    mov edx, 0x1F0
    mov ecx, 256
    rep insw
    dec esi
    jnz .batch_sector

    pop rdi
    mov eax, r8d
    shl eax, 9
    add rdi, rax
    pop rax
    add eax, r8d
    pop rcx
    sub ecx, r8d
    jmp .ata_r_loop

.ata_r_abort:
    pop rdi
    pop rax
    pop rcx

.ata_r_done:
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

"""

data = data[:as_idx] + nl(new_ata_read) + data[ae_idx:]

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Successfully upgraded kernel.asm with 576x432 HD video decoder, AC'97 lip-sync audio, and fast batch ATA PIO!")
