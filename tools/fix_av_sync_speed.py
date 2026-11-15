with open("kernel.asm", "rb") as f:
    data = f.read()

crlf = b"\r\n" in data
def nl(s: str) -> bytes:
    return (s.replace("\n", "\r\n") if crlf else s).encode("ascii")

start_marker = b"VIDEO_YUV_BUF        equ 0x03000000"
end_marker = nl("; ------------------------------------------------------------\n; clear_video_region:")
s_idx = data.find(start_marker)
e_idx = data.find(end_marker)
assert s_idx != -1 and e_idx != -1, f"Markers not found: {s_idx}, {e_idx}"

new_code = """VIDEO_YUV_BUF        equ 0x03000000
VIDEO_U_BUF          equ 0x0303CC00
VIDEO_V_BUF          equ 0x0304BF00
VIDEO_ROW0_BUF       equ 0x03060000
VIDEO_ROW1_BUF       equ 0x03061000
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
    mov byte [yt_prev_mouse_btn], 1
    mov dword [yt_last_sec], -1

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

    ; Static Transport Hints & Green Playing Badge (drawn once, updated on pause/resume)
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 30
    mov rsi, str_yt_playing_badge
    call print

    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 47
    mov byte [cursor_y], 30
    mov rsi, str_yt_hd_keys
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

    ; Seek bar background track
    mov eax, 180
    mov ebx, 582
    mov ecx, 664
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    ; Check which video is selected: Video 1 (seed == 0) uses Real 576x432 15fps HD Stream!
    cmp dword [yt_playing_seed], 0
    jne near .fallback_thumb_video

    ; Load real 19s 48kHz 16-bit stereo PCM audio (LBA 10000, 7125 sectors -> 0x00600000)
    mov eax, VIDEO_PCM_LBA
    mov ecx, VIDEO_PCM_SECTORS
    mov rdi, AUDIO_DMA_BUFFER
    call ata_read_sectors
    mov dword [audio_size], VIDEO_PCM_BYTES

    ; Start Intel AC'97 Stereo DMA Playback!
    mov eax, [audio_bm]
    test eax, eax
    jz .hd_no_audio
    call audio_start_dma
.hd_no_audio:
    xor r14d, r14d           ; Frame index 0..283

.hd_frame_loop:
    cmp r14d, VIDEO_TOTAL_FRAMES
    jge near .video_stream_done

    ; Load frame r14d from ATA disk into VIDEO_YUV_BUF
    mov eax, r14d
    imul eax, VIDEO_FRAME_SECTORS
    add eax, VIDEO_YUV_LBA
    mov ecx, VIDEO_FRAME_SECTORS
    mov rdi, VIDEO_YUV_BUF
    call ata_read_sectors

    ; Render crisp 576x432 TrueColor frame via fast cached row buffer + 64-bit rep movsq
    call draw_yuv420_frame_576x432

    ; Update Seek Bar Track, Red Elapsed Bar & White Scrubber Knob
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

    ; Update Timecode ONLY once per second (15 frames) to avoid redundant font blitting!
    mov eax, r14d
    xor edx, edx
    mov ecx, 15
    div ecx
    cmp eax, 19
    jbe .sec_ok
    mov eax, 19
.sec_ok:
    cmp eax, [yt_last_sec]
    je .skip_sec_print
    mov [yt_last_sec], eax

    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [str_yt_timecode + 3], al
    add dl, '0'
    mov [str_yt_timecode + 4], dl

    mov eax, 370
    mov ebx, 598
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 31
    mov byte [cursor_y], 30
    mov rsi, str_yt_timecode
    call print
.skip_sec_print:

    ; AC'97 Hardware Lip-Sync using BDL descriptor + PO_PICB (with safe software fallback)
    mov r15d, 1000000
.hd_sync_loop:
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .hd_check_ac97

    ; Paused: show amber [ || PAUSED ] badge cleanly
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

    ; Resumed: restore green [ > PLAYING ] badge
    mov eax, 176
    mov ebx, 598
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 30
    mov rsi, str_yt_playing_badge
    call print
    jmp .hd_next_frame

.hd_check_ac97:
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .hd_no_hw_sync
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1               ; Audio finished (DCH=1)?
    jnz .hd_no_hw_sync

    ; Compute live 16-bit sample index from PO_CIV & PO_PICB
    lea edx, [ebx + PO_CIV]
    in al, dx
    movzx ecx, al
    and ecx, 31
    movzx esi, word [AUDIO_BDL + rcx*8 + 4]
    imul ecx, 65534
    lea edx, [ebx + PO_PICB]
    in ax, dx
    movzx eax, ax
    cmp eax, esi
    jae .hd_picb_skip
    sub esi, eax
    add ecx, esi
.hd_picb_skip:
    mov eax, ecx
    xor edx, edx
    mov esi, 6400            ; 48kHz stereo @ 15fps = 6400 16-bit samples/frame
    div esi                  ; eax = exact synced video frame
    cmp eax, r14d
    ja .hd_jump_synced
    pause
    dec r15d
    jnz .hd_sync_loop
    jmp .hd_next_frame

.hd_jump_synced:
    mov r14d, eax
    jmp .hd_frame_loop

.hd_no_hw_sync:
    ; No active AC'97 clock: advance immediately cleanly at ~15fps
    inc r14d
    jmp .hd_frame_loop

.hd_next_frame:
    inc r14d
    jmp .hd_frame_loop

; Animated multi-frame player for Video 2 & Video 3 (with AC'97 audio + live progress)
.fallback_thumb_video:
    mov eax, [audio_bm]
    test eax, eax
    jz .fb_no_audio
    call audio_start_dma
.fb_no_audio:
    xor r14d, r14d
.fb_anim_loop:
    cmp r14d, 180
    jge .video_stream_done
    mov rsi, [yt_thumb_ptr_1]
    cmp dword [yt_playing_seed], 0x005A3C91
    je .fb_draw
    cmp dword [yt_playing_seed], 64
    je .fb_draw
    mov rsi, [yt_thumb_ptr_2]
.fb_draw:
    mov eax, r14d
    shr eax, 3
    and eax, 3
    sub eax, 1
    add eax, 352
    mov ebx, 250
    call draw_raw_image_32bpp_scaled4x

    mov eax, r14d
    imul eax, 664
    xor edx, edx
    mov ecx, 180
    div ecx
    mov ecx, eax
    mov eax, 180
    mov ebx, 582
    mov edx, 8
    mov esi, 0x00FF0000
    call draw_rect

    mov ecx, 1500000
.fb_dly:
    pause
    dec ecx
    jnz .fb_dly
    call yt_handle_input
    cmp eax, 1
    je .video_stream_done
    inc r14d
    jmp .fb_anim_loop

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
; draw_yuv420_frame_576x432:
; Converts 576x432 full-range YUV420P into cached RAM row buffers
; then bursts both scanlines to VRAM via fast 64-bit rep movsq!
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

    ; r8 = current VRAM scanline address (starting at X=224, Y=132)
    mov eax, 132
    imul eax, [framebuffer_pitch]
    add eax, 224 * 4
    add rax, [framebuffer_address]
    mov r8, rax

    mov qword [yt_row_pair_cnt], 216
.yuv_row_loop:
    mov rdi, VIDEO_ROW0_BUF
    mov r13, VIDEO_ROW1_BUF
    mov r9d, 288
.yuv_col_loop:
    movzx eax, byte [r11]
    sub eax, 128
    movzx ecx, byte [r12]
    sub ecx, 128

    imul r14d, ecx, 359
    sar r14d, 8

    imul r15d, eax, -88
    imul edx, ecx, -183
    add r15d, edx
    sar r15d, 8

    imul ebp, eax, 454
    sar ebp, 8

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

    ; Burst both cached 576-px rows into VRAM via 64-bit rep movsq (288 qwords each)
    push rsi
    mov rsi, VIDEO_ROW0_BUF
    mov rdi, r8
    mov ecx, 288
    rep movsq

    mov edx, [framebuffer_pitch]
    mov rsi, VIDEO_ROW1_BUF
    lea rdi, [r8 + rdx]
    mov ecx, 288
    rep movsq

    lea r8, [r8 + rdx * 2]
    pop rsi

    add rsi, 576
    lea r10, [rsi + 576]

    dec qword [yt_row_pair_cnt]
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

yt_last_sec:     dd -1
yt_row_pair_cnt: dq 0

"""

data = data[:s_idx] + nl(new_code) + data[e_idx:]

with open("kernel.asm", "wb") as f:
    f.write(data)
print("Successfully updated play_real_video & draw_yuv420_frame_576x432!")
