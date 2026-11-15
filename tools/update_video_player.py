import sys

with open("kernel.asm", "rb") as f:
    data = f.read()

# 1. Update data section: replace video_melody_divisors with timecode & playing badge strings
old_melody = b"""video_melody_divisors:
    dw 2281, 1811, 1522, 1140, 1522, 1811, 1355, 1140"""
new_melody = b"""str_yt_timecode:       db "00:00 / 00:19",0
str_yt_playing_badge:  db "[ > PLAYING ]",0"""

# Check CRLF vs LF
if old_melody in data:
    data = data.replace(old_melody, new_melody, 1)
    print("Replaced video_melody_divisors (LF)")
else:
    old_melody_crlf = old_melody.replace(b"\n", b"\r\n")
    new_melody_crlf = new_melody.replace(b"\n", b"\r\n")
    if old_melody_crlf in data:
        data = data.replace(old_melody_crlf, new_melody_crlf, 1)
        print("Replaced video_melody_divisors (CRLF)")
    else:
        print("ERROR: video_melody_divisors not found!")
        sys.exit(1)

# 2. Trim input buffer: from 128 to 64 bytes
old_input = b"input:\r\n\r\n    times 128 db 0"
new_input = b"input:\r\n\r\n    times 64 db 0"
if old_input in data:
    data = data.replace(old_input, new_input, 1)
    print("Trimmed input buffer (CRLF)")
else:
    old_input_lf = old_input.replace(b"\r\n", b"\n")
    new_input_lf = new_input.replace(b"\r\n", b"\n")
    if old_input_lf in data:
        data = data.replace(old_input_lf, new_input_lf, 1)
        print("Trimmed input buffer (LF)")
    else:
        print("Warning: input buffer pattern not found, skipping trim")

# 3. Replace play_real_video and yt_handle_input up to REGISTER FILE IN NOVAFS HELPER
start_marker = b"play_real_video:"
end_marker = b"; ============================================================\r\n; REGISTER FILE IN NOVAFS HELPER"
if end_marker not in data:
    end_marker = b"; ============================================================\n; REGISTER FILE IN NOVAFS HELPER"

start_idx = data.find(start_marker)
end_idx = data.find(end_marker)

assert start_idx != -1, "start_marker not found"
assert end_idx != -1, "end_marker not found"

new_engine = """play_real_video:
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

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FF0000
    mov byte [cursor_x], 15
    mov byte [cursor_y], 8
    mov rsi, str_video_stream_header
    call print
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, [yt_playing_title_ptr]
    call print

    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 15
    mov byte [cursor_y], 24
    mov rsi, [yt_playing_meta_ptr]
    call print

    ; Transport status indicator [ > PLAYING ]
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 26
    mov rsi, str_yt_playing_badge
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

    ; 1. Dark theater cinema background for video viewport (drawn on frame 0)
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
    ; MULTI-SHOT DYNAMIC VIDEO FRAME PLAYBACK
    ; Changes shots/scenes across time and animates live camera motion!
    ; ------------------------------------------------------------
    ; Select scene keyframe based on current playback progress:
    ; 0..239: Shot 1 (yt_thumb_ptr_0) - Jawed talking in front of elephants
    ; 240..479: Shot 2 (yt_thumb_ptr_1) - Elephants moving trunks
    ; 480..719: Shot 3 (yt_thumb_ptr_2) - Wide zoo enclosure perspective
    ; 720..959: Shot 4 (yt_thumb_ptr_0) - Close-up: "really really long trunks"
    ; 960..1139: Shot 5 (yt_thumb_ptr_1) - Elephants turning in sunlight
    mov rsi, [yt_thumb_ptr_0]
    mov eax, r14d
    cmp eax, 240
    jb .got_scene_thumb
    cmp eax, 480
    jb .scene_shot2
    cmp eax, 720
    jb .scene_shot3
    cmp eax, 960
    jb .got_scene_thumb
    jmp .scene_shot2

.scene_shot2:
    mov rsi, [yt_thumb_ptr_1]
    jmp .got_scene_thumb

.scene_shot3:
    mov rsi, [yt_thumb_ptr_2]

.got_scene_thumb:
    ; Organic handheld camera sway: dx = ((r14d / 8) & 3) - 1
    mov eax, r14d
    shr eax, 3
    and eax, 3
    sub eax, 1
    add eax, 340             ; Dest X: 339..342
    mov ebx, 230             ; Dest Y: 230

    ; Draw the widescreen video frame (320x180)
    call draw_raw_image_32bpp_scaled4x

    ; Live Video Scanline / CRT illumination highlight
    ; A luminous scan bar that smoothly sweeps down the video at 60fps
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

    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 23
    mov byte [cursor_y], 26
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
    mov ebx, 140
    mov ecx, 680
    mov edx, 380
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
yt_video_paused: db 0

; ------------------------------------------------------------
; yt_handle_input:
; Wires keyboard & mouse clicks to YouTube player:
;   - Space / Pause Button: toggles playback, sends 0x01 (PAUSE) / 0x02 (RESUME)
;   - Escape / Close [X]: sends 0x00 (STOP), clears canvas, returns EAX=1
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
    test byte [mouse_byte0], 1   ; Check left mouse button
    jz .input_continue

    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    ; Close [X] Button (X=800..840, Y=140..170)
    cmp eax, 800
    jb .check_pause_btn
    cmp eax, 840
    ja .check_pause_btn
    cmp ebx, 140
    jb .check_pause_btn
    cmp ebx, 170
    jbe .do_close_player

.check_pause_btn:
    ; Pause/Play Button (X=170..260, Y=450..490)
    cmp eax, 170
    jb .input_continue
    cmp eax, 260
    ja .input_continue
    cmp ebx, 450
    jb .input_continue
    cmp ebx, 490
    jbe .toggle_pause_play

.input_continue:
    xor eax, eax
    ret

.toggle_pause_play:
    xor byte [yt_video_paused], 1
    cmp byte [yt_video_paused], 1
    je .do_pause
    ; Resuming: write 1 to AC'97 PO_CR
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_resume_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 1                ; Run bit = 1 (Resume)
    out dx, al
.skip_resume_dma:
    mov al, 0x02              ; RESUME command byte
    call serial_send_char
    xor eax, eax
    ret

.do_pause:
    ; Pausing: write 0 to AC'97 PO_CR
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_pause_dma
    add eax, PO_CR
    mov dx, ax
    xor al, al               ; Run bit = 0 (Pause)
    out dx, al
.skip_pause_dma:
    call speaker_stop
    mov al, 0x01              ; PAUSE command byte
    call serial_send_char
    xor eax, eax
    ret

.do_close_player:
    ; Stop AC'97 DMA
    mov eax, [audio_bm]
    test eax, eax
    jz .skip_stop_dma
    add eax, PO_CR
    mov dx, ax
    mov al, 2                ; Reset controller
    out dx, al
.skip_stop_dma:
    call speaker_stop
    mov al, 0x00              ; STOP/CLOSE command byte
    call serial_send_char
    call clear_video_region
    mov byte [yt_video_paused], 0
    mov eax, 1
    ret
\r\n\r\n"""

# Match line endings of original file
if b"\r\n" in data[start_idx:start_idx+100]:
    new_engine_bytes = new_engine.replace("\n", "\r\n").encode("ascii")
else:
    new_engine_bytes = new_engine.encode("ascii")

data = data[:start_idx] + new_engine_bytes + data[end_idx:]

with open("kernel.asm", "wb") as f:
    f.write(data)

print("Successfully replaced play_real_video & yt_handle_input!")
