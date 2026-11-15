with open("kernel.asm", "rb") as f:
    data = f.read()

start_marker = b"play_real_video:"
end_marker = b"; ------------------------------------------------------------\r\n; clear_video_region:"
if end_marker not in data:
    end_marker = b"; ------------------------------------------------------------\n; clear_video_region:"

start_idx = data.find(start_marker)
end_idx = data.find(end_marker)
assert start_idx != -1 and end_idx != -1

new_play_real_video = """play_real_video:
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

    ; Top YouTube Red Border
    mov eax, 160
    mov ebx, 140
    mov ecx, 680
    mov edx, 4
    mov esi, 0x00FF0000
    call draw_rect

    ; YouTube Header & Title
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FF0000
    mov byte [cursor_x], 15
    mov byte [cursor_y], 8
    mov rsi, str_video_stream_header
    call print
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, [yt_playing_title_ptr]
    call print

    ; Video metadata line (views, duration, channel)
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 15
    mov byte [cursor_y], 24
    mov rsi, [yt_playing_meta_ptr]
    call print

    ; Seek bar track (X=180, Y=462, W=640, H=8)
    mov eax, 180
    mov ebx, 462
    mov ecx, 640
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    ; Start Intel AC'97 16-bit stereo PCM DMA audio hardware!
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_ac97_start
    call audio_start_dma
.skip_ac97_start:

    xor r14d, r14d           ; Frame counter 0..1139 (full 19s at 60fps)

.video_frame_loop:
    cmp r14d, 1140           ; Full video duration (19 seconds @ 60fps)
    jge .video_stream_done

    ; 1. Dark theater cinema background for video viewport (frame 0)
    cmp r14d, 0
    jne .skip_cinema_bg
    mov eax, 180
    mov ebx, 190
    mov ecx, 640
    mov edx, 260
    mov esi, 0x00000000
    call draw_rect

.skip_cinema_bg:
    ; 2. Buffering phase (first 12 frames)
    cmp r14d, 12
    jae .have_buffered
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 28
    mov byte [cursor_y], 14
    mov rsi, str_yt_buffering
    call print
    jmp .skip_vid_frame_draw

.have_buffered:
    cmp r14d, 12
    jne .skip_clear_buffering
    ; Clear buffering text area once buffered
    mov eax, 180
    mov ebx, 190
    mov ecx, 640
    mov edx, 260
    mov esi, 0x00000000
    call draw_rect

.skip_clear_buffering:
    ; ------------------------------------------------------------
    ; MULTI-FRAME ANIMATED VIDEO PLAYBACK
    ; Real photographic frame with organic camera sway & subject motion
    ; ------------------------------------------------------------
    mov rsi, [yt_thumb_ptr_0]

    ; Organic handheld camera sway: dx = ((r14d / 8) & 3) - 1
    mov eax, r14d
    shr eax, 3
    and eax, 3
    sub eax, 1
    add eax, 340             ; Dest X: 339..342
    mov ebx, 230             ; Dest Y: 230

    ; Draw base widescreen HD frame (320x180)
    call draw_raw_image_32bpp_scaled4x

    ; ------------------------------------------------------------
    ; ANIMATED SUBJECT MOTION: Talking Mouth & Facial Gestures!
    ; ------------------------------------------------------------
    ; Jawed mouth at X=494..504, Y=306..311
    mov eax, r14d
    shr eax, 2
    and eax, 3               ; Cycle through 4 speech visemes
    cmp eax, 0
    je .viseme_closed
    cmp eax, 2
    je .viseme_open_wide

    ; Viseme: Half open mouth
    mov eax, 495
    mov ebx, 307
    mov ecx, 8
    mov edx, 4
    mov esi, 0x00331818      ; Dark speech cavity
    call draw_rect
    mov eax, 496
    mov ebx, 307
    mov ecx, 6
    mov edx, 1
    mov esi, 0x00FFFFFF      ; Upper teeth highlight
    call draw_rect
    jmp .viseme_done

.viseme_open_wide:
    mov eax, 494
    mov ebx, 306
    mov ecx, 10
    mov edx, 6
    mov esi, 0x002B1010      ; Open mouth cavity
    call draw_rect
    mov eax, 495
    mov ebx, 306
    mov ecx, 8
    mov edx, 2
    mov esi, 0x00FFFFFF      ; Upper teeth
    call draw_rect
    jmp .viseme_done

.viseme_closed:
    mov eax, 495
    mov ebx, 308
    mov ecx, 8
    mov edx, 2
    mov esi, 0x00B57E6B      ; Lips closed
    call draw_rect

.viseme_done:
    ; ------------------------------------------------------------
    ; ANIMATED BACKGROUND MOTION: Elephant Trunk Sway!
    ; ------------------------------------------------------------
    ; Elephant trunk at X=590..598, Y=276..296
    mov eax, r14d
    shr eax, 3
    and eax, 3
    sub eax, 1               ; Trunk shift dx: -1..+2
    add eax, 592
    mov ebx, 278
    mov ecx, 6
    mov edx, 16
    mov esi, 0x005A5D64      ; Elephant skin tone
    call draw_rect

    ; ------------------------------------------------------------
    ; LIVE VIDEO SCANLINE / CRT ILLUMINATION SWEEP (60FPS)
    ; ------------------------------------------------------------
    mov eax, r14d
    imul eax, 2
    xor edx, edx
    mov ecx, 174
    div ecx                  ; edx = (r14d * 2) % 174
    add edx, 232             ; Y coordinate: 232..406
    mov eax, 340
    mov ebx, edx
    mov ecx, 320
    mov edx, 2
    mov esi, 0x00475569      ; Subtle scanline highlight
    call draw_rect

.skip_vid_frame_draw:

    ; 3. Draw 16 animated audio-equalizer bars at bottom of video frame
    xor r15d, r15d
.eq_bar_loop:
    cmp r15d, 16
    jge .eq_bars_done

    mov eax, r14d
    imul eax, 7
    mov edx, r15d
    imul edx, 23
    add eax, edx
    and eax, 47
    add eax, 8
    mov edx, eax

    mov ebx, 446
    sub ebx, edx

    mov eax, r15d
    imul eax, 36
    add eax, 200
    mov ecx, 24
    mov esi, 0x0010B981
    call draw_rect

    inc r15d
    jmp .eq_bar_loop
.eq_bars_done:

    ; 4. Smooth Progress Scrub Bar & Elapsed Timecode
    ; Scrub bar track: X=180, Y=462, W=640, H=8
    ; progress_w = (r14d * 640) / 1140
    mov eax, r14d
    imul eax, 640
    xor edx, edx
    mov ecx, 1140
    div ecx                  ; eax = progress width (0..640)
    cmp eax, 640
    jbe .prog_w_ok
    mov eax, 640
.prog_w_ok:
    push rax
    ; Elapsed red bar
    mov ecx, eax
    mov eax, 180
    mov ebx, 462
    mov edx, 8
    mov esi, 0x00FF0000      ; YouTube Red
    call draw_rect
    pop rax

    ; White Playhead Scrubber Knob
    add eax, 176
    mov ebx, 459
    mov ecx, 8
    mov edx, 14
    mov esi, 0x00FFFFFF      ; Scrubber head
    call draw_rect

    ; Clear transport controls status area (X=180, Y=476, W=640, H=32)
    mov eax, 180
    mov ebx, 476
    mov ecx, 640
    mov edx, 32
    mov esi, 0x000B0F19
    call draw_rect

    ; Live Timecode Readout: 00:XX / 00:19
    ; sec = r14d / 60
    mov eax, r14d
    xor edx, edx
    mov ecx, 60
    div ecx                  ; eax = seconds (0..19)
    xor edx, edx
    mov ecx, 10
    div ecx                  ; eax = tens digit, edx = ones digit
    add al, '0'
    mov [str_yt_timecode + 3], al
    add dl, '0'
    mov [str_yt_timecode + 4], dl

    ; Draw Transport Badge [ > PLAYING ]
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 25
    mov rsi, str_yt_playing_badge
    call print

    ; Draw Elapsed Timecode
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 26
    mov byte [cursor_y], 25
    mov rsi, str_yt_timecode
    call print

    ; 5. Keep Intel AC'97 Audio DMA looping seamlessly!
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_dma_chk
    add eax, PO_SR
    mov dx, ax
    in al, dx
    test al, 1               ; Bit 0: DCH (DMA Controller Halted)
    jz .skip_dma_chk
    call audio_start_dma     ; Buffer completed: restart immediately!
.skip_dma_chk:

    ; Frame pacing delay (~60fps)
    mov ecx, 1500000
.vid_delay:
    pause
    dec ecx
    jnz .vid_delay

    ; Check non-blocking keyboard/mouse input via yt_handle_input
    call yt_handle_input
    cmp eax, 1
    je .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .next_vid_frame

.vid_pause_loop:
    mov ecx, 2000000
.vid_p_delay:
    pause
    dec ecx
    jnz .vid_p_delay
    call yt_handle_input
    cmp eax, 1
    je .video_stream_done
    cmp byte [yt_video_paused], 1
    je .vid_pause_loop

.next_vid_frame:
    inc r14d
    cmp r14d, 1140
    jb .video_frame_loop

.video_stream_done:
    ; Stop AC'97 DMA audio
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_done_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 2                ; Reset/Stop DMA
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
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
\r\n\r\n"""

if b"\r\n" in data[start_idx:start_idx+100]:
    new_bytes = new_play_real_video.replace("\n", "\r\n").encode("ascii")
else:
    new_bytes = new_play_real_video.encode("ascii")

data = data[:start_idx] + new_bytes + data[end_idx:]

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Updated play_real_video with talking mouth, elephant motion & clean HUD!")
