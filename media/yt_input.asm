; ============================================================
; media/yt_input.asm
; Input handling for NovaOS Media / YouTube Video & Audio Player
; Wires keyboard & mouse clicks to yt_handle_input:
;   - Space / Pause/Play button: toggles playback, pauses audio DMA,
;     sends PAUSE byte (0x01) over TCP/serial socket to relay server.
;   - Escape / Close [X] button: stops audio DMA, closes TCP socket,
;     clears video region, and returns to main OS shell/desktop.
; ============================================================

[bits 64]
DEFAULT ABS

global yt_handle_input
global yt_video_paused
global clear_video_region

extern ac97_pause_dma
extern ac97_resume_dma
extern ac97_stop_dma
extern serial_send_char
extern mouse_x
extern mouse_y
extern mouse_buttons
extern draw_rect

section .data
align 4
yt_video_paused: db 0

section .text

; ------------------------------------------------------------
; clear_video_region: Clears video playback canvas to desktop theme
; Video canvas: X=160, Y=140, W=680, H=380
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
    mov esi, 0x000F172A        ; NovaOS Shell dark slate background
    call draw_rect

    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------
; yt_handle_input:
; Checks keyboard scancode / ASCII and mouse clicks
; Returns: EAX = 0 (continue playing)
;          EAX = 1 (exit player to OS shell/desktop)
; ------------------------------------------------------------
yt_handle_input:
    push rbx
    push rcx
    push rdx

    ; 1. Check keyboard status
    in al, 0x64                ; KBD_STATUS
    test al, 1
    jz .check_mouse_click

    ; Check if mouse byte waiting on 0x60
    test al, 0x20
    jnz .consume_mouse_byte

    in al, 0x60                ; KBD_DATA
    test al, 0x80              ; Ignore key release
    jnz .check_mouse_click

    ; Check Escape (scancode 0x01) -> Close video player
    cmp al, 0x01
    je .do_close_player

    ; Check Spacebar (scancode 0x39) -> Toggle Pause/Play
    cmp al, 0x39
    je .toggle_pause_play

    jmp .check_mouse_click

.consume_mouse_byte:
    in al, 0x60
    jmp .check_mouse_click

.check_mouse_click:
    ; 2. Check mouse button clicks
    cmp byte [mouse_buttons], 0
    je .input_continue

    ; Mouse is clicked! Check coordinates
    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    ; Check Close [X] Button (X=800..840, Y=140..170)
    cmp eax, 800
    jb .check_pause_btn
    cmp eax, 840
    ja .check_pause_btn
    cmp ebx, 140
    jb .check_pause_btn
    cmp ebx, 170
    jbe .do_close_player

.check_pause_btn:
    ; Check Pause/Play Button (X=170..260, Y=450..490)
    cmp eax, 170
    jb .input_continue
    cmp eax, 260
    ja .input_continue
    cmp ebx, 450
    jb .input_continue
    cmp ebx, 490
    jbe .toggle_pause_play

.input_continue:
    xor eax, eax               ; Continue playing
    pop rdx
    pop rcx
    pop rbx
    ret

.toggle_pause_play:
    cmp byte [yt_video_paused], 1
    je .do_resume

    ; Pause: stop DMA, send 0x01 over TCP/serial socket
    mov byte [yt_video_paused], 1
    call ac97_pause_dma
    mov al, 0x01              ; PAUSE command byte
    call serial_send_char
    jmp .input_continue

.do_resume:
    ; Resume: start DMA, send 0x02 over TCP/serial socket
    mov byte [yt_video_paused], 0
    call ac97_resume_dma
    mov al, 0x02              ; RESUME command byte
    call serial_send_char
    jmp .input_continue

.do_close_player:
    ; Close: stop DMA, send 0x00, clear video region, return to shell
    call ac97_stop_dma
    mov al, 0x00              ; STOP/CLOSE command byte
    call serial_send_char
    call clear_video_region
    mov byte [yt_video_paused], 0
    mov eax, 1                ; Signal player exit to shell/desktop
    pop rdx
    pop rcx
    pop rbx
    ret
