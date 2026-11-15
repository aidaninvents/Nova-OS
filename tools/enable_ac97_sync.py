with open("kernel.asm", "rb") as f:
    data = f.read()

crlf = b"\r\n" in data
def nl(s: str) -> bytes:
    return (s.replace("\n", "\r\n") if crlf else s).encode("ascii")

old_block = """    ; Initialize PIT Ch0 snapshot for exact 15.00 FPS (79,545 PIT ticks / frame)
    call pit_read_ch0
    mov [yt_last_pit], ax

    xor r14d, r14d           ; Frame index 0..283"""

new_block = """    xor r14d, r14d           ; Frame index 0..283"""

old_wait = """    ; Frame Pacer: wait until 79,545 PIT ticks (66.67ms = 15fps) elapsed since yt_last_pit
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
    jmp .hd_frame_loop"""

new_wait = """    ; AC'97 Hardware Lip-Sync (PO_CIV * 3 + (19200 - PO_PICB) / 6400)
    mov r15d, 1500000        ; Safety spin bound (~20-30ms fallback)
.hd_sync_loop:
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .hd_check_ac97

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
    jmp .hd_next_frame

.hd_check_ac97:
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .hd_no_hw_sync
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1               ; DCH halted?
    jnz .hd_no_hw_sync

    ; Compute live audio frame from PO_CIV & PO_PICB
    lea edx, [ebx + PO_CIV]
    in al, dx
    movzx ecx, al
    imul ecx, 3              ; base frame = CIV * 3
    lea edx, [ebx + PO_PICB]
    in ax, dx
    movzx eax, ax
    cmp eax, 19200
    jae .hd_sub_ok
    mov edx, 19200
    sub edx, eax
    mov eax, edx
    xor edx, edx
    mov esi, 6400
    div esi
    add ecx, eax             ; ecx = live AC'97 hardware video frame
.hd_sub_ok:
    cmp ecx, r14d
    ja .hd_jump_synced
    pause
    dec r15d
    jnz .hd_sync_loop
    jmp .hd_next_frame

.hd_jump_synced:
    mov r14d, ecx
    jmp .hd_frame_loop

.hd_no_hw_sync:
    mov ecx, 1200000
.hd_fb_dly:
    pause
    dec ecx
    jnz .hd_fb_dly

.hd_next_frame:
    inc r14d
    jmp .hd_frame_loop"""

old_pit_fn = """; ------------------------------------------------------------
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
    ret"""

assert nl(old_block) in data, "old_block missing"
assert nl(old_wait) in data, "old_wait missing"
assert nl(old_pit_fn) in data, "old_pit_fn missing"

data = data.replace(nl(old_block), nl(new_block), 1)
data = data.replace(nl(old_wait), nl(new_wait), 1)
data = data.replace(nl(old_pit_fn), b"", 1)
data = data.replace(nl("yt_last_pit:       dw 0\n"), b"", 1)

with open("kernel.asm", "wb") as f:
    f.write(data)
print("Switched play_real_video to AC'97 hardware PO_CIV/PO_PICB lip-sync!")
