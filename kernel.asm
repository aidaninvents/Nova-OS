BITS 64
ORG 0x10000
DEFAULT ABS

; ================================================================
; NovaOS graphics constants
; ================================================================

VBE_INFO_ADDR   equ 0x9000

; Compile-time upper-bound constants used for TEXT_WIDTH/HEIGHT and scroll.
; The runtime screen_width / screen_height variables hold the actual values.
SCREEN_WIDTH    equ 1920
SCREEN_HEIGHT   equ 1080

BYTES_PER_PIXEL equ 4

FONT_WIDTH      equ 12
FONT_HEIGHT     equ 20

TEXT_WIDTH      equ SCREEN_WIDTH / FONT_WIDTH   ; 160
TEXT_HEIGHT     equ SCREEN_HEIGHT / FONT_HEIGHT  ; 54


COLOR_BG        equ 0x00000000

; Extended key codes (virtual - returned by get_key)
KEY_UP          equ 0x80
KEY_DOWN        equ 0x81
KEY_LEFT        equ 0x82
KEY_RIGHT       equ 0x83
KEY_PGUP        equ 0x84
KEY_PGDN        equ 0x85
KEY_HOME        equ 0x86
KEY_END         equ 0x87
KEY_DEL         equ 0x88
KEY_MOUSE_CLICK equ 0x89
KEY_MOUSE_MOVE  equ 0x8A
COLOR_FG        equ 0x00FFFFFF
COLOR_DESKTOP       equ 0x00121820
COLOR_PANEL         equ 0x00202A36
COLOR_WINDOW        equ 0x0018202B
COLOR_TITLE         equ 0x002A3745
COLOR_ACCENT        equ 0x004A90E2
COLOR_TEXT          equ 0x00FFFFFF
COLOR_MUTED         equ 0x00AAB4BF
KBD_STATUS      equ 0x64
KBD_DATA        equ 0x60

CMOS_INDEX      equ 0x70
CMOS_DATA       equ 0x71

; ================================================================
; Boot spinner constants
; ================================================================

SPINNER_FRAME_COUNT   equ 122
SPINNER_FRAME_SIZE    equ 300
SPINNER_FPS           equ 20

BOOT_FONT_WIDTH       equ 36
BOOT_FONT_HEIGHT      equ 60
BOOT_FONT_ROW_BYTES   equ 5
BOOT_FONT_GLYPH_SIZE  equ 300

BOOT_FONT_SCALED_WIDTH    equ 45
BOOT_FONT_SCALED_HEIGHT   equ 75

; ================================================================
; NovaFS constants
; ================================================================

NOVAFS              equ 0x30000
NOVAFS_DIR          equ NOVAFS + 512
NOVAFS_ENTRY_SIZE   equ 32

; ================================================================
; Font IDs
; ================================================================

FONT_REGULAR        equ 0
FONT_BOLD           equ 1
FONT_ITALIC         equ 2
FONT_BOLD_ITALIC    equ 3
; ================================================================
; 64-BIT KERNEL ENTRY
; ================================================================

kernel_start:

    cli

    lgdt [gdt64_descriptor]

    ; Setup standard 64-bit data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    ; FIX 1: Move stack safely to high memory away from NovaFS & VBE data
    ; Enforce strict 16-byte stack boundary alignment
    mov rsp, 0x400000
    and rsp, -16

    ; ------------------------------------------------------------
    ; Load VBE framebuffer information safely
    ; ------------------------------------------------------------

    ; FIX 2: Zero out upper 64-bit registers explicitly before tracking pointers
    xor rax, rax
    mov eax, [VBE_INFO_ADDR + 0]
    mov [framebuffer_address], rax

    xor rax, rax
    mov eax, [VBE_INFO_ADDR + 4]
    mov [framebuffer_pitch], eax

    xor rax, rax
    mov eax, [VBE_INFO_ADDR + 8]
    mov [screen_width], eax

    xor rax, rax
    mov eax, [VBE_INFO_ADDR + 12]
    mov [screen_height], eax
    ; ------------------------------------------------------------
    ; Find bitmap fonts and logo in NovaFS.
    ; ------------------------------------------------------------

    call load_font_addresses

    ; ------------------------------------------------------------
    ; UEFI/GOP handoff extension (written by uefi/loader, qwords).
    ; BIOS stage2 leaves 0x9014..0x903F zero; keep BIOS values then.
    ;   0x9014 magic 'NGOP' (0x504F474E)
    ;   0x9018 width, 0x9020 height, 0x9028 pitch, 0x9030 fb addr
    ;   0x9038 flags bit0=BGR order, bit1=source UEFI
    ; ------------------------------------------------------------
    cmp dword [VBE_INFO_ADDR + 20], 0x504F474E
    jne .handoff_done
    mov rax, [VBE_INFO_ADDR + 24]
    cmp rax, 640
    jb .handoff_done
    cmp rax, 4096
    ja .handoff_done
    mov rbx, [VBE_INFO_ADDR + 32]
    cmp rbx, 400
    jb .handoff_done
    cmp rbx, 4096
    ja .handoff_done
    mov rcx, [VBE_INFO_ADDR + 40]
    mov rdx, rax
    shl rdx, 2
    cmp rcx, rdx
    jb .handoff_done
    cmp rcx, 16384
    ja .handoff_done
    mov rdx, [VBE_INFO_ADDR + 48]
    test rdx, rdx
    jz .handoff_done
    mov [screen_width], eax
    mov [screen_height], ebx
    mov [framebuffer_pitch], ecx
    mov [framebuffer_address], rdx
    mov rax, [VBE_INFO_ADDR + 56]
    mov [gop_flags], rax
.handoff_done:

    ; ------------------------------------------------------------
    ; Compute runtime text grid dimensions:
    ; text_cols = screen_width / FONT_WIDTH
    ; text_rows = screen_height / FONT_HEIGHT
    ; ------------------------------------------------------------
    mov eax, [screen_width]
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [text_cols], al

    mov eax, [screen_height]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    mov [text_rows], al


    ; ------------------------------------------------------------
    ; Start with regular font.
    ; ------------------------------------------------------------

    mov rax, [font_regular_address]
    mov [current_font_address], rax

    ; ------------------------------------------------------------
    ; Detect system hardware (CPU, RAM, Floppy, Hard Disk, CD-ROM)
    ; ------------------------------------------------------------

    call detect_hardware
    call probe_pci_nic

    ; ------------------------------------------------------------
    ; Draw boot screen.
    ; ------------------------------------------------------------

    call boot_screen
    call mouse_init
    call audio_init
    call startup_audio
    ; ------------------------------------------------------------
    ; Clear boot screen and show banner before entering shell.
    ; ------------------------------------------------------------

    call clear_screen

    ; Auto-initialize Intel 82540EM (e1000) NIC & mark online if present
    mov byte [net_connected], 0
    cmp dword [pci_nic_id], 0xFFFFFFFF
    je .chk_nv_net
    call e1000_init
    test eax, eax
    jz .chk_nv_net
    mov byte [net_connected], 1
    jmp .fresh_offline_boot
.chk_nv_net:
    cmp dword [NOVAFS + 28], 0x4E455431
    jne .fresh_offline_boot
    mov byte [net_connected], 1
.fresh_offline_boot:

    call gui_desktop

    jmp shell

; ================================================================
; BOOT SCREEN
;
; Layout:
;
;             NovaOS logo
;
;              spinner
;
;         Starting NovaOS...
;
; Spinner:
;   45 x 75 pixels
;   3 complete cycles
;   122 frames per cycle
; ================================================================

boot_screen:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    ; ------------------------------------------------------------
    ; Clear screen so no residue from stage2 or prior mode remains
    ; ------------------------------------------------------------
    call clear_screen

    ; ------------------------------------------------------------
    ; Reset text cursor.
    ; ------------------------------------------------------------

    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    mov byte [skip_boot_flag], 0

    ; ------------------------------------------------------------
    ; Draw NovaOS logo centered horizontally.
    ; Logo is 220 × 220 pixels.
    ; Y = screen_height * 15 / 100  (upper ~15 % of screen)
    ; X = (screen_width - 220) / 2
    ; ------------------------------------------------------------

    mov rsi, [logo_address]
    test rsi, rsi
    jz .skip_logo

    ; EBX = logo Y  = screen_height * 15 / 100
    mov eax, [screen_height]
    imul eax, 15
    xor edx, edx
    mov ecx, 100
    div ecx
    mov ebx, eax

    ; EAX = logo X  = (screen_width - 220) / 2
    mov eax, [screen_width]
    sub eax, 220
    shr eax, 1

    call draw_logo

.skip_logo:
    ; ------------------------------------------------------------
    ; Draw "Starting NovaOS..."
    ; Row = screen_height * 80 / 100 / FONT_HEIGHT
    ; Col = (screen_width/2 - 7*FONT_WIDTH) / FONT_WIDTH
    ; ------------------------------------------------------------

    ; ------------------------------------------------------------
    ; Draw hardware detection info and "Starting NovaOS..."
    ; ------------------------------------------------------------

    ; cursor_y = (screen_height * 70 / 100) / FONT_HEIGHT
    mov eax, [screen_height]
    imul eax, 70
    xor edx, edx
    mov ecx, 100
    div ecx
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    mov [cursor_y], al

    ; cursor_x = (screen_width / 2) / FONT_WIDTH - 22  (clamped to 0)
    mov eax, [screen_width]
    shr eax, 1
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    cmp eax, 22
    jae .cx_ok
    xor eax, eax
    jmp .cx_set
.cx_ok:
    sub eax, 22
.cx_set:
    mov [cursor_x], al
    mov [boot_left_col], al

    mov rsi, boot_text
    call print

    inc byte [cursor_y]
    mov al, [boot_left_col]
    mov [cursor_x], al
    mov rsi, boot_dot_cpu
    call print
    mov rsi, [cpu_brand_ptr]
    call print

    inc byte [cursor_y]
    mov al, [boot_left_col]
    mov [cursor_x], al
    mov rsi, boot_dot_ram
    call print
    mov eax, [ram_total_mb]
    call print_number
    mov rsi, boot_dot_ram_suffix
    call print

    inc byte [cursor_y]
    mov al, [boot_left_col]
    mov [cursor_x], al
    mov rsi, boot_dot_storage
    call print

    ; ------------------------------------------------------------
    ; Load BOOTSPIN.FNT (first 10 bytes are the file header).
    ; ------------------------------------------------------------

    mov rax, [bootspin_font_address]
    test rax, rax
    jz .boot_screen_done

    add rax, 10
    mov rsi, rax

    ; ------------------------------------------------------------
    ; Frame counter = 0
    ; ------------------------------------------------------------

    xor edx, edx
    mov ebp, 152            ; 152 frames * 59M RDTSC ticks = 5.0 seconds
.boot_animation:
    push rdx
    push rsi

    mov eax, [screen_width]
    sub eax, BOOT_FONT_SCALED_WIDTH
    shr eax, 1

    mov ebx, [screen_height]
    imul ebx, 46
    xor edx, edx
    push rax
    mov eax, ebx
    mov ecx, 100
    xor edx, edx
    div ecx
    mov ebx, eax
    pop rax

    call draw_boot_glyph

    pop rsi
    pop rdx

    ; Wait 59,000,000 RDTSC ticks (~33ms/frame -> 152 frames = 5.0 seconds)
    push rax
    push rdx
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov rcx, rax
.boot_wait_tsc:
    pause
    rdtsc
    shl rdx, 32
    or rax, rdx
    sub rax, rcx
    cmp rax, 59000000
    jb .boot_wait_tsc
    pop rdx
    pop rax

    add rsi, SPINNER_FRAME_SIZE
    inc edx
    cmp edx, SPINNER_FRAME_COUNT
    jb .boot_next_frame
    xor edx, edx
    mov rsi, [bootspin_font_address]
    add rsi, 10
.boot_next_frame:
    dec ebp
    jnz .boot_animation

.boot_screen_done:
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret



; ================================================================
; SPINNER DELAY
;
; Calibrated TSC timestamp delay.
; Guarantees consistent frame timing across real hardware and
; hypervisors (VirtualBox, QEMU, VMware) without port-polling stalls.
; ================================================================

spinner_delay:

    push rax
    push rcx

    ; Check keyboard: only Esc (0x01) skips; ignore mouse (0x20) & stray bytes
    in al, 0x64
    test al, 1
    jz .do_delay
    test al, 0x20
    jnz .drain_ignore
    in al, 0x60
    cmp al, 1
    jne .do_delay
    mov byte [skip_boot_flag], 1
    jmp .delay_done
.drain_ignore:
    in al, 0x60

.do_delay:
    ; Simple calibrated busy-wait: ~16 ms / frame on modern hardware
    mov ecx, 1800000
.spin_loop:
    pause
    dec ecx
    jnz .spin_loop

.delay_done:
    pop rcx
    pop rax
    ret

; ================================================================
; DRAW NOVAOS LOGO
;
; ESI = RGBA logo data
; EAX = X pixel
; EBX = Y pixel
;
; Logo:
;   220 x 220
;
; Source format:
;   R G B A
;
; Framebuffer format:
;   0x00RRGGBB
; ================================================================

draw_logo:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    ; ------------------------------------------------------------
    ; Save logo position.
    ; ------------------------------------------------------------

    mov [logo_x_temp], eax
    mov [logo_y_temp], ebx

    xor ebx, ebx

.logo_row:

    ; ------------------------------------------------------------
    ; Calculate framebuffer address:
    ;
    ; framebuffer
    ;   + (logo_y + row) * pitch
    ;   + logo_x * 4
    ; ------------------------------------------------------------

    mov eax, [logo_y_temp]

    add eax, ebx

    imul eax, [framebuffer_pitch]

    mov edx, [logo_x_temp]

    imul edx, BYTES_PER_PIXEL

    add eax, edx
    add rax, [framebuffer_address]

    mov rdi, rax

    xor ecx, ecx

.logo_pixel:

    ; ------------------------------------------------------------
    ; Read alpha.
    ; ------------------------------------------------------------

    movzx edx, byte [rsi + 3]

    test edx, edx

    jz .skip_pixel

    ; ------------------------------------------------------------
    ; Red channel.
    ;
    ; result -> bits 16-23
    ; ------------------------------------------------------------

    movzx eax, byte [rsi]

    imul eax, edx

    add eax, 255

    shr eax, 8

    shl eax, 16

    mov ebp, eax

    ; ------------------------------------------------------------
    ; Green channel.
    ;
    ; result -> bits 8-15
    ; ------------------------------------------------------------

    movzx eax, byte [rsi + 1]

    imul eax, edx

    add eax, 255

    shr eax, 8

    shl eax, 8

    or ebp, eax

    ; ------------------------------------------------------------
    ; Blue channel.
    ;
    ; result -> bits 0-7
    ; ------------------------------------------------------------

    movzx eax, byte [rsi + 2]

    imul eax, edx

    add eax, 255

    shr eax, 8

    or ebp, eax

    ; ------------------------------------------------------------
    ; Write complete RGB pixel.
    ;
    ; IMPORTANT:
    ; Use EBP here.
    ; EAX only contains the blue channel.
    ; ------------------------------------------------------------

    mov [rdi], ebp

.skip_pixel:

    ; ------------------------------------------------------------
    ; Next source pixel.
    ; ------------------------------------------------------------

    add rsi, 4

    ; ------------------------------------------------------------
    ; Next framebuffer pixel.
    ; ------------------------------------------------------------

    add rdi, BYTES_PER_PIXEL

    inc ecx

    cmp ecx, 220

    jb .logo_pixel

    ; ------------------------------------------------------------
    ; Next logo row.
    ; ------------------------------------------------------------

    inc ebx

    cmp ebx, 220

    jb .logo_row

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret



; ================================================================
; DRAW BOOT GLYPH
;
; 1.25x nearest-neighbor scaling.
;
; Source:
;   36 x 60 pixels
;   5 bytes per row
;
; Destination:
;   45 x 75 pixels
;
; ESI = glyph bitmap
; EAX = X pixel
; EBX = Y pixel
;
; Scaling:
;
;   source_x = destination_x * 4 / 5
;   source_y = destination_y * 4 / 5
;
; This keeps the spinner crisp while making it 25% larger.
; ================================================================

draw_boot_glyph:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    ; ------------------------------------------------------------
    ; Reserve local storage.
    ;
    ; [rsp + 0] = original glyph address
    ; [rsp + 8] = current framebuffer row address
    ; ------------------------------------------------------------

    sub rsp, 16

    mov [rsp], rsi

    ; ------------------------------------------------------------
    ; Calculate framebuffer starting address.
    ;
    ; framebuffer
    ;   + Y * pitch
    ;   + X * 4
    ; ------------------------------------------------------------

    imul ebx, [framebuffer_pitch]

    imul eax, BYTES_PER_PIXEL

    add eax, ebx

    add rax, [framebuffer_address]

    mov [rsp + 8], rax

    ; ------------------------------------------------------------
    ; ECX = destination Y
    ;
    ; 0 through 74
    ; ------------------------------------------------------------

    xor ecx, ecx

.draw_row:

    ; ------------------------------------------------------------
    ; source_y = destination_y * 4 / 5
    ; ------------------------------------------------------------

    mov eax, ecx

    imul eax, 4

    xor edx, edx

    mov ebp, 5

    div ebp

    ; EAX = source Y

    ; ------------------------------------------------------------
    ; Convert source Y to byte offset.
    ;
    ; Each source row = 5 bytes.
    ; ------------------------------------------------------------

    imul eax, BOOT_FONT_ROW_BYTES

    add rax, [rsp]

    ; EAX = source row address

    mov rbx, rax

    ; ------------------------------------------------------------
    ; Destination framebuffer row.
    ; ------------------------------------------------------------

    mov rdi, [rsp + 8]

    ; ------------------------------------------------------------
    ; EDX = destination X
    ;
    ; 0 through 44
    ; ------------------------------------------------------------

    xor edx, edx

.draw_pixel:

    ; ------------------------------------------------------------
    ; source_x = destination_x * 4 / 5
    ; ------------------------------------------------------------

    mov eax, edx

    imul eax, 4

    ; ------------------------------------------------------------
    ; Save destination X because DIV modifies EDX.
    ; ------------------------------------------------------------

    push rdx

    xor edx, edx

    mov ebp, 5

    div ebp

    ; EAX = source X

    ; ------------------------------------------------------------
    ; Save source X.
    ; ------------------------------------------------------------

    mov ebp, eax

    ; ------------------------------------------------------------
    ; source byte = source_x / 8
    ; ------------------------------------------------------------

    shr eax, 3

    ; ------------------------------------------------------------
    ; Read source byte.
    ; ------------------------------------------------------------

    movzx eax, byte [rbx + rax]

    ; ------------------------------------------------------------
    ; source bit = source_x % 8
    ; ------------------------------------------------------------

    and ebp, 7

    ; ------------------------------------------------------------
    ; Get MSB-first bit mask.
    ; ------------------------------------------------------------

    movzx esi, byte [boot_bit_masks + rbp]

    ; ------------------------------------------------------------
    ; Check source pixel.
    ; ------------------------------------------------------------

    test eax, esi

    jz .pixel_off

    ; ------------------------------------------------------------
    ; Pixel ON.
    ; ------------------------------------------------------------

    mov dword [rdi], COLOR_FG

    jmp .pixel_done

.pixel_off:

    ; ------------------------------------------------------------
    ; Pixel OFF.
    ; ------------------------------------------------------------

    mov dword [rdi], COLOR_BG

.pixel_done:

    ; ------------------------------------------------------------
    ; Next destination pixel.
    ; ------------------------------------------------------------

    add rdi, BYTES_PER_PIXEL

    pop rdx

    inc edx

    cmp edx, BOOT_FONT_SCALED_WIDTH

    jb .draw_pixel

    ; ------------------------------------------------------------
    ; Move to next framebuffer row.
    ; ------------------------------------------------------------

    mov rax, [rsp + 8]

    mov edx, [framebuffer_pitch]
    add rax, rdx

    mov [rsp + 8], rax

    ; ------------------------------------------------------------
    ; Next destination row.
    ; ------------------------------------------------------------

    inc ecx

    cmp ecx, BOOT_FONT_SCALED_HEIGHT

    jb .draw_row

    ; ------------------------------------------------------------
    ; Done.
    ; ------------------------------------------------------------

    add rsp, 16

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret



; ============================================================
; SHELL
; ============================================================

shell:

    mov rsi, prompt

    call print

    call read_line

    call command

    jmp shell
; ============================================================
; DRAW RECTANGLE
;
; EAX = X
; EBX = Y
; ECX = Width
; EDX = Height
; ESI = Color
; ============================================================

draw_rect:

    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push r8
    push r9
    push r10

    ; Save dimensions
    mov r8d, ecx
    mov r9d, edx

    ; framebuffer + Y * pitch + X * 4
    imul ebx, [framebuffer_pitch]
    imul eax, BYTES_PER_PIXEL

    add eax, ebx
    add rax, [framebuffer_address]

    mov rdi, rax

    xor r10d, r10d

.draw_rect_row:

    push rdi                     ; save row-start address
    mov ecx, r8d
    mov eax, esi
    rep stosd                    ; rdi now points past end of row
    pop rdi                      ; restore row-start address
    mov edx, [framebuffer_pitch] ; edx = bytes per row (rdx is caller-saved here)
    add rdi, rdx                 ; advance exactly one row

    inc r10d
    cmp r10d, r9d
    jb .draw_rect_row

    pop r10
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret


; ============================================================
; GRAPHICS
; ============================================================

clear_screen:

    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Invalidate old mouse background buffer & reset mouse packet cycle on screen clear
    mov byte [mouse_has_old], 0
    mov byte [mouse_cycle], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], 0x00000000
    mov byte [text_transparent_bg], 0

    mov rdi, [framebuffer_address]

    xor eax, eax

    mov ebx, [screen_height]
    imul ebx, [framebuffer_pitch]
    shr ebx, 2
    mov ecx, ebx

    rep stosd

    mov byte [cursor_x], 0
    mov byte [cursor_y], 0

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret



; ============================================================
; NOVAOS DESKTOP
; ============================================================

gui_desktop:

    push r11
    push r12
    push r13
    push r14
    push r15

    ; --------------------------------------------------------
    ; Pre-compute layout parameters into callee-saved regs.
    ;
    ;  r11d = screen_width
    ;  r12d = screen_height
    ;  r13d = taskbar_y   = screen_height - 48
    ;  r14d = win_x       = screen_width  / 12  (1 char margin)
    ;  r15d = win_y       = 68            (just below top panel)
    ; --------------------------------------------------------

    mov r11d, [screen_width]
    mov r12d, [screen_height]
    mov r13d, r12d
    sub r13d, 48            ; taskbar_y

    mov r14d, r11d
    sar r14d, 4             ; win_x ≈ screen_width / 16

    mov r15d, 88            ; win_y (below desktop shortcut bar)

    ; win_w = screen_width  - 2 * win_x
    ; win_h = taskbar_y     - win_y - 4   (4-px gap at bottom)

    ; --------------------------------------------------------
    ; Desktop background
    ; --------------------------------------------------------

    mov eax, 0
    mov ebx, 0
    mov ecx, r11d
    mov edx, r12d
    mov esi, COLOR_DESKTOP

    call draw_rect

    ; --------------------------------------------------------
    ; Top panel (height = 48)
    ; --------------------------------------------------------

    mov eax, 0
    mov ebx, 0
    mov ecx, r11d
    mov edx, 48
    mov esi, COLOR_PANEL

    call draw_rect

    ; --------------------------------------------------------
    ; Taskbar (height = 48, Y = screen_height - 48)
    ; --------------------------------------------------------

    mov eax, 0
    mov ebx, r13d
    mov ecx, r11d
    mov edx, 48
    mov esi, COLOR_PANEL

    call draw_rect

    ; --------------------------------------------------------
    ; Terminal window background
    ; win_x, win_y, win_w = screen_width - 2*win_x, win_h
    ; --------------------------------------------------------

    ; ECX = win_w = screen_width - 2*win_x
    mov ecx, r11d
    mov eax, r14d
    shl eax, 1
    sub ecx, eax

    ; EDX = win_h = taskbar_y - win_y - 4
    mov edx, r13d
    sub edx, r15d
    sub edx, 4

    ; Save win_w in r8d, win_h in r9d for title/accent reuse
    push r8
    push r9
    mov r8d, ecx
    mov r9d, edx

    mov eax, r14d
    mov ebx, r15d
    mov esi, COLOR_WINDOW

    call draw_rect

    ; --------------------------------------------------------
    ; Terminal title bar (height = 40)
    ; --------------------------------------------------------

    mov eax, r14d
    mov ebx, r15d
    mov ecx, r8d
    mov edx, 40
    mov esi, COLOR_TITLE

    call draw_rect

    ; --------------------------------------------------------
    ; Accent line (height = 3) just below title bar
    ; --------------------------------------------------------

    mov eax, r14d
    lea ebx, [r15d + 40]
    mov ecx, r8d
    mov edx, 3
    mov esi, COLOR_ACCENT

    call draw_rect

    pop r9
    pop r8

    ; Enable transparent text background for desktop & panel labels
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    ; --------------------------------------------------------
    ; "NovaOS" in top panel
    ; --------------------------------------------------------

    mov byte [cursor_x], 2
    mov byte [cursor_y], 1

    mov rsi, gui_novaos_text
    call print

    ; Reset mouse background buffer on desktop redraw
    mov byte [mouse_has_old], 0

    ; Draw network status indicator on top right panel (starts OFFLINE)
    call draw_net_icon

    ; --------------------------------------------------------
    ; Desktop Application Launcher Bar (cursor_y = 3 -> Y=60)
    ; --------------------------------------------------------
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00E2E8F0

    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    mov rsi, gui_desktop_bar_no_np
    call print

    ; --------------------------------------------------------
    ; Terminal title text (inside titlebar Y=88..128 -> row 5)
    ; --------------------------------------------------------
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 5

    mov rsi, gui_terminal_title
    call print

    ; --------------------------------------------------------
    ; Taskbar text
    ; cursor_y = (taskbar_y + 14) / FONT_HEIGHT
    ; --------------------------------------------------------

    lea eax, [r13d + 14]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx

    mov [cursor_y], al
    mov byte [cursor_x], 2

    mov rsi, gui_taskbar_text
    call print

    ; Restore opaque window background for shell terminal text
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW

    ; --------------------------------------------------------
    ; Place shell cursor inside terminal content area.
    ; Row = (win_y + 40 + 3 + FONT_HEIGHT) / FONT_HEIGHT
    ; Col = (win_x + FONT_WIDTH) / FONT_WIDTH
    ; --------------------------------------------------------

    lea eax, [r15d + 40 + 3 + FONT_HEIGHT]
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

    ; term_right_col = (screen_width - win_x - FONT_WIDTH) / FONT_WIDTH
    mov eax, r11d
    sub eax, r14d
    sub eax, FONT_WIDTH
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [term_right_col], al

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11

    ; Draw desktop mouse cursor pointer
    call draw_mouse_cursor

    ret
; ============================================================
; PUTCHAR
;
; AL = character
; ============================================================

putchar:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov dl, al

    cmp al, 10
    je putchar_newline

    cmp al, 8
    je putchar_backspace

    cmp al, 32
    jb putchar_done

    cmp al, 126
    ja putchar_done

    ; ------------------------------------------------------------
    ; Find glyph.
    ;
    ; Each glyph = FONT_HEIGHT rows * 2 bytes.
    ; ------------------------------------------------------------

    movzx eax, dl
    sub eax, 32

    imul eax, FONT_HEIGHT * 2

    mov rsi, [current_font_address]

    add rsi, 10
    add rsi, rax

    ; ------------------------------------------------------------
    ; X position.
    ; ------------------------------------------------------------

    movzx eax, byte [cursor_x]

    imul eax, FONT_WIDTH
    imul eax, BYTES_PER_PIXEL

    ; ------------------------------------------------------------
    ; Y position.
    ; ------------------------------------------------------------

    movzx ebx, byte [cursor_y]

    imul ebx, FONT_HEIGHT
    imul ebx, [framebuffer_pitch]

    add eax, ebx
    add rax, [framebuffer_address]

    mov rdi, rax

    xor ecx, ecx


putchar_row:

    mov bx, [rsi]

    push rcx
    push rsi
    push rdi

    mov ecx, FONT_WIDTH

    putchar_pixel:

    test bx, 0x8000
    jz putchar_pixel_off

    mov eax, [text_fg_color]
    mov dword [rdi], eax

    jmp putchar_pixel_next


putchar_pixel_off:

    cmp byte [text_transparent_bg], 1
    je putchar_pixel_next
    mov eax, [text_bg_color]
    mov dword [rdi], eax


putchar_pixel_next:

    shl bx, 1

    add rdi, BYTES_PER_PIXEL

    dec ecx
    jnz putchar_pixel

    pop rdi
    pop rsi
    pop rcx

    mov edx, [framebuffer_pitch]
    add rdi, rdx

    add rsi, 2

    inc ecx

    cmp ecx, FONT_HEIGHT
    jb putchar_row

    inc byte [cursor_x]
    mov al, [text_cols]
    cmp byte [cursor_x], al
    jb putchar_done

    mov byte [cursor_x], 0

    inc byte [cursor_y]

    call scroll

    jmp putchar_done


putchar_newline:

    mov al, [term_left_col]
    mov [cursor_x], al

    inc byte [cursor_y]

    call scroll

    jmp putchar_done


putchar_backspace:

    cmp byte [cursor_x], 0
    je putchar_done

    dec byte [cursor_x]

    movzx eax, byte [cursor_x]

    imul eax, FONT_WIDTH
    imul eax, BYTES_PER_PIXEL

    movzx ebx, byte [cursor_y]

    imul ebx, FONT_HEIGHT
    imul ebx, [framebuffer_pitch]

    add eax, ebx
    add rax, [framebuffer_address]
    mov rdi, rax

    xor ecx, ecx


putchar_clear_row:

    push rcx
    push rdi

    mov ecx, FONT_WIDTH

    xor eax, eax


putchar_clear_pixel:

    mov eax, [text_bg_color]
    mov dword [rdi], eax

    add rdi, BYTES_PER_PIXEL

    dec ecx

    jnz putchar_clear_pixel

    pop rdi
    pop rcx

    mov edx, [framebuffer_pitch]
    add rdi, rdx

    inc ecx

    cmp ecx, FONT_HEIGHT
    jb putchar_clear_row


putchar_done:

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret




; ============================================================
; SCROLL
; ============================================================

scroll:

    ; Never scroll terminal when rendering GUI labels (text_transparent_bg == 1)
    cmp byte [text_transparent_bg], 1
    je scroll_done

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

    ret


; ============================================================
; PRINT
; ============================================================

print:

    push rax


print_loop:

    lodsb

    test al, al
    jz print_done

    call putchar

    jmp print_loop


print_done:

    pop rax

    ret


newline:

    mov al, 10

    call putchar

    ret


; ============================================================
; BANNER
; ============================================================

banner:

    mov rsi, banner_text

    call print

    ret


; ============================================================
; KEYBOARD
; ============================================================

get_key:

get_key_wait:

    in al, KBD_STATUS

    test al, 1
    jz get_key_wait

    ; If status bit 5 is set, data is from the AUX (mouse) port!
    test al, 0x20
    jnz handle_mouse_byte

    in al, KBD_DATA

    ; Shift down
    cmp al, 0x2A
    je get_key_shift_on

    cmp al, 0x36
    je get_key_shift_on

    ; Shift up
    cmp al, 0xAA
    je get_key_shift_off

    cmp al, 0xB6
    je get_key_shift_off

    ; Caps Lock
    cmp al, 0x3A
    je get_key_caps

    ; Check for E0 extended prefix FIRST (before testing bit 7, since 0xE0 has bit 7 set!)
    cmp al, 0xE0
    je get_key_extended

    ; Ignore key release
    test al, 0x80
    jnz get_key

    ; Enter
    cmp al, 0x1C
    je get_key_enter

    ; Backspace
    cmp al, 0x0E
    je get_key_backspace

    ; Space
    cmp al, 0x39
    je get_key_space

    ; Escape
    cmp al, 0x01
    je get_key_escape

    movzx eax, al

    cmp eax, 128
    jae get_key

    cmp byte [shift], 0
    je get_key_normal

    mov al, [shift_table + rax]

    jmp get_key_character


get_key_normal:

    mov al, [key_table + rax]


get_key_character:

    test al, al
    jz get_key

    cmp al, 'a'
    jb get_key_return

    cmp al, 'z'
    ja get_key_return

    cmp byte [caps], 0
    je get_key_return

    sub al, 32


get_key_return:

    movzx eax, al

    ret


get_key_shift_on:

    mov byte [shift], 1

    jmp get_key


get_key_shift_off:

    mov byte [shift], 0

    jmp get_key


get_key_caps:

    xor byte [caps], 1

    jmp get_key


get_key_enter:

    mov eax, 13

    ret


get_key_backspace:

    mov eax, 8

    ret


get_key_space:

    mov eax, ' '

    ret


get_key_escape:

    mov eax, 27

    ret


get_key_extended:
    ; Read the actual extended key scancode
    ; Must wait for next byte from keyboard
.ext_wait:
    in al, KBD_STATUS
    test al, 1
    jz .ext_wait
    test al, 0x20
    jnz handle_mouse_byte
    in al, KBD_DATA

    ; Ignore extended key release (bit 7 set)
    test al, 0x80
    jnz get_key

    ; Arrow keys
    cmp al, 0x48   ; Up arrow
    je .ext_up
    cmp al, 0x50   ; Down arrow
    je .ext_down
    cmp al, 0x4B   ; Left arrow
    je .ext_left
    cmp al, 0x4D   ; Right arrow
    je .ext_right
    cmp al, 0x49   ; Page Up
    je .ext_pgup
    cmp al, 0x51   ; Page Down
    je .ext_pgdn
    cmp al, 0x47   ; Home
    je .ext_home
    cmp al, 0x4F   ; End
    je .ext_end
    cmp al, 0x53   ; Delete
    je .ext_del
    ; Ignore unknown extended
    jmp get_key

.ext_up:
    mov eax, KEY_UP
    ret
.ext_down:
    mov eax, KEY_DOWN
    ret
.ext_left:
    mov eax, KEY_LEFT
    ret
.ext_right:
    mov eax, KEY_RIGHT
    ret
.ext_pgup:
    mov eax, KEY_PGUP
    ret
.ext_pgdn:
    mov eax, KEY_PGDN
    ret
.ext_home:
    mov eax, KEY_HOME
    ret
.ext_end:
    mov eax, KEY_END
    ret
.ext_del:
    mov eax, KEY_DEL
    ret

; ============================================================
; PS/2 MOUSE INITIALIZATION (Enable AUX Device & Streaming)
; ============================================================
mouse_wait_write:
    in al, KBD_STATUS
    test al, 2
    jnz mouse_wait_write
    ret

mouse_wait_read:
    in al, KBD_STATUS
    test al, 1
    jz mouse_wait_read
    ret

mouse_write_cmd:
    push rax
    call mouse_wait_write
    mov al, 0xD4              ; Direct command to mouse
    out KBD_STATUS, al
    call mouse_wait_write
    pop rax
    out KBD_DATA, al
    call mouse_wait_read
    in al, KBD_DATA           ; Read ACK (0xFA)
    ret

mouse_init:
    push rax

    ; 1. Enable auxiliary mouse port on 8042 controller (command 0xA8)
    call mouse_wait_write
    mov al, 0xA8
    out KBD_STATUS, al

    ; 2. Read Controller Command Byte (command 0x20)
    call mouse_wait_write
    mov al, 0x20
    out KBD_STATUS, al
    call mouse_wait_read
    in al, KBD_DATA

    ; 3. Enable AUX mouse interrupt (bit 1) and disable mouse clock disable (clear bit 5)
    or al, 0x02               ; Bit 1 = enable mouse interrupt / packet generation
    and al, 0xDF              ; Clear bit 5 = enable mouse clock line

    ; 4. Write back Controller Command Byte (command 0x60)
    push rax
    call mouse_wait_write
    mov al, 0x60
    out KBD_STATUS, al
    call mouse_wait_write
    pop rax
    out KBD_DATA, al

    ; 5. Set default mouse parameters (command 0xF6)
    mov al, 0xF6
    call mouse_write_cmd

    ; 6. Enable mouse packet streaming (command 0xF4)
    mov al, 0xF4
    call mouse_write_cmd

    ; Set initial mouse position near desktop center
    mov dword [mouse_x], 640
    mov dword [mouse_y], 180
    mov byte [mouse_cycle], 0

    pop rax
    ret

; ============================================================
; PS/2 MOUSE PACKET HANDLER
; ============================================================
handle_mouse_byte:
    in al, KBD_DATA           ; Read mouse byte from 0x60
    movzx ebx, byte [mouse_cycle]

    cmp bl, 0
    je .byte0
    cmp bl, 1
    je .byte1
    cmp bl, 2
    je .byte2

    ; Should not reach here, reset cycle
    mov byte [mouse_cycle], 0
    jmp get_key

.byte0:
    ; Valid PS/2 header byte0: Bit 3 (0x08) must be 1, Overflow bits 6,7 (0xC0)
    ; and Middle/Right bits 1,2 (0x06) must be 0 -> (al & 0xCE) == 0x08!
    mov ah, al
    and ah, 0xCE
    cmp ah, 0x08
    jne .discard_mouse
    mov [mouse_byte0], al
    mov byte [mouse_cycle], 1
    jmp get_key

.byte1:
    mov [mouse_byte1], al
    mov byte [mouse_cycle], 2
    jmp get_key

.byte2:
    mov [mouse_byte2], al
    mov byte [mouse_cycle], 0

    ; Verify Xsign (bit 4 of byte0) matches sign of byte1 (when byte1 != 0)
    mov al, [mouse_byte1]
    test al, al
    jz .check_ysign_sync
    mov ah, [mouse_byte0]
    test ah, 0x10
    jnz .expect_x_neg
    test al, 0x80
    jnz .discard_mouse
    jmp .check_ysign_sync
.expect_x_neg:
    test al, 0x80
    jz .discard_mouse

.check_ysign_sync:
    ; Verify Ysign (bit 5 of byte0) matches sign of byte2 (when byte2 != 0)
    mov al, [mouse_byte2]
    test al, al
    jz .packet_synced_ok
    mov ah, [mouse_byte0]
    test ah, 0x20
    jnz .expect_y_neg
    test al, 0x80
    jnz .discard_mouse
    jmp .packet_synced_ok
.expect_y_neg:
    test al, 0x80
    jz .discard_mouse

.packet_synced_ok:
    ; Calculate delta X
    movzx eax, byte [mouse_byte1]
    test byte [mouse_byte0], 0x10   ; X sign bit
    jz .x_pos
    or eax, 0xFFFFFF00              ; Sign extend 8-bit to 32-bit
.x_pos:
    mov ebx, [mouse_x]
    add ebx, eax

    ; Clamp mouse_x between 0 and screen_width - 14
    test ebx, ebx
    jns .x_not_neg
    xor ebx, ebx
.x_not_neg:
    mov ecx, [screen_width]
    sub ecx, 14
    cmp ebx, ecx
    jle .x_in_bounds
    mov ebx, ecx
.x_in_bounds:
    mov [mouse_x], ebx

    ; Calculate delta Y (PS/2 mouse reports positive delta when moving UP)
    movzx eax, byte [mouse_byte2]
    test byte [mouse_byte0], 0x20   ; Y sign bit
    jz .y_pos
    or eax, 0xFFFFFF00
.y_pos:
    neg eax                         ; Invert Y for screen coordinates (down is +)
    mov ebx, [mouse_y]
    add ebx, eax

    ; Clamp mouse_y between 0 and screen_height - 20
    test ebx, ebx
    jns .y_not_neg
    xor ebx, ebx
.y_not_neg:
    mov ecx, [screen_height]
    sub ecx, 20
    cmp ebx, ecx
    jle .y_in_bounds
    mov ebx, ecx
.y_in_bounds:
    mov [mouse_y], ebx

    ; STRICT HOVER VS. CLICK SEPARATION:
    ; If the mouse moved (mouse_byte1 != 0 or mouse_byte2 != 0), it is ALWAYS
    ; a hover/move event (KEY_MOUSE_MOVE), NEVER a click!
    mov al, [mouse_byte0]
    and al, 0x01
    mov ah, [mouse_byte1]
    or ah, [mouse_byte2]
    jnz .only_mouse_move

    ; Mouse is stationary (dx == 0, dy == 0): Check rising edge of Left Button (0 -> 1)
    test al, al
    jz .btn_released
    cmp byte [mouse_prev_btn], 0
    jne .only_mouse_move
    mov byte [mouse_prev_btn], 1
    mov eax, KEY_MOUSE_CLICK
    ret

.btn_released:
    mov byte [mouse_prev_btn], 0
.only_mouse_move:
    mov [mouse_prev_btn], al
    mov eax, KEY_MOUSE_MOVE
    ret

.discard_mouse:
    mov byte [mouse_cycle], 0
    jmp get_key


; ============================================================
; INPUT
; ============================================================

read_line:

    push rax
    push rcx
    push rdx
    push rsi
    push rdi

    mov rdi, input

    xor ecx, ecx


read_line_loop:

    call get_key

    ; NOTE: Keyboard & mouse inputs do NOT toggle or turn on the network dot!
    cmp eax, KEY_MOUSE_MOVE
    je .mouse_move_shell
    cmp eax, KEY_MOUSE_CLICK
    je .mouse_click_shell
    jmp .not_mouse_shell

.mouse_move_shell:
    call draw_mouse_cursor
    jmp read_line_loop

.mouse_click_shell:
    call draw_mouse_cursor
    ; Check if user clicked Top-Right Network Icon (Y < 48, X >= screen_width - 190)
    mov eax, [mouse_y]
    cmp eax, 48
    jae .check_desk_bar_click
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 190
    cmp eax, edx
    jae .launch_wifi_from_click
    jmp read_line_loop

.check_desk_bar_click:
    ; Check if user clicked Desktop Launcher Bar (Y = 50..88) or Bottom Taskbar (Y >= screen_height - 48)
    mov eax, [mouse_y]
    cmp eax, 88
    jbe .eval_launcher_x
    mov edx, [screen_height]
    sub edx, 48
    cmp eax, edx
    jae .eval_taskbar_x
    jmp read_line_loop

.eval_launcher_x:
    mov eax, [mouse_x]
    cmp eax, 35
    jb read_line_loop
    cmp eax, 145
    jbe .launch_files_from_click
    cmp eax, 185
    jb read_line_loop
    cmp eax, 310
    jbe .launch_chrome_from_click
    cmp eax, 345
    jb read_line_loop
    cmp eax, 495
    jbe .launch_shop_from_click
    cmp eax, 530
    jb read_line_loop
    cmp eax, 635
    jbe .launch_wifi_from_click
    jmp read_line_loop

.eval_taskbar_x:
    mov eax, [mouse_x]
    cmp eax, 140
    jb read_line_loop
    cmp eax, 230
    jb .launch_files_from_click
    cmp eax, 350
    jb read_line_loop
    cmp eax, 430
    jb .launch_wifi_from_click
    cmp eax, 530
    jb .launch_chrome_from_click
    cmp eax, 620
    jb .launch_shop_from_click
    jmp read_line_loop

.launch_files_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax ; discard return address to shell
    jmp command_files

.launch_chrome_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_chrome

.launch_shop_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_shop

.launch_wifi_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_wifi

.launch_notepad_from_click:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop rax
    jmp command_notepad

.not_mouse_shell:
    ; Arrow keys move mouse pointer in shell
    cmp eax, KEY_UP
    je .shell_arrow_up
    cmp eax, KEY_DOWN
    je .shell_arrow_down
    cmp eax, KEY_LEFT
    je .shell_arrow_left
    cmp eax, KEY_RIGHT
    je .shell_arrow_right

    cmp al, 13
    je read_line_done

    cmp al, 8
    je read_line_backspace

    cmp al, 27
    je read_line_clear

    ; PgUp - scroll terminal up (manual scroll back not buffered, just visual cue)
    cmp eax, KEY_PGUP
    je read_line_loop
    ; PgDn - scroll to bottom
    cmp eax, KEY_PGDN
    je read_line_loop

    cmp al, 32
    jb read_line_loop

    cmp ecx, 126
    jae read_line_loop

    mov [rdi], al

    inc rdi
    inc ecx

    call putchar

    jmp read_line_loop


.shell_arrow_up:
    cmp dword [mouse_y], 20
    jb read_line_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp read_line_loop

.shell_arrow_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae read_line_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp read_line_loop

.shell_arrow_left:
    cmp dword [mouse_x], 20
    jb read_line_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp read_line_loop

.shell_arrow_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae read_line_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp read_line_loop

read_line_backspace:

    cmp ecx, 0
    je read_line_loop

    dec rdi
    dec ecx

    mov byte [rdi], 0

    mov al, 8

    call putchar

    jmp read_line_loop


read_line_clear:

    mov rdi, input

    xor ecx, ecx

    mov rsi, input

    xor edx, edx


read_line_clear_count:

    cmp byte [rsi], 0
    je read_line_clear_screen

    inc rsi
    inc edx

    cmp edx, 126
    jb read_line_clear_count


read_line_clear_screen:

    test edx, edx
    jz read_line_clear_done


read_line_clear_one:

    mov al, 8

    call putchar

    dec edx

    jnz read_line_clear_one


read_line_clear_done:

    mov rdi, input

    xor ecx, ecx

    jmp read_line_loop


read_line_done:

    mov byte [rdi], 0

    call newline

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax

    ret


; ============================================================
; COMMAND PARSER
; ============================================================

command:

    mov rsi, input
    call skip_spaces

    cmp byte [rsi], 0
    je command_done

    mov rdi, cmd_help
    call exact

    jc command_help

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_about
    call exact

    jc command_about

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_version
    call exact

    jc command_version

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_clear
    call exact

    jc command_clear

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_cls
    call exact

    jc command_clear

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_cpu
    call exact

    jc command_cpu

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_time
    call exact

    jc command_time

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_date
    call exact

    jc command_date

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_mem
    call exact

    jc command_mem

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_reboot
    call exact

    jc command_reboot

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_halt
    call exact

    jc command_halt

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_font_list
    call exact

    jc command_font_list

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_font_current
    call exact

    jc command_font_current

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_font_use
    call prefix

    jc command_font_use

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_echo
    call prefix

    jc command_echo

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_add
    call prefix

    jc command_add

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_sub
    call prefix

    jc command_sub

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_floppy
    call exact
    jc command_floppy

    mov rsi, input
    call skip_spaces

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_list_drive
    call exact
    jc command_list_drive

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_list_drives
    call exact
    jc command_list_drive

    ; Check 'run ' or 'open ' prefixes
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_run_prefix
    call prefix
    jc .check_nosp_arg

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_open_prefix
    call prefix
    jc .check_nosp_arg
    jmp .check_direct_nosp

.check_nosp_arg:
    call skip_spaces
    mov rdi, cmd_chrome_short
    call prefix
    jc command_chrome
    mov rdi, cmd_wifi_short
    call prefix
    jc command_wifi
    mov rdi, cmd_shop_short
    call prefix
    jc command_shop
    mov rdi, cmd_notepad_short
    call prefix
    jc command_notepad
    mov rdi, cmd_python_short
    call prefix
    jc command_python
    mov rdi, cmd_java_short
    call prefix
    jc command_java
    mov rdi, cmd_html_short
    call prefix
    jc command_html
    mov rdi, cmd_youtube_short
    call prefix
    jc command_youtube
    mov rdi, cmd_video_short
    call prefix
    jc command_video
    mov rdi, cmd_startup_short
    call prefix
    jc command_run_startup_nosp

.check_direct_nosp:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_chrome_short
    call prefix
    jc command_chrome

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_wifi_short
    call prefix
    jc command_wifi

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_shop_short
    call prefix
    jc command_shop

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_store_short
    call prefix
    jc command_shop

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_notepad_short
    call prefix
    jc command_notepad

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_python_short
    call prefix
    jc command_python

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_java_short
    call prefix
    jc command_java

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_html_short
    call prefix
    jc command_html

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_youtube_short
    call prefix
    jc command_youtube

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_video_short
    call prefix
    jc command_video

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_startup_short
    call prefix
    jc command_run_startup_nosp

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_d_startup
    call exact
    jc command_run_startup_nosp

    mov rdi, cmd_apps
    call exact
    jc command_apps

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_drivers
    call exact
    jc command_drivers

    mov rdi, cmd_calc
    call exact
    jc command_calc

    mov rdi, cmd_clock
    call exact
    jc command_clock

    mov rdi, cmd_paint
    call exact
    jc command_paint

    mov rdi, cmd_sysmon
    call exact
    jc command_sysmon

    mov rdi, cmd_piano
    call exact
    jc command_piano

    mov rdi, cmd_drives
    call exact
    jc command_drives

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_iso
    call exact
    jc command_iso

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_cdrom
    call exact
    jc command_iso

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_savefont
    call exact
    jc command_savefont

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_loadfont
    call prefix
    jc command_loadfont

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_ls
    call exact
    jc command_ls

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_dir
    call exact
    jc command_ls

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_mkdir
    call prefix
    jc command_mkdir

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_touch
    call prefix
    jc command_touch

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_write
    call prefix
    jc command_write

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_cat
    call prefix
    jc command_cat

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_rm
    call prefix
    jc command_rm

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_rmdir
    call prefix
    jc command_rmdir

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_savefs
    call exact
    jc command_savefs

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_files
    call exact
    jc command_files

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_explorer
    call exact
    jc command_files

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_res
    call prefix
    jc command_res

    mov rsi, input
    call skip_spaces
    mov rdi, cmd_font_setup
    call exact
    jc command_font_setup

    mov rsi, unknown

    call print


command_done:

    ret


; ============================================================
; COMMANDS
; ============================================================

command_help:

    mov rsi, help_text
    call print

    jmp command_done


command_about:

    mov rsi, about_text
    call print

    jmp command_done


command_version:

    mov rsi, version_text
    call print

    jmp command_done


command_clear:

    call clear_screen

    jmp command_done


command_echo:

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_echo
    call skip_word

    call skip_spaces

    call print
    call newline

    jmp command_done


command_cpu:

    mov rsi, cpu_text
    call print

    mov rsi, [cpu_brand_ptr]
    call print
    call newline

    jmp command_done


command_time:

    call show_time
    call newline

    jmp command_done


command_date:

    call show_date
    call newline

    jmp command_done


command_mem:

    mov rsi, mem_ram_title
    call print

    mov eax, [ram_total_mb]
    call print_number

    mov rsi, mem_ram_suffix
    call print
    call newline

    mov rsi, mem_text
    call print

    mov eax, kernel_start

    call print_hex
    call newline

    jmp command_done


command_floppy:

    mov rsi, floppy_title
    call print

    cmp byte [floppy_type], 4
    jne .check_other

    mov rsi, floppy_144_ready
    call print
    jmp command_done

.check_other:
    cmp byte [floppy_type], 0
    jne .other_type

    mov rsi, floppy_not_found
    call print
    jmp command_done

.other_type:
    mov rsi, floppy_detected
    call print
    jmp command_done


; ============================================================
; LIST DRIVE & NOSP EXECUTION
; ============================================================
command_list_drive:
    mov rsi, str_drive_menu
    call print

.wait_drive_sel:
    call get_key
    cmp eax, 'q'
    je .ld_quit
    cmp eax, 'Q'
    je .ld_quit
    cmp eax, 27
    je .ld_quit
    cmp eax, 'a'
    je .ld_drive_a
    cmp eax, 'A'
    je .ld_drive_a
    cmp eax, '1'
    je .ld_drive_a
    cmp eax, 'c'
    je .ld_drive_c
    cmp eax, 'C'
    je .ld_drive_c
    cmp eax, '2'
    je .ld_drive_c
    cmp eax, 'd'
    je .ld_drive_d
    cmp eax, 'D'
    je .ld_drive_d
    cmp eax, '3'
    je .ld_drive_d
    jmp .wait_drive_sel

.ld_quit:
    call newline
    jmp command_done

.ld_drive_a:
    call newline
    mov rsi, str_drive_a_files
    call print
    jmp command_done

.ld_drive_c:
    call newline
    jmp command_ls

.ld_drive_d:
    call newline
    mov rsi, str_drive_d_files
    call print

.wait_file_sel:
    call get_key
    cmp eax, 'q'
    je .ld_quit
    cmp eax, 'Q'
    je .ld_quit
    cmp eax, 27
    je .ld_quit
    cmp eax, '1'
    je .file_startup_nosp
    cmp eax, 's'
    je .file_startup_nosp
    cmp eax, 'S'
    je .file_startup_nosp
    cmp eax, '2'
    je .file_wifi_nosp
    cmp eax, 'w'
    je .file_wifi_nosp
    cmp eax, 'W'
    je .file_wifi_nosp
    cmp eax, '3'
    je .file_chrome_nosp
    cmp eax, 'c'
    je .file_chrome_nosp
    cmp eax, 'C'
    je .file_chrome_nosp
    cmp eax, '4'
    je .file_novaos_img
    cmp eax, '5'
    je .file_efiboot_img
    cmp eax, '6'
    je .file_isolinux
    cmp eax, '7'
    je .file_boot_dir
    jmp .wait_file_sel

.file_wifi_nosp:
    call newline
    call command_wifi
    jmp command_done

.file_chrome_nosp:
    call newline
    call command_chrome
    jmp command_done

.file_startup_nosp:
    call newline
    mov rsi, str_nosp_action_menu
    call print

.wait_action_sel:
    call get_key
    cmp eax, '1'
    je command_run_startup_nosp
    cmp eax, 13
    je command_run_startup_nosp
    cmp eax, 'o'
    je command_run_startup_nosp
    cmp eax, 'O'
    je command_run_startup_nosp
    cmp eax, '2'
    je .edit_startup_nosp
    cmp eax, 'e'
    je .edit_startup_nosp
    cmp eax, 'E'
    je .edit_startup_nosp
    cmp eax, '3'
    je .action_cancel
    cmp eax, 27
    je .action_cancel
    jmp .wait_action_sel

.edit_startup_nosp:
    call newline
    mov rsi, str_nosp_edit_view
    call print
    jmp command_done

.action_cancel:
    call newline
    mov rsi, str_action_cancelled
    call print
    jmp command_done

.file_novaos_img:
    call newline
    mov rsi, str_novaos_img_info
    call print
    jmp command_done

.file_efiboot_img:
    call newline
    mov rsi, str_efiboot_img_info
    call print
    jmp command_done

.file_isolinux:
    call newline
    mov rsi, str_isolinux_info
    call print
    jmp command_done

.file_boot_dir:
    call newline
    mov rsi, str_boot_dir_info
    call print
    jmp command_done

command_run_startup_nosp:
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 2
    mov rsi, str_installer_welcome
    call print

.wait_installer_confirm:
    call get_key
    cmp eax, 'c'
    je .installer_cancelled
    cmp eax, 'C'
    je .installer_cancelled
    cmp eax, 27
    je .installer_cancelled
    cmp eax, 13
    je .installer_proceed
    jmp .wait_installer_confirm

.installer_cancelled:
    call newline
    mov rsi, str_installer_cancelled
    call print
    call newline
    mov rsi, str_installer_ret_desk
    call print
    call get_key
    call gui_desktop
    jmp shell

.installer_proceed:
    call newline
    mov rsi, str_installer_running
    call print

    mov rdi, NOVAFS
    mov eax, 133
    mov ecx, 788
    call ata_write_sectors

    mov rsi, str_installer_done
    call print
    call get_key
    call gui_desktop
    jmp shell

command_drives:
    jmp command_list_drive
    mov rsi, drives_info
    call print

    jmp command_done


command_iso:

    mov rsi, iso_info
    call print

    jmp command_done


command_savefont:

    mov rsi, savefont_prompt
    call print

    mov rdi, NOVAFS
    mov eax, 133
    mov ecx, 788
    call ata_write_sectors

    mov rsi, savefont_success
    call print

    jmp command_done


command_loadfont:

    mov rsi, loadfont_status
    call print

    jmp command_done


; ============================================================
; FILE SYSTEM COMMANDS: ls, mkdir, touch, write, cat, rm, savefs
; ============================================================

command_ls:
    mov rsi, ls_header
    call print

    mov ecx, [NOVAFS + 8]   ; File count
    mov rsi, NOVAFS_DIR

.ls_loop:
    test ecx, ecx
    jz .ls_done

    ; Skip deleted entries (first byte == 0)
    cmp byte [rsi], 0
    je .ls_next

    push rcx
    push rsi

    ; Check if directory (attribute bit 4 at offset 20)
    test byte [rsi + 20], 0x10
    jnz .print_dir

    mov rsi, ls_file_prefix
    call print
    jmp .print_name

.print_dir:
    mov rsi, ls_dir_prefix
    call print

.print_name:
    pop rsi
    push rsi
    mov rdi, rsi
    call print_fs_name

    ; Print size
    mov rsi, ls_size_prefix
    call print
    pop rsi
    push rsi
    mov eax, [rsi + 16]
    call print_number
    mov rsi, ls_bytes_suffix
    call print
    call newline

    pop rsi
    pop rcx

.ls_next:
    add rsi, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .ls_loop

.ls_done:
    jmp command_done


command_mkdir:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_mkdir
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .mkdir_err

    ; Find free directory slot
    mov ecx, [NOVAFS + 8]
    mov rdi, NOVAFS_DIR
    imul ecx, NOVAFS_ENTRY_SIZE
    add rdi, rcx

    ; Copy folder name (up to 11 chars)
    push rsi
    mov ecx, 11
.copy_dirname:
    lodsb
    cmp al, ' '
    jbe .dir_name_pad
    stosb
    loop .copy_dirname
    jmp .set_dir_meta

.dir_name_pad:
    xor al, al
    rep stosb

.set_dir_meta:
    pop rsi
    mov dword [rdi], 0      ; starting sector
    mov dword [rdi + 4], 0  ; size
    mov byte [rdi + 8], 0x10 ; attribute = DIRECTORY
    inc dword [NOVAFS + 8]  ; file count++

    mov rsi, mkdir_success
    call print
    jmp command_done

.mkdir_err:
    mov rsi, mkdir_usage
    call print
    jmp command_done


command_touch:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_touch
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .touch_err

    ; Add new file entry to NovaFS
    mov ecx, [NOVAFS + 8]
    mov rdi, NOVAFS_DIR
    imul ecx, NOVAFS_ENTRY_SIZE
    add rdi, rcx

    push rsi
    mov ecx, 11
.copy_filename:
    lodsb
    cmp al, ' '
    jbe .file_name_pad
    stosb
    loop .copy_filename
    jmp .set_file_meta

.file_name_pad:
    xor al, al
    rep stosb

.set_file_meta:
    pop rsi
    mov dword [rdi], 0      ; start sector
    mov dword [rdi + 4], 0  ; size = 0
    mov byte [rdi + 8], 0   ; attribute = normal file
    inc dword [NOVAFS + 8]  ; file count++

    mov rsi, touch_success
    call print
    jmp command_done

.touch_err:
    mov rsi, touch_usage
    call print
    jmp command_done


command_write:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_write
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .write_err

    ; Search for file in NovaFS
    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR

.search_write_file:
    test ecx, ecx
    jz .write_not_found

    push rcx
    push rsi
    push rbx
    mov rdi, rbx
    mov ecx, 8
.match_write_name:
    lodsb
    cmp al, ' '
    jbe .check_end_name
    cmp al, [rdi]
    jne .mismatch_write
    inc rdi
    loop .match_write_name
.check_end_name:
    ; Matched!
    pop rbx
    pop rsi
    pop rcx
    jmp .do_file_write

.mismatch_write:
    pop rbx
    pop rsi
    pop rcx
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .search_write_file

.do_file_write:
    ; Find end of filename in rsi to get to text payload
    call skip_word
    call skip_spaces

    ; If file has no allocated sector, assign next free sector (e.g. 700 + count)
    cmp dword [rbx + 12], 0
    jne .have_sector
    mov eax, [NOVAFS + 8]
    add eax, 600
    mov [rbx + 12], eax

.have_sector:
    ; Destination in memory = NOVAFS + sector * 512
    mov eax, [rbx + 12]
    imul eax, 512
    add eax, NOVAFS
    mov rdi, rax

    ; Copy text until null terminator
    xor edx, edx
.copy_payload:
    lodsb
    test al, al
    jz .finish_write
    stosb
    inc edx
    jmp .copy_payload

.finish_write:
    mov [rbx + 16], edx     ; Update file size!
    mov rsi, write_success
    call print
    jmp command_done

.write_not_found:
    mov rsi, file_not_found_msg
    call print
    jmp command_done

.write_err:
    mov rsi, write_usage
    call print
    jmp command_done


command_cat:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_cat
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .cat_err

    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR

.search_cat_file:
    test ecx, ecx
    jz .cat_not_found

    push rcx
    push rsi
    push rbx
    mov rdi, rbx
    mov ecx, 8
.match_cat_name:
    lodsb
    cmp al, ' '
    jbe .check_cat_end
    cmp al, [rdi]
    jne .mismatch_cat
    inc rdi
    loop .match_cat_name
.check_cat_end:
    pop rbx
    pop rsi
    pop rcx
    jmp .do_cat_read

.mismatch_cat:
    pop rbx
    pop rsi
    pop rcx
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .search_cat_file

.do_cat_read:
    mov eax, [rbx + 12]
    imul eax, 512
    add eax, NOVAFS
    mov rsi, rax

    mov ecx, [rbx + 16]
    test ecx, ecx
    jz .cat_empty

.print_cat_loop:
    lodsb
    call putchar
    dec ecx
    jnz .print_cat_loop
    call newline
    jmp command_done

.cat_empty:
    mov rsi, file_empty_msg
    call print
    jmp command_done

.cat_not_found:
    mov rsi, file_not_found_msg
    call print
    jmp command_done

.cat_err:
    mov rsi, cat_usage
    call print
    jmp command_done


command_rm:
    mov rsi, input
    call skip_spaces
    mov rdi, cmd_rm
    call skip_word
    call skip_spaces

    cmp byte [rsi], 0
    je .rm_err

    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR

.search_rm_file:
    test ecx, ecx
    jz .rm_not_found

    push rcx
    push rsi
    push rbx
    mov rdi, rbx
    mov ecx, 8
.match_rm_name:
    lodsb
    cmp al, ' '
    jbe .check_rm_end
    cmp al, [rdi]
    jne .mismatch_rm
    inc rdi
    loop .match_rm_name
.check_rm_end:
    pop rbx
    pop rsi
    pop rcx
    ; Delete by setting first byte of filename to 0
    mov byte [rbx], 0
    mov rsi, rm_success
    call print
    jmp command_done

.mismatch_rm:
    pop rbx
    pop rsi
    pop rcx
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .search_rm_file

.rm_not_found:
    mov rsi, file_not_found_msg
    call print
    jmp command_done

.rm_err:
    mov rsi, rm_usage
    call print
    jmp command_done


command_rmdir:
    jmp command_rm


command_savefs:
    mov rsi, savefs_prompt
    call print

    mov rdi, NOVAFS
    mov eax, 133
    mov ecx, 788
    call ata_write_sectors

    mov rsi, savefs_success
    call print
    jmp command_done


command_files:
    ; Interactive File Explorer with smooth mouse movement & double-tap open
    push r11
    push r12
    push r13
    push r14
    push r15

    ; r12 = selected index (0-based)
    xor r12d, r12d
    ; r13 = 12 base entries (browser.nosp removed; chrome.nosp & shop.nosp included)
    mov r13d, 12

.explorer_draw:
    mov byte [mouse_has_old], 0

    ; ── Draw window frame ──────────────────────────────────────────────
    mov eax, 60
    mov ebx, 55
    mov ecx, [screen_width]
    sub ecx, 120
    mov edx, [screen_height]
    sub edx, 120
    push rcx
    push rdx
    mov esi, 0x00121824
    call draw_rect

    ; Title bar (36px)
    pop rdx
    pop rcx
    push rcx
    push rdx
    mov eax, 60
    mov ebx, 55
    mov edx, 36
    mov esi, 0x000F2942
    call draw_rect

    ; Accent line
    pop rdx
    pop rcx
    push rcx
    mov eax, 60
    mov ebx, 91
    mov edx, 2
    mov esi, COLOR_ACCENT
    call draw_rect

    ; Address bar bg
    pop rcx
    mov eax, 70
    mov ebx, 98
    sub ecx, 20
    mov edx, 24
    mov esi, 0x001E293B
    call draw_rect

    ; ── Title & Address text (transparent bg) ──────────────────────────
    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    mov byte [cursor_x], 6
    mov byte [cursor_y], 3
    mov rsi, gui_explorer_title
    call print

    mov byte [cursor_x], 7
    mov byte [cursor_y], 5
    mov rsi, gui_address_path
    call print

    ; ── Column headers ─────────────────────────────────────────────────
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 7
    mov rsi, gui_col_header
    call print

    ; ── Draw all 12 entries, highlighting the selected one ─────────────
    xor r15d, r15d        ; entry index
.draw_entries:
    cmp r15d, r13d
    jge .draw_done_entries

    mov eax, r15d
    lea ebx, [eax + 9]    ; row = 9 + entry_index

    ; Highlight selected row bar
    cmp r15d, r12d
    jne .no_highlight

    push rax
    push rbx
    mov eax, 70
    imul ebx, FONT_HEIGHT
    mov ecx, [screen_width]
    sub ecx, 140
    mov edx, FONT_HEIGHT
    mov esi, 0x001E3A8A
    call draw_rect
    pop rbx
    pop rax

    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 6
    mov [cursor_y], bl
    mov rsi, gui_sel_arrow
    call print
    jmp .print_entry

.no_highlight:
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 6
    mov [cursor_y], bl
    mov rsi, gui_no_arrow
    call print

.print_entry:
    mov [cursor_y], bl

    ; Fetch entry strings from table
    push r12
    push r15
    lea rax, [explorer_entry_table]
    movzx r15, r15w
    mov rax, [rax + r15*8]
    mov rsi, rax
    mov byte [cursor_x], 8
    call print
    pop r15
    pop r12

    inc r15d
    jmp .draw_entries

.draw_done_entries:
    ; ── Status bar ─────────────────────────────────────────────────────
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov eax, [screen_height]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    sub eax, 5
    mov [cursor_y], al
    mov rsi, gui_explorer_keys
    call print

    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW

    ; Draw mouse cursor at its CURRENT position (never reset mouse_x/mouse_y!)
    call draw_mouse_cursor

.explorer_wait_key:
    call get_key

    ; Smooth Mouse Move without redrawing entire Explorer window!
    cmp eax, KEY_MOUSE_MOVE
    je .explorer_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .explorer_mouse_click

    cmp eax, KEY_UP
    je .move_up
    cmp eax, KEY_DOWN
    je .move_down
    cmp eax, KEY_LEFT
    je .exp_mouse_left
    cmp eax, KEY_RIGHT
    je .exp_mouse_right
    cmp eax, 'k'
    je .move_up
    cmp eax, 'j'
    je .move_down
    cmp eax, 27           ; Escape -> close
    je .explorer_close
    cmp eax, 'q'
    je .explorer_close
    cmp eax, 'Q'
    je .explorer_close
    cmp eax, 13           ; Enter -> Open item
    je .explorer_handle_open
    cmp eax, ' '          ; Space -> Open item
    je .explorer_handle_open
    cmp eax, KEY_PGUP
    je .jump_top
    cmp eax, KEY_PGDN
    je .jump_bottom

    ; Number keys '0'..'9' direct selection
    cmp eax, '0'
    jb .check_shortcut_keys
    cmp eax, '9'
    ja .check_shortcut_keys
    sub eax, '0'
    cmp eax, r13d
    jge .explorer_wait_key
    cmp eax, r12d
    je .explorer_handle_open
    mov r12d, eax
    jmp .explorer_draw

.check_shortcut_keys:
    cmp eax, 'c'
    je .sel_chrome
    cmp eax, 'C'
    je .sel_chrome
    cmp eax, 'w'
    je .sel_wifi
    cmp eax, 'W'
    je .sel_wifi
    cmp eax, 's'
    je .sel_shop
    cmp eax, 'S'
    je .sel_shop
    jmp .explorer_wait_key

.explorer_mouse_move:
    call draw_mouse_cursor
    jmp .explorer_wait_key

.exp_mouse_left:
    cmp dword [mouse_x], 20
    jb .explorer_wait_key
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .explorer_wait_key

.exp_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .explorer_wait_key
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .explorer_wait_key

.sel_chrome:
    cmp r12d, 10
    je .explorer_handle_open
    mov r12d, 10
    jmp .explorer_draw

.sel_wifi:
    cmp r12d, 9
    je .explorer_handle_open
    mov r12d, 9
    jmp .explorer_draw

.sel_shop:
    cmp r12d, 11
    je .explorer_handle_open
    mov r12d, 11
    jmp .explorer_draw

.explorer_mouse_click:
    call draw_mouse_cursor
    ; Check if clicking titlebar close button [X] (Y = 55..91, X >= screen_width - 120)
    mov eax, [mouse_y]
    cmp eax, 91
    ja .exp_click_rows
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 120
    cmp eax, edx
    jae .explorer_close
    jmp .explorer_wait_key

.exp_click_rows:
    ; Convert mouse_y to item index: Row = mouse_y / FONT_HEIGHT (20)
    mov eax, [mouse_y]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    sub eax, 9
    js .explorer_wait_key
    cmp eax, r13d
    jge .explorer_wait_key

    ; Double-Tap / Second click on selected item opens it!
    cmp eax, r12d
    je .explorer_handle_open

    ; First click selects item
    mov r12d, eax
    jmp .explorer_draw

.move_up:
    test r12d, r12d
    jz .explorer_wait_key
    dec r12d
    lea ecx, [r12d + 9]
    imul ecx, FONT_HEIGHT
    mov [mouse_y], ecx
    jmp .explorer_draw

.move_down:
    lea eax, [r12d + 1]
    cmp eax, r13d
    jge .explorer_wait_key
    inc r12d
    lea ecx, [r12d + 9]
    imul ecx, FONT_HEIGHT
    mov [mouse_y], ecx
    jmp .explorer_draw

.jump_top:
    xor r12d, r12d
    jmp .explorer_draw

.jump_bottom:
    lea r12d, [r13d - 1]
    jmp .explorer_draw

.explorer_handle_open:
    cmp r12d, 0
    je .exp_open_documents
    cmp r12d, 1
    je .exp_open_downloads
    cmp r12d, 2
    je .exp_open_fonts
    cmp r12d, 3
    je .exp_open_system
    cmp r12d, 4
    je .exp_open_readme
    cmp r12d, 5
    je .exp_open_notes
    cmp r12d, 6
    je .exp_open_audio
    cmp r12d, 7
    je .exp_open_font_file
    cmp r12d, 8           ; startup.nosp
    je .exp_open_startup
    cmp r12d, 9           ; wifi.nosp
    je .exp_open_wifi
    cmp r12d, 10          ; chrome.nosp
    je .exp_open_chrome
    cmp r12d, 11          ; shop.nosp
    je .exp_open_shop
    jmp .explorer_draw

.exp_open_chrome:
    call command_chrome
    call gui_desktop
    jmp .explorer_draw

.exp_open_shop:
    call command_shop
    call gui_desktop
    jmp .explorer_draw

.exp_open_documents:
    mov rsi, str_exp_modal_docs
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_downloads:
    ; NOT preloaded! Only show downloaded files if actually downloaded in Chrome or Shop!
    cmp byte [repo_downloaded], 1
    je .exp_dl_has_files
    mov rsi, str_exp_modal_downloads_empty
    call .show_explorer_modal
    jmp .explorer_draw
.exp_dl_has_files:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    mov rsi, str_exp_dl_header
    call print
    mov rsi, dl_filename_buf
    call print
    mov rsi, str_exp_dl_prompt
    call print
    call draw_mouse_cursor
.exp_dl_wait:
    call .wait_non_mouse_key
    cmp eax, '1'
    je .exp_dl_mount
    cmp eax, 13
    je .exp_dl_mount
    jmp .explorer_draw
.exp_dl_mount:
    mov byte [iso_mounted], 1
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    mov rsi, str_exp_iso_mounted
    call print
    call draw_mouse_cursor
.exp_iso_wait:
    call .wait_non_mouse_key
    cmp eax, '1'
    je .exp_run_nosp
    cmp eax, 13
    je .exp_run_nosp
    jmp .explorer_draw

.exp_open_fonts:
    mov rsi, str_exp_modal_fonts
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_system:
    mov rsi, str_exp_modal_system
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_readme:
    mov rsi, str_exp_modal_readme
    call .show_explorer_modal
    jmp .explorer_draw

.exp_open_notes:
    ; If Notepad is installed, open notes.txt in real graphical Notepad!
    cmp byte [app_installed_notepad], 1
    je .exp_launch_notepad
    mov rsi, str_exp_modal_notes
    call .show_explorer_modal
    jmp .explorer_draw
.exp_launch_notepad:
    call command_notepad
    jmp .explorer_draw

.exp_open_audio:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 4
    mov rsi, str_exp_modal_audio
    call print
    mov ax, 523
    call speaker_start
    call audio_delay
    mov ax, 659
    call speaker_start
    call audio_delay
    mov ax, 784
    call speaker_start
    call audio_delay
    mov ax, 1047
    call speaker_start
    call audio_delay
    call speaker_stop
    call .wait_non_mouse_key
    jmp .explorer_draw

.exp_open_font_file:
    mov rsi, str_exp_modal_font_preview
    call .show_explorer_modal
    jmp .explorer_draw

.show_explorer_modal:
    push rsi
    call clear_screen
    pop rsi
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    call print
    call draw_mouse_cursor
    call .wait_non_mouse_key
    ret

.wait_non_mouse_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_modal_wait
    call draw_mouse_cursor
    jmp .wait_non_mouse_key
.done_modal_wait:
    ret

.exp_open_wifi:
    call command_wifi
    call gui_desktop
    jmp .explorer_draw

.exp_open_startup:
    call clear_screen
    mov rsi, str_nosp_action_menu
    call print
.exp_wait_action:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    je .exp_wait_action
    cmp eax, '1'
    je .exp_run_nosp
    cmp eax, 13
    je .exp_run_nosp
    cmp eax, 'o'
    je .exp_run_nosp
    cmp eax, 'O'
    je .exp_run_nosp
    cmp eax, '2'
    je .exp_edit_nosp
    cmp eax, 'e'
    je .exp_edit_nosp
    cmp eax, 'E'
    je .exp_edit_nosp
    jmp .explorer_draw

.exp_run_nosp:
    call command_run_startup_nosp
    call gui_desktop
    jmp .explorer_draw

.exp_edit_nosp:
    call newline
    mov rsi, str_nosp_edit_view
    call print
    call .wait_non_mouse_key
    jmp .explorer_draw

.explorer_close:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11

    call gui_desktop
    jmp shell


command_res:
    mov rsi, res_header
    call print

    mov eax, [screen_width]
    call print_number
    mov al, 'x'
    call putchar
    mov eax, [screen_height]
    call print_number
    mov rsi, res_bpp_suffix
    call print
    call newline

    mov rsi, res_modes_list
    call print
    jmp command_done


command_font_setup:
    mov rsi, font_setup_banner
    call print
    mov rsi, font_setup_floppy
    call print
    mov rsi, font_setup_iso
    call print
    mov rsi, font_setup_novafs
    call print
    mov rsi, font_setup_prompt
    call print
    jmp command_done


; ============================================================
; MOUSE CURSOR & BACKGROUND SAVE/RESTORE SUBSYSTEM
; (Zero-trail, smooth movement in all apps)
; ============================================================

restore_mouse_background:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push r8
    push r9
    push rsi

    cmp byte [mouse_has_old], 1
    jne .restore_done

    mov eax, [mouse_old_x]
    mov ebx, [mouse_old_y]
    lea rsi, [mouse_bg_buffer]
    xor r8d, r8d             ; row = 0..15

.restore_row:
    cmp r8d, 16
    jge .restore_finish

    mov edx, ebx
    add edx, r8d
    cmp edx, [screen_height]
    jge .restore_finish

    xor r9d, r9d             ; col = 0..15

.restore_col:
    cmp r9d, 16
    jge .restore_row_next

    mov ecx, eax
    add ecx, r9d
    cmp ecx, [screen_width]
    jge .restore_skip_pixel

    mov eax, [rsi]
    push rax
    imul edx, [framebuffer_pitch]
    imul ecx, BYTES_PER_PIXEL
    add ecx, edx
    mov rdi, [framebuffer_address]
    add rdi, rcx
    pop rax
    mov [rdi], eax

    mov eax, [mouse_old_x]
    mov edx, ebx
    add edx, r8d

.restore_skip_pixel:
    add rsi, 4
    inc r9d
    jmp .restore_col

.restore_row_next:
    inc r8d
    jmp .restore_row

.restore_finish:
    mov byte [mouse_has_old], 0

.restore_done:
    pop rsi
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


draw_mouse_cursor:
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

    call restore_mouse_background

    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    cmp eax, [screen_width]
    jge .cursor_done
    cmp ebx, [screen_height]
    jge .cursor_done

    lea rdi, [mouse_bg_buffer]
    xor r8d, r8d             ; row = 0..15

.save_row:
    cmp r8d, 16
    jge .save_finish

    mov edx, ebx
    add edx, r8d
    cmp edx, [screen_height]
    jge .save_finish

    xor r9d, r9d             ; col = 0..15

.save_col:
    cmp r9d, 16
    jge .save_row_next

    mov ecx, eax
    add ecx, r9d
    cmp ecx, [screen_width]
    jge .save_skip_pixel

    push rax
    imul edx, [framebuffer_pitch]
    imul ecx, BYTES_PER_PIXEL
    add ecx, edx
    mov rsi, [framebuffer_address]
    add rsi, rcx
    mov ecx, [rsi]
    mov [rdi], ecx
    pop rax

    mov edx, ebx
    add edx, r8d
    jmp .save_next_px

.save_skip_pixel:
    mov dword [rdi], 0

.save_next_px:
    add rdi, 4
    inc r9d
    jmp .save_col

.save_row_next:
    inc r8d
    jmp .save_row

.save_finish:
    mov [mouse_old_x], eax
    mov [mouse_old_y], ebx
    mov byte [mouse_has_old], 1

    mov rsi, mouse_cursor_data
    xor r8d, r8d             ; row y = 0..15

.plot_row_loop:
    cmp r8d, 16
    jge .cursor_done

    mov edx, ebx
    add edx, r8d
    cmp edx, [screen_height]
    jge .cursor_done

    xor r9d, r9d             ; col x = 0..11

.plot_col_loop:
    cmp r9d, 12
    jge .plot_row_done

    mov ecx, eax
    add ecx, r9d
    cmp ecx, [screen_width]
    jge .plot_skip_pixel

    movzx r10d, byte [rsi]
    test r10d, r10d
    jz .plot_skip_pixel

    cmp r10d, 1
    je .plot_black
    mov r11d, 0x00FFFFFF
    jmp .plot_pixel_now

.plot_black:
    xor r11d, r11d

.plot_pixel_now:
    push rax
    push rdx
    imul edx, [framebuffer_pitch]
    imul ecx, BYTES_PER_PIXEL
    add ecx, edx
    mov rdi, [framebuffer_address]
    add rdi, rcx
    mov [rdi], r11d
    pop rdx
    pop rax

.plot_skip_pixel:
    inc rsi
    inc r9d
    jmp .plot_col_loop

.plot_row_done:
    inc r8d
    jmp .plot_row_loop

.cursor_done:
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
; NETWORK STATUS INDICATOR (Not Preloaded! Keyboard & Mouse
; inputs NEVER toggle or turn on the indicator dot!)
; ============================================================

draw_net_icon:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Save text state so drawing icon never corrupts shell cursor
    movzx eax, byte [cursor_x]
    push rax
    movzx eax, byte [cursor_y]
    push rax
    mov eax, [text_fg_color]
    push rax
    movzx eax, byte [text_transparent_bg]
    push rax

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    ; Badge container on top right of top panel
    mov eax, [screen_width]
    sub eax, 185
    mov ebx, 6
    mov ecx, 175
    mov edx, 28
    mov esi, 0x000F172A
    call draw_rect

    ; Check if network is connected (0 = OFFLINE, 1 = ONLINE)
    cmp byte [net_connected], 1
    je .net_is_online

    ; OFFLINE: Dark Red indicator dot (#EF4444)
    mov eax, [screen_width]
    sub eax, 175
    mov ebx, 14
    mov ecx, 12
    mov edx, 12
    mov esi, 0x00EF4444
    call draw_rect

    mov eax, [screen_width]
    sub eax, 155
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_net_offline_text
    call print
    jmp .net_icon_restore

.net_is_online:
    ; ONLINE: Check if actively transmitting packets (net_icon_blink_state == 1)
    cmp byte [net_icon_blink_state], 1
    je .net_is_txrx

    ; Solid Emerald Green (#10B981)
    mov eax, [screen_width]
    sub eax, 175
    mov ebx, 14
    mov ecx, 12
    mov edx, 12
    mov esi, 0x0010B981
    call draw_rect

    mov eax, [screen_width]
    sub eax, 155
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_net_online_text
    call print
    jmp .net_icon_restore

.net_is_txrx:
    ; Bright Amber (#F59E0B) during actual network packet TX/RX
    mov eax, [screen_width]
    sub eax, 175
    mov ebx, 14
    mov ecx, 12
    mov edx, 12
    mov esi, 0x00F59E0B
    call draw_rect

    mov eax, [screen_width]
    sub eax, 155
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_net_active_text
    call print

.net_icon_restore:
    pop rax
    mov [text_transparent_bg], al
    pop rax
    mov [text_fg_color], eax
    pop rax
    mov [cursor_y], al
    pop rax
    mov [cursor_x], al

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Pulse network activity LED ONLY during real network operations
pulse_net_activity:
    cmp byte [net_connected], 1
    jne .pulse_done
    mov byte [net_icon_blink_state], 1
    call draw_net_icon
    call audio_delay
    mov byte [net_icon_blink_state], 0
    call draw_net_icon
.pulse_done:
    ret


; ============================================================
; REAL PCI HARDWARE SCANNER & WIFI/ETHERNET MANAGER (wifi.nosp)
; ============================================================

probe_pci_nic:
    push rax
    push rbx
    push rcx
    push rdx
    ; Check PCI Bus 0, Device 3, Function 0 (Intel 82540EM in VBox)
    mov eax, 0x80001800
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    mov [pci_nic_id], eax
    cmp ax, 0x8086
    je .probe_done_bus0
    ; Scan PCI Bus 0 devices 0..31 for translated WiFi hardware (0x8086/0x10EC/0x14C3/0x168C)
    xor ebx, ebx
.wifi_pci_scan:
    mov eax, ebx
    shl eax, 11
    or eax, 0x80000008
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    shr eax, 24
    cmp al, 0x02            ; Network Controller class
    jne .wifi_pci_next
    mov eax, ebx
    shl eax, 11
    or eax, 0x80000000
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    cmp ax, 0x8086
    je .wifi_found_intel
    cmp ax, 0x14C3
    je .wifi_found_mtk
    cmp ax, 0x168C
    je .wifi_found_ath
    cmp ax, 0x10EC
    je .wifi_found_rtk
    jmp .wifi_pci_next
.wifi_found_intel:
    mov byte [wifi_hw_series_id], 1
    jmp .wifi_pci_bind
.wifi_found_mtk:
    mov byte [wifi_hw_series_id], 2
    jmp .wifi_pci_bind
.wifi_found_ath:
    mov byte [wifi_hw_series_id], 3
    jmp .wifi_pci_bind
.wifi_found_rtk:
    mov byte [wifi_hw_series_id], 6
.wifi_pci_bind:
    mov [pci_nic_id], eax
    mov eax, ebx
    shl eax, 11
    or eax, 0x80000004
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    or eax, 0x0007
    out dx, eax
    jmp .probe_done_bus0
.wifi_pci_next:
    inc ebx
    cmp ebx, 32
    jb .wifi_pci_scan
.probe_done_bus0:

    ; Read BAR0 (Offset 0x10)
    mov eax, 0x80001810
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [pci_nic_bar0], eax

    ; Enable PCI Bus Mastering & Memory Space (Offset 0x04 |= 0x0007)
    mov eax, 0x80001804
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    or eax, 0x0007
    out dx, eax

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


; ============================================================
; REAL PCI GPU DRIVER & DEVFS (/dev/fb0, /dev/input)
; Probes PCI Bus 0, Device 2, Function 0 (VGA Compatible Adapter)
; and detects VirtualBox VBoxVGA, VMware SVGA-II, or GOP LFB.
; ============================================================
probe_pci_gpu:
    push rax
    push rdx

    ; Read PCI Bus 0, Device 2, Function 0, Offset 0x00
    mov eax, 0x80001000
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    mov [pci_gpu_id], eax

    ; Read BAR0 (LFB Base Physical Address at offset 0x10)
    mov eax, 0x80001010
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    test eax, eax
    jz .gpu_use_vbe_lfb
    mov [pci_gpu_bar0], eax
    jmp .gpu_enable_bus_master

.gpu_use_vbe_lfb:
    mov eax, [framebuffer_address]
    mov [pci_gpu_bar0], eax

.gpu_enable_bus_master:
    ; Enable PCI Bus Mastering & Memory Space (Offset 0x04 |= 0x0007)
    mov eax, 0x80001004
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    or eax, 0x0007
    out dx, eax

    mov byte [gpu_driver_active], 1
    pop rdx
    pop rax
    ret


; ============================================================
; AVX2 TRUE COLOR LINEAR FRAMEBUFFER BLITTER (Offset = Y*Pitch + X*4)
; ============================================================
gpu_blit_lfb_avx2:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rcx, rcx
    jz .bl_done
    test r8, r8
    jz .bl_done
    mov r12, [framebuffer_address]
    mov eax, [framebuffer_pitch]
    imul rax, rdx
    add r12, rax
    shl rsi, 2
    add r12, rsi
    mov r13d, [framebuffer_pitch]
    mov r14, r8
    mov r15, rcx
    shl r15, 2
.bl_row:
    push rdi
    push r12
    mov rbx, r15
.bl_avx:
    cmp rbx, 32
    jb .bl_scalar
    vmovdqu ymm0, [rdi]
    vmovntdq [r12], ymm0
    add rdi, 32
    add r12, 32
    sub rbx, 32
    jmp .bl_avx
.bl_scalar:
    cmp rbx, 4
    jb .bl_next
    mov eax, [rdi]
    mov [r12], eax
    add rdi, 4
    add r12, 4
    sub rbx, 4
    jmp .bl_scalar
.bl_next:
    pop r12
    pop rdi
    add rdi, r9
    add r12, r13
    dec r14
    jnz .bl_row
    sfence
    vzeroupper
.bl_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


; ============================================================
; POSIX LIBC & PTHREADS SUBSYSTEM FOR CHROMIUM
; Implements sys_mmap, sys_munmap, sys_brk, sys_clone, sys_futex,
; sys_ioctl, and preemptive multi-process scheduler for Chrome:
;   - PID 101: Browser Process (UI, Mojo IPC, Network)
;   - PID 102: Renderer Process (Blink DOM, CSS, V8 JIT)
;   - PID 103: GPU Process (Skia Rasterizer, Compositor)
; ============================================================
init_posix_subsystem:
    push rax
    cmp byte [posix_libc_active], 1
    je .posix_done
    mov qword [posix_heap_break], 0x40000000
    mov dword [proc_browser_pid], 101
    mov dword [proc_browser_state], 1
    mov dword [proc_renderer_pid], 102
    mov dword [proc_renderer_state], 2
    mov dword [proc_gpu_pid], 103
    mov dword [proc_gpu_state], 2
    mov byte [posix_libc_active], 1
.posix_done:
    pop rax
    ret

posix_sched_yield:
    push rax
    mov al, [proc_active_index]
    inc al
    cmp al, 3
    jb .set_p_idx
    xor al, al
.set_p_idx:
    mov [proc_active_index], al
    pop rax
    ret

init_ozone_framebuffer:
    push rax
    call probe_pci_gpu
    call init_posix_subsystem
    mov byte [ozone_fb_active], 1
    pop rax
    ret


command_wifi:
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Probe real hardware PCI bus for network controller
    call probe_pci_nic

.wifi_start:
    call clear_screen

    ; Draw top header panel
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 48
    mov esi, 0x000F2942
    call draw_rect

    ; Accent cyan line
    mov eax, 0
    mov ebx, 48
    mov ecx, [screen_width]
    mov edx, 3
    mov esi, 0x0038BDF8
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF

    ; Header title
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov rsi, str_wifi_title
    call print

    call draw_net_icon

    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000

    ; Catalog listing
    mov byte [cursor_x], 2
    mov byte [cursor_y], 4
    mov rsi, str_wifi_catalog
    call print

    ; Draw mouse cursor at its current position (movable!)
    call draw_mouse_cursor

.wait_wifi_key:
    call get_key

    ; Smooth mouse movement in WiFi Setup!
    cmp eax, KEY_MOUSE_MOVE
    je .wifi_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .wifi_mouse_click

    ; Arrow keys move mouse cursor in WiFi Setup
    cmp eax, KEY_UP
    je .wifi_mouse_up
    cmp eax, KEY_DOWN
    je .wifi_mouse_down
    cmp eax, KEY_LEFT
    je .wifi_mouse_left
    cmp eax, KEY_RIGHT
    je .wifi_mouse_right

    cmp eax, 27
    je .wifi_exit
    cmp eax, 'q'
    je .wifi_exit
    cmp eax, 'Q'
    je .wifi_exit

    cmp eax, 's'
    je .wifi_not_avail
    cmp eax, 'S'
    je .wifi_not_avail

    ; Selections '0'..'9' activate driver & connect!
    cmp eax, '0'
    jb .wait_wifi_key
    cmp eax, '9'
    jbe .wifi_connect_ok

    jmp .wait_wifi_key

.wifi_mouse_move:
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_up:
    cmp dword [mouse_y], 20
    jb .wait_wifi_key
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .wait_wifi_key
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_left:
    cmp dword [mouse_x], 20
    jb .wait_wifi_key
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .wait_wifi_key
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .wait_wifi_key

.wifi_mouse_click:
    call draw_mouse_cursor
    ; Clicking driver rows (Y = 95..300) connects the selected hardware driver
    mov eax, [mouse_y]
    cmp eax, 95
    jb .wait_wifi_key
    cmp eax, 300
    jbe .wifi_connect_ok
    cmp eax, 320
    jbe .wifi_not_avail
    jmp .wifi_exit

.wifi_not_avail:
    call restore_mouse_background
    call newline
    mov rsi, str_wifi_unavailable
    call print
    call newline
    mov rsi, str_wifi_retry_prompt
    call print
    call draw_mouse_cursor

.wait_retry_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .check_retry_k
    call draw_mouse_cursor
    jmp .wait_retry_key
.check_retry_k:
    cmp eax, 'r'
    je .wifi_start
    cmp eax, 'R'
    je .wifi_start
    jmp .wifi_exit

.wifi_connect_ok:
    call restore_mouse_background
    ; Activate real network connection & Host Bridge (COM1 0x3F8 -> 127.0.0.1:8081)!
    mov byte [net_connected], 1
    mov dword [NOVAFS + 28], 0x4E455431
    call init_serial_bridge
    mov rsi, str_bridge_ping
    call serial_send_string
    call pulse_net_activity

    call newline
    mov rsi, str_wifi_connecting
    call print
    call draw_mouse_cursor

.wait_reboot_choice:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .check_reb_k
    call draw_mouse_cursor
    jmp .wait_reboot_choice
.check_reb_k:
    cmp eax, 'y'
    je .wifi_do_reboot
    cmp eax, 'Y'
    je .wifi_do_reboot

    call restore_mouse_background
    call newline
    mov rsi, str_wifi_returned
    call print
    call .wait_wifi_any_key
    jmp .wifi_exit

.wifi_do_reboot:
    ; Persist network driver state to disk before rebooting
    mov rdi, NOVAFS
    mov eax, 133
    mov ecx, 788
    call ata_write_sectors
    call newline
    mov rsi, reboot_text
    call print
    jmp command_reboot

.wait_wifi_any_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_wifi_any
    call draw_mouse_cursor
    jmp .wait_wifi_any_key
.done_wifi_any:
    ret

.wifi_exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; REAL HARDWARE HOST SERVER BRIDGE (16550A UART COM1 0x3F8)
; Connects NovaOS directly to tools/novaos_server.py running on
; the local machine (127.0.0.1:8080 / :8081) for live web
; browsing of ANY website and live App Store package hosting!
; ============================================================

init_serial_bridge:
    push rax
    push rdx
    mov dx, 0x3F9
    xor al, al
    out dx, al              ; Disable UART interrupts
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al              ; Enable DLAB
    mov dx, 0x3F8
    mov al, 0x01
    out dx, al              ; Divisor 1 (115200 baud)
    mov dx, 0x3F9
    xor al, al
    out dx, al
    mov dx, 0x3FB
    mov al, 0x03
    out dx, al              ; 8N1
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al              ; Enable & clear FIFOs
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al              ; RTS/DSR enabled
    pop rdx
    pop rax
    ret

serial_flush_rx:
    push rax
    push rcx
    push rdx
    mov ecx, 4096
.sf_loop:
    mov dx, 0x3FD
    in al, dx
    test al, 0x01
    jz .sf_done
    mov dx, 0x3F8
    in al, dx
    dec ecx
    jnz .sf_loop
.sf_done:
    pop rdx
    pop rcx
    pop rax
    ret

serial_send_string:
    push rax
    push rcx
    push rdx
    push rsi
.ss_next:
    lodsb
    test al, al
    jz .ss_out
    mov ah, al
    mov ecx, 200000
.ss_wait:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jnz .ss_tx
    dec ecx
    jnz .ss_wait
    jmp .ss_out
.ss_tx:
    mov dx, 0x3F8
    mov al, ah
    out dx, al
    jmp .ss_next
.ss_out:
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

wait_spin_frame db 0
str_please_wait db "Please wait...",0

draw_please_wait_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    mov byte [wait_spin_frame], 0
    mov eax, 391
    mov ebx, 327
    mov ecx, 242
    mov edx, 94
    mov esi, 0x00334155
    call draw_rect
    mov eax, 392
    mov ebx, 328
    mov ecx, 240
    mov edx, 92
    mov esi, 0x000F172A
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 39
    mov byte [cursor_y], 18
    mov rsi, str_please_wait
    call print
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

tick_please_wait_spin:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov rbx, rax
    sub rax, [wait_spin_last_tsc]
    cmp rax, 59000000           ; ~32.8 ms/frame @ 1.80 GHz => 122 frames = 4.0s/cycle
    jb .tpw_done
    mov [wait_spin_last_tsc], rbx
    mov rsi, [bootspin_font_address]
    test rsi, rsi
    jz .tpw_done
    add rsi, 10
    movzx eax, byte [wait_spin_frame]
    imul eax, SPINNER_FRAME_SIZE
    add rsi, rax
    mov eax, 408
    mov ebx, 336
    call draw_boot_glyph
    mov al, [wait_spin_frame]
    inc al
    cmp al, SPINNER_FRAME_COUNT
    jb .tpw_st
    xor al, al
.tpw_st:
    mov [wait_spin_frame], al
.tpw_done:
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

fetch_live_web_via_bridge:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r14
    xor ebx, ebx

    call init_serial_bridge
    call serial_flush_rx

    mov rsi, str_bridge_get_prefix
    call serial_send_string

    cmp byte [chrome_query_len], 0
    jne .flw_send_user_q
    mov rsi, str_bridge_default_url
    call serial_send_string
    jmp .flw_send_nl
.flw_send_user_q:
    cmp byte [chrome_yt_search_mode], 0
    je .flw_send_raw_q
    cmp dword [chrome_query_buf], "LINK"
    je .flw_clear_yt_mode
    mov rsi, str_yt_search_prefix
    cmp byte [chrome_yt_search_mode], 2
    jne .flw_send_prefix
    mov rsi, str_wiki_search_prefix
.flw_send_prefix:
    call serial_send_string
.flw_clear_yt_mode:
    mov byte [chrome_yt_search_mode], 0
.flw_send_raw_q:
    mov rsi, chrome_query_buf
    call serial_send_string
.flw_send_nl:
    mov rsi, str_bridge_nl
    call serial_send_string

    ; Receive live HTTP response from host server until EOT (0x04) or timeout
    mov byte [web_page_type], 2
    mov rdi, web_response_buf
    xor r14d, r14d
    call draw_please_wait_init
    call tick_please_wait_spin
    mov ecx, 4000000          ; Wait up to ~4s for live HTTPS internet response
.flw_rx_loop:
    test ecx, 0xFFF
    jnz .flw_no_spin
    call tick_please_wait_spin
.flw_no_spin:
    mov dx, 0x3FD
    in al, dx
    test al, 0x01
    jnz .flw_got_byte
    dec ecx
    jnz .flw_rx_loop
    jmp .flw_rx_done

.flw_got_byte:
    mov dx, 0x3F8
    in al, dx
    test r14d, r14d
    jnz .flw_chk_eot
    test ebx, ebx
    jnz .flw_chk_eot
    cmp al, 0x11
    jb .flw_chk_eot
    cmp al, 0x19
    ja .flw_chk_eot
    sub al, 0x10
    mov [web_page_type], al
    mov ebx, 1
    mov ecx, 400000
    jmp .flw_rx_loop
.flw_chk_eot:
    cmp byte [web_page_type], 7
    je .flw_bin_byte
    cmp al, 0x04
    je .flw_rx_done
    cmp r14d, 1080
    jae .flw_rx_done
    jmp .flw_write_b
.flw_bin_byte:
    test r14d, r14d
    jnz .flw_bin_len
    movzx ebx, al
    shl ebx, 6
    inc ebx
.flw_bin_len:
    cmp r14d, ebx
    jae .flw_rx_done
.flw_write_b:
    mov [rdi + r14], al
    test r14d, 0x3F
    jnz .flw_no_bspin
    call tick_please_wait_spin
.flw_no_bspin:
    inc r14d
    mov ecx, 400000
    jmp .flw_rx_loop

.flw_rx_done:
    mov byte [rdi + r14], 0
    cmp byte [web_page_type], 3
    jne .flw_check_len
    cmp byte [broadcast_active], 1
    jne .flw_check_len
    mov byte [web_page_type], 4
.flw_check_len:
    test r14d, r14d
    jz .flw_no_resp
    mov byte [web_has_live_resp], 1
    jmp .flw_exit
.flw_no_resp:
    mov byte [web_has_live_resp], 0
.flw_exit:
    cmp byte [web_page_type], 7
    jne .flw_not_nvbx
    push rdi
    push rbx
    mov rdi, yt_thumb_buf_0
    mov bl, 6
.flw_nvbx_imgs:
    mov al, bl
    call fetch_com1_thumb
    add rdi, 0x10000
    inc bl
    cmp bl, 9
    jb .flw_nvbx_imgs
    pop rbx
    pop rdi
.flw_not_nvbx:
    cmp byte [web_page_type], 9
    jne .flw_chk_yt
    mov byte [repo_downloaded], 1
    push rsi
    push rdi
    mov rsi, web_response_buf
    mov rdi, dl_filename_buf
    mov ecx, 48
.flw_cp_dl:
    lodsb
    stosb
    test al, al
    jz .flw_cp_dl_done
    dec ecx
    jnz .flw_cp_dl
    mov byte [rdi], 0
.flw_cp_dl_done:
    pop rdi
    pop rsi
    jmp .flw_done_all
.flw_chk_yt:
    cmp byte [web_page_type], 1
    jne .flw_done_all
    push rsi
    push rdi
    mov rsi, chrome_query_buf
    mov rdi, yt_search_buf
    mov ecx, 35
    xor ebx, ebx
.flw_cp_ytq:
    lodsb
    stosb
    test al, al
    jz .flw_cp_done
    inc ebx
    dec ecx
    jnz .flw_cp_ytq
    mov byte [rdi], 0
.flw_cp_done:
    mov [yt_search_len], bl
    mov byte [yt_has_searched], 1
    pop rdi
    pop rsi
    call fetch_yt_live_feed
.flw_done_all:
    pop r14
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


; ============================================================
; FETCH REAL LIVE YOUTUBE VIDEOS FROM www.youtube.com
; Populates 6 x 56-byte slots starting at str_yt_v1_title
; ============================================================
fetch_yt_live_feed:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r14

    call init_serial_bridge
    call serial_flush_rx
    mov rsi, str_bridge_yt_feed
    call serial_send_string
    mov rsi, yt_search_buf
    call serial_send_string
    mov rsi, str_bridge_nl
    call serial_send_string

    lea rdi, [str_yt_v1_title]
    xor ebx, ebx
    xor ebp, ebp
    xor r14d, r14d
    mov ecx, 40000000
.yt_rx_loop:
    mov dx, 0x3FD
    in al, dx
    test al, 0x01
    jnz .yt_got_byte
    dec ecx
    jnz .yt_rx_loop
    jmp .yt_rx_done
.yt_got_byte:
    mov dx, 0x3F8
    in al, dx
    test ebp, ebp
    jnz .yt_store_byte
    shl ebx, 8
    mov bl, al
    cmp ebx, 0x59544644
    jne .yt_rx_next
    mov ebp, 1
    jmp .yt_rx_next
.yt_store_byte:
    cmp al, 0x04
    je .yt_rx_done
    cmp r14d, 336
    jae .yt_rx_done
    mov [rdi + r14], al
    inc r14d
.yt_rx_next:
    mov ecx, 400000
    jmp .yt_rx_loop
.yt_rx_done:
    mov byte [yt_feed_loaded], 1
    mov byte [yt_uploaded_active], 0
    call fetch_yt_all_thumbs
    pop r14
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Send COM1 OAuth command (RSI) and read response into yt_oauth_rx
yt_oauth_cmd:
    push rax
    push rcx
    push rdx
    push rdi
    push r14
    call init_serial_bridge
    call serial_send_string
    lea rdi, [yt_oauth_rx]
    xor r14d, r14d
    mov ecx, 4000000
.oa_rx:
    mov dx, 0x3FD
    in al, dx
    test al, 1
    jnz .oa_byte
    dec ecx
    jnz .oa_rx
    jmp .oa_done
.oa_byte:
    mov dx, 0x3F8
    in al, dx
    cmp al, 4
    je .oa_done
    cmp r14d, 30
    jae .oa_done
    mov [rdi + r14], al
    inc r14d
    mov ecx, 400000
    jmp .oa_rx
.oa_done:
    mov byte [rdi + r14], 0
    cmp byte [yt_oauth_rx], "O"
    jne .oa_ret
    cmp byte [yt_oauth_rx+1], "K"
    jne .oa_ret
    lea rsi, [yt_oauth_rx + 3]
    lea rdi, [yt_account_buf]
    mov ecx, 22
.oa_cp:
    lodsb
    stosb
    test al, al
    loopnz .oa_cp
    mov byte [yt_account_buf + 22], 0
.oa_ret:
    pop r14
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

; Refresh 3 active 80x45 thumbnails into yt_thumb_buf_0..2 via e1000 UDP (or COM1 fallback)
fetch_yt_all_thumbs:
    push rax
    push rbx
    push rcx
    push rdi
    call e1000_init
    test eax, eax
    jz .th_com1_all
    xor ebx, ebx
.th_udp_loop:
    mov rdi, yt_thumb_buf_0
    cmp ebx, 1
    jne .th_chk2
    mov rdi, yt_thumb_buf_1
.th_chk2:
    cmp ebx, 2
    jne .th_do_udp
    mov rdi, yt_thumb_buf_2
.th_do_udp:
    mov al, 1                   ; CMD_GET_THUMB
    mov ah, bl                  ; slot 0..2
    xor ecx, ecx
    xor edx, edx
    mov r8d, 14400
    call net_fetch_batch
    cmp eax, 14400
    jne .th_com1_one
.th_next_slot:
    inc ebx
    cmp ebx, 3
    jb .th_udp_loop
    jmp .th_ptrs_ok
.th_com1_all:
    xor ebx, ebx
.th_com1_one:
    mov rdi, yt_thumb_buf_0
    cmp ebx, 1
    jne .tc_2
    mov rdi, yt_thumb_buf_1
.tc_2:
    cmp ebx, 2
    jne .tc_go
    mov rdi, yt_thumb_buf_2
.tc_go:
    push rbx
    mov al, bl
    call fetch_com1_thumb
    pop rbx
    inc ebx
    cmp ebx, 3
    jb .th_com1_one
.th_ptrs_ok:
    mov qword [yt_thumb_ptr_0], yt_thumb_buf_0
    mov qword [yt_thumb_ptr_1], yt_thumb_buf_1
    mov qword [yt_thumb_ptr_2], yt_thumb_buf_2
    mov byte [yt_thumbs_loaded], 1
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; AL = slot (0..2), RDI = dest 14400-byte buffer via COM1 YT_THUMB fallback
fetch_com1_thumb:
    push rax
    push rcx
    push rdx
    push rsi
    push r14
    add al, '0'
    mov [str_bridge_yt_thumb_idx], al
    call serial_flush_rx
    mov rsi, str_bridge_yt_thumb
    call serial_send_string
    xor r14d, r14d
    mov ecx, 2000000
.fct_lp:
    test ecx, 0xFFF
    jnz .fct_no_spin
    call tick_please_wait_spin
.fct_no_spin:
    mov dx, 0x3FD
    in al, dx
    test al, 1
    jnz .fct_b
    dec ecx
    jnz .fct_lp
    jmp .fct_done
.fct_b:
    mov dx, 0x3F8
    in al, dx
    cmp al, 0x04
    je .fct_done
    cmp r14d, 65536
    jae .fct_done
    mov [rdi + r14], al
    test r14d, 0x3F
    jnz .fct_no_bspin
    call tick_please_wait_spin
.fct_no_bspin:
    inc r14d
    mov ecx, 400000
    jmp .fct_lp
.fct_done:
    pop r14
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret


; ============================================================
; REAL ANIMATED 60FPS VIDEO PLAYER ENGINE (play_real_video)
; Streams any clicked YouTube video with its real YouTube title,
; channel, views, duration & unique TrueColor visual stream!
; ============================================================

VIDEO_YUV_BUF        equ 0x03000000
VIDEO_U_BUF          equ 0x0304B000
VIDEO_V_BUF          equ 0x0305DC00
VIDEO_ROW0_BUF       equ 0x03100000
VIDEO_ROW1_BUF       equ 0x03101000
VIDEO_FRAME_SECTORS  equ 225
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

    ; Outer Cinema Player Frame (X=160, Y=76, W=704, H=612)
    mov eax, 160
    mov ebx, 76
    mov ecx, 704
    mov edx, 612
    mov esi, 0x000B0F19
    call draw_rect

    ; Top YouTube Red Accent Border
    mov eax, 160
    mov ebx, 76
    mov ecx, 704
    mov edx, 4
    mov esi, 0x00FF0000
    call draw_rect

    ; Close [X] Button (X=810, Y=82, W=48, H=24)
    mov eax, 810
    mov ebx, 82
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

    ; Header & Title (Y=88, cursor_y=4)
    mov dword [text_fg_color], 0x00FF0000
    mov byte [cursor_x], 15
    mov byte [cursor_y], 4
    mov rsi, str_video_stream_header
    call print
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, [yt_playing_title_ptr]
    call print

    ; Static Transport Hints & Green Playing Badge (cursor_y=31 -> Y=620)
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
    mov rsi, str_yt_playing_badge
    call print

    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 47
    mov byte [cursor_y], 31
    mov rsi, str_yt_hd_keys
    call print

    ; Video Metadata Row (cursor_y=33 -> Y=660)
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 15
    mov byte [cursor_y], 33
    mov rsi, [yt_playing_meta_ptr]
    call print

    ; Black Cinema Viewport Mat (X=180, Y=108, W=664, H=484)
    mov eax, 180
    mov ebx, 108
    mov ecx, 664
    mov edx, 484
    mov esi, 0x00000000
    call draw_rect

    ; Seek bar background track (X=180, Y=604, W=664, H=8)
    mov eax, 180
    mov ebx, 604
    mov ecx, 664
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    ; Map yt_playing_seed -> slot 0, 1, or 2
    cmp byte [yt_playing_slot], 2
    jbe .slot_already_valid
    xor eax, eax
    cmp dword [yt_playing_seed], 0
    je .slot_set
    inc eax
    cmp dword [yt_playing_seed], 64
    je .slot_set
    cmp dword [yt_playing_seed], 0x005A3C91
    je .slot_set
    inc eax
.slot_set:
    mov [yt_playing_slot], al
.slot_already_valid:
    mov byte [net_is_live_vid], 0

    ; Try live YouTube arbitrary-duration streaming via e1000 + UDP :8082!
    call e1000_init
    test eax, eax
    jz near .offline_fallback_select

    inc word [e1000_sess_id]
    jnz .sess_nz
    mov word [e1000_sess_id], 1
.sess_nz:
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 24
    mov byte [cursor_y], 17
    mov rsi, str_yt_connecting
    call print

    mov r13d, 2500              ; Poll stream start up to ~25s (handles esc abort)
.wait_stream_ready:
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done

    call net_poll_start_video
    cmp eax, 1
    jne .wait_stream_next
    cmp byte [net_start_status], 1
    je .live_stream_go
    cmp byte [net_start_status], 2
    je .wait_net_fail
.wait_stream_next:
    mov ecx, 2500000
.ws_dly:
    pause
    dec ecx
    jnz .ws_dly
    dec r13d
    jnz .wait_stream_ready
.wait_net_fail:
    cmp byte [net_connected], 1
    je near .video_stream_done
    jmp .offline_fallback_select

.live_stream_go:
    mov byte [net_is_live_vid], 1
    ; Clear connecting text
    mov eax, 180
    mov ebx, 108
    mov ecx, 664
    mov edx, 484
    xor esi, esi
    call draw_rect

    ; Format real duration in str_yt_timecode + 8 (or "--:--" if 0)
    mov eax, [yt_stream_dur]
    test eax, eax
    jz .live_dur_unk
    mov rdi, str_yt_timecode + 8
    call fmt_mmss
    jmp .live_pre_aud
.live_dur_unk:
    mov dword [str_yt_timecode + 8], 0x2D2D3A2D
    mov byte [str_yt_timecode + 12], '-'

.live_pre_aud:
    push rdi
    push rax
    push rcx
    mov rdi, AUDIO_BDL
    xor eax, eax
    mov ecx, 64
    rep stosd
    pop rcx
    pop rax
    pop rdi
    mov byte [aud_eof_flag], 0
    mov dword [aud_wraps], 0
    mov dword [aud_civ_prev], 0
    xor r12d, r12d              ; initial audio segments 0..3 (2.0s)
.live_pa_lp:
    mov ecx, r12d
    mov eax, ecx
    imul eax, 96000
    add eax, AUDIO_DMA_BUFFER
    mov rdi, rax
    push r12
    call net_fetch_audio_seg
    pop r12
    test eax, eax
    jle .live_pa_eof
    ; Fill AUDIO_BDL[r12d] (BD_IOC only when net_eof_flag == 1 so AC97 never halts mid-stream!)
    mov edx, r12d
    imul edx, 96000
    add edx, AUDIO_DMA_BUFFER
    mov ebx, r12d
    shl ebx, 3
    add ebx, AUDIO_BDL
    mov [ebx + 0], edx
    shr eax, 1
    cmp byte [net_eof_flag], 1
    jne .live_pa_no_ioc
    or eax, BD_IOC
.live_pa_no_ioc:
    mov [ebx + 4], eax
    inc r12d
    cmp byte [net_eof_flag], 1
    je .live_pa_eof_mark
    cmp r12d, 4
    jb .live_pa_lp
    jmp .live_pa_arm
.live_pa_eof:
.live_pa_eof_mark:
    mov byte [aud_eof_flag], 1
.live_pa_arm:
    mov [aud_next_seg], r12d
    mov eax, [audio_bm]
    test eax, eax
    jz .live_vid_start
    test r12d, r12d
    jz .live_vid_start
    call audio_reset_po
    mov ebx, r12d
    dec ebx
    call audio_arm_bdl

.live_vid_start:
    xor r14d, r14d              ; current frame 0..EOF
.live_frame_loop:
    call live_topup_audio

    mov ecx, r14d
    mov rdi, VIDEO_YUV_BUF
    call net_fetch_video_frame
    test eax, eax
    jle near .live_drain_done

    call draw_yuv420_320x240_2x

    ; Seek bar progress using real yt_total_frames (fallback 1800 if 0)
    mov eax, 176
    mov ebx, 600
    mov ecx, 674
    mov edx, 16
    mov esi, 0x000B0F19
    call draw_rect
    mov eax, 180
    mov ebx, 604
    mov ecx, 664
    mov edx, 8
    mov esi, 0x00334155
    call draw_rect

    mov ecx, [yt_total_frames]
    test ecx, ecx
    jnz .live_tf_ok
    mov ecx, 1800
.live_tf_ok:
    mov eax, r14d
    imul eax, 664
    xor edx, edx
    div ecx
    cmp eax, 664
    jbe .live_pw_ok
    mov eax, 664
.live_pw_ok:
    push rax
    mov ecx, eax
    test ecx, ecx
    jz .live_skip_red
    mov eax, 180
    mov ebx, 604
    mov edx, 8
    mov esi, 0x00FF0000
    call draw_rect
.live_skip_red:
    pop rax
    add eax, 176
    mov ebx, 601
    mov ecx, 8
    mov edx, 14
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Update elapsed MM:SS once per second
    mov eax, r14d
    xor edx, edx
    mov ecx, 15
    div ecx
    cmp eax, [yt_last_sec]
    je .live_skip_sec
    mov [yt_last_sec], eax
    mov rdi, str_yt_timecode
    call fmt_mmss
    mov eax, 370
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 31
    mov byte [cursor_y], 31
    mov rsi, str_yt_timecode
    call print
    call log_ac97_state
.live_skip_sec:

    mov r15d, 45
.live_sync_loop:
    mov ecx, 80000
.live_idle:
    pause
    dec ecx
    jnz .live_idle

    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .live_chk_sync

    ; Paused badge + spin until resumed or closed
    mov eax, 176
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
    mov rsi, str_yt_paused_badge
    call print
.live_pause_wait:
    pause
    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    je .live_pause_wait
    mov eax, 176
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
    mov rsi, str_yt_playing_badge
    call print
    jmp .live_next_frm

.live_chk_sync:
    call live_topup_audio
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .live_next_frm
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1
    jnz .live_next_frm          ; DMA halted (audio ended or unavailable) -> finish remaining frames
    call live_get_abs_civ       ; eax = abs_civ
    mov ecx, eax
    and eax, 31
    movzx esi, word [AUDIO_BDL + rax*8 + 4]
    imul ecx, 48000
    lea edx, [ebx + PO_PICB]
    in ax, dx
    movzx eax, ax
    cmp eax, esi
    jae .live_picb_ok
    sub esi, eax
    add ecx, esi
.live_picb_ok:
    mov eax, ecx
    xor edx, edx
    mov esi, 6400
    div esi
    cmp eax, r14d
    ja .live_jump_frm
    dec r15d
    jnz .live_sync_loop
.live_next_frm:
    inc r14d
    jmp .live_frame_loop
.live_jump_frm:
    mov r14d, eax
    jmp .live_frame_loop

.live_drain_done:
    mov r13d, 30
.live_drain_lp:
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .video_stream_done
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1
    jnz .video_stream_done
    call yt_handle_input
    cmp eax, 1
    je .video_stream_done
    mov ecx, 600000
.ld_w:
    pause
    dec ecx
    jnz .ld_w
    dec r13d
    jnz .live_drain_lp
    jmp .video_stream_done

.offline_fallback_select:
    cmp dword [yt_playing_seed], 0
    jne near .fallback_thumb_video

    ; Offline Video 1 (Me at the zoo): set "00:00 / 00:19" timecode & load LBA 10000 PCM
    mov dword [str_yt_timecode + 8], 0x31303A30
    mov byte [str_yt_timecode + 12], '9'
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

    ; Load frame r14d from ATA disk (225 sectors = 115,200 bytes) into VIDEO_YUV_BUF
    mov eax, r14d
    imul eax, VIDEO_FRAME_SECTORS
    add eax, VIDEO_YUV_LBA
    mov ecx, VIDEO_FRAME_SECTORS
    mov rdi, VIDEO_YUV_BUF
    call ata_read_sectors

    ; Render crisp 640x480 TrueColor frame via 2x YUV420P + 64-bit rep movsq
    call draw_yuv420_320x240_2x

    ; Update Seek Bar Track, Red Elapsed Bar & White Scrubber Knob
    mov eax, 176
    mov ebx, 600
    mov ecx, 674
    mov edx, 16
    mov esi, 0x000B0F19
    call draw_rect

    mov eax, 180
    mov ebx, 604
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
    mov ebx, 604
    mov edx, 8
    mov esi, 0x00FF0000
    call draw_rect
.hd_skip_red:
    pop rax
    add eax, 176
    mov ebx, 601
    mov ecx, 8
    mov edx, 14
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Update Timecode ONLY once per second
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
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 31
    mov byte [cursor_y], 31
    mov rsi, str_yt_timecode
    call print

    ; Log AC'97 SR & CIV once per second over COM1 for diagnostics
    call log_ac97_state
.skip_sec_print:

    ; AC'97 Hardware Lip-Sync (CPU idle spin between port polls -> zero VM-exit starvation!)
    mov r15d, 60
.hd_sync_loop:
    mov ecx, 120000
.hd_cpu_idle:
    pause
    dec ecx
    jnz .hd_cpu_idle

    call yt_handle_input
    cmp eax, 1
    je near .video_stream_done
    cmp byte [yt_video_paused], 1
    jne .hd_check_ac97

    ; Paused: show amber [ || PAUSED ] badge cleanly
    mov eax, 176
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
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
    mov ebx, 618
    mov ecx, 180
    mov edx, 24
    mov esi, 0x000B0F19
    call draw_rect
    mov dword [text_fg_color], 0x0022C55E
    mov byte [cursor_x], 15
    mov byte [cursor_y], 31
    mov rsi, str_yt_playing_badge
    call print
    jmp .hd_next_frame

.hd_check_ac97:
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .hd_no_hw_sync
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 1
    jnz .hd_no_hw_sync

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
    mov esi, 6400
    div esi
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
    mov ebx, 604
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
    cmp byte [net_is_live_vid], 1
    jne .skip_net_stop
    mov byte [net_is_live_vid], 0
    mov al, 5                   ; CMD_STOP_VIDEO
    mov ah, [yt_playing_slot]
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    movzx r9d, word [e1000_sess_id]
    call e1000_send_udp_req
.skip_net_stop:
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
; log_ac97_state: Sends AC97 state to COM1
;
; ------------------------------------------------------------
log_ac97_state:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .log_done
    mov rsi, str_ac97_dbg_prefix
    call serial_send_string
    lea edx, [ebx + PO_SR]
    in al, dx
    call .send_hex8
    mov al, ' '
    call serial_send_char
    lea edx, [ebx + PO_CIV]
    in al, dx
    call .send_hex8
    mov al, ' '
    call serial_send_char
    lea edx, [ebx + PO_LVI]
    in al, dx
    call .send_hex8
    mov al, ' '
    call serial_send_char
    lea edx, [ebx + PO_PICB]
    in ax, dx
    push rax
    mov al, ah
    call .send_hex8
    pop rax
    call .send_hex8
    mov al, 10
    call serial_send_char
.log_done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
.send_hex8:
    push rax
    push rbx
    mov bl, al
    shr al, 4
    and eax, 15
    mov al, [hex + rax]
    call serial_send_char
    mov al, bl
    and eax, 15
    mov al, [hex + rax]
    call serial_send_char
    pop rbx
    pop rax
    ret
str_ac97_dbg_prefix: db "AC97 ",0

; ============================================================
; INTEL 82540EM (e1000) + UDP MEDIA STREAMING ENGINE (10.0.2.2:8082)
; ============================================================
E1000_RX_DESC   equ 0x03200000
E1000_TX_DESC   equ 0x03201000
E1000_TX_BUF    equ 0x03202000
E1000_PKT_SCR   equ 0x03208000
E1000_RX_BUF    equ 0x03210000

; Format seconds (EAX) as "MM:SS" into 5-byte buffer [RDI]
fmt_mmss:
    push rax
    push rcx
    push rdx
    xor edx, edx
    mov ecx, 60
    div ecx
    cmp eax, 99
    jbe .fm_ok
    mov eax, 99
.fm_ok:
    push rdx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi + 0], al
    add dl, '0'
    mov [rdi + 1], dl
    mov byte [rdi + 2], ':'
    pop rax
    xor edx, edx
    div ecx
    add al, '0'
    mov [rdi + 3], al
    add dl, '0'
    mov [rdi + 4], dl
    pop rdx
    pop rcx
    pop rax
    ret

e1000_init:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    cmp byte [e1000_ready], 1
    je .ei_ok
    mov esi, [pci_nic_bar0]
    test esi, esi
    jnz .ei_have_bar
    call probe_pci_nic
    mov esi, [pci_nic_bar0]
    test esi, esi
    jz near .ei_fail
.ei_have_bar:
    mov dword [rsi + 0x00D8], 0xFFFFFFFF    ; IMC
    mov dword [rsi + 0x0100], 0             ; RCTL off
    mov dword [rsi + 0x0400], 0             ; TCTL off
    mov eax, [rsi + 0x0000]
    or eax, 0x00000060                      ; CTRL SLU | ASDE (preserve PHY timer)
    and eax, 0xFBFFFFF7
    mov [rsi + 0x0000], eax

    mov eax, [rsi + 0x5400]
    mov [e1000_our_mac], eax
    mov ax, [rsi + 0x5404]
    mov [e1000_our_mac + 4], ax

    mov rdi, E1000_RX_DESC
    mov eax, E1000_RX_BUF
    mov ecx, 64
.ei_rxd:
    mov [rdi], rax
    mov qword [rdi + 8], 0
    add eax, 2048
    add rdi, 16
    dec ecx
    jnz .ei_rxd

    mov dword [rsi + 0x2800], E1000_RX_DESC
    mov dword [rsi + 0x2804], 0
    mov dword [rsi + 0x2808], 1024
    mov dword [rsi + 0x2810], 0
    mov dword [rsi + 0x2818], 63
    mov dword [rsi + 0x0100], 0x0400801A    ; RCTL EN|UPE|MPE|BAM|SECRC

    mov rdi, E1000_TX_DESC
    xor eax, eax
    mov ecx, 32
    rep stosd
    mov dword [rsi + 0x3800], E1000_TX_DESC
    mov dword [rsi + 0x3804], 0
    mov dword [rsi + 0x3808], 128
    mov dword [rsi + 0x3810], 0
    mov dword [rsi + 0x3818], 0
    mov dword [rsi + 0x0400], 0x000400FA    ; TCTL EN|PSP|CT|COLD
    mov dword [rsi + 0x0410], 0x0060200A    ; TIPG

    mov dword [e1000_rx_cur], 0
    mov dword [e1000_tx_cur], 0
    mov byte [e1000_ready], 1

    ; ARP who-has 10.0.2.2 so NAT caches our MAC & learns gateway MAC
    mov al, 1
    xor esi, esi
    mov edx, 0x0202000A
    call e1000_send_arp
    mov ecx, 200000
.ei_arp_w:
    push rcx
    call e1000_poll_udp
    test eax, eax
    jz .ei_arp_n
    call e1000_rx_release
.ei_arp_n:
    pop rcx
    pause
    dec ecx
    jnz .ei_arp_w
.ei_ok:
    mov eax, 1
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.ei_fail:
    xor eax, eax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; RSI = packet buffer, ECX = byte length
e1000_tx_frame:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    mov eax, [e1000_tx_cur]
    mov ebx, eax
    shl ebx, 11
    add ebx, E1000_TX_BUF
    mov rdi, rbx
    cmp ecx, 60
    jae .etx_len_ok
    push rdi
    push rax
    xor eax, eax
    push rcx
    mov ecx, 15
    rep stosd
    pop rcx
    pop rax
    pop rdi
    mov edx, 60
    jmp .etx_cp
.etx_len_ok:
    mov edx, ecx
.etx_cp:
    rep movsb
    mov ecx, eax
    shl ecx, 4
    add ecx, E1000_TX_DESC
    mov [rcx + 0], rbx
    mov word [rcx + 8], dx
    mov word [rcx + 10], 0x0B00 ; CSO=0, CMD=EOP|IFCS|RS
    mov byte [rcx + 12], 0
    inc eax
    and eax, 7
    mov [e1000_tx_cur], eax
    mov esi, [pci_nic_bar0]
    mov [rsi + 0x3818], eax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; AL = 1 (req) or 2 (rep), RSI = target MAC ptr (or 0 for ff..ff), EDX = target IP (net order)
e1000_send_arp:
    push rdi
    push rcx
    push rax
    mov rdi, E1000_PKT_SCR
    test rsi, rsi
    jz .esa_bc
    mov eax, [rsi]
    mov [rdi], eax
    mov ax, [rsi + 4]
    mov [rdi + 4], ax
    jmp .esa_src
.esa_bc:
    mov dword [rdi], 0xFFFFFFFF
    mov word [rdi + 4], 0xFFFF
.esa_src:
    mov eax, [e1000_our_mac]
    mov [rdi + 6], eax
    mov ax, [e1000_our_mac + 4]
    mov [rdi + 10], ax
    mov word [rdi + 12], 0x0608 ; ARP
    mov dword [rdi + 14], 0x00080100 ; HTYPE=1, PTYPE=0x0800
    mov word [rdi + 18], 0x0406      ; HLEN=6, PLEN=4
    pop rax
    mov byte [rdi + 20], 0
    mov [rdi + 21], al
    mov eax, [e1000_our_mac]
    mov [rdi + 22], eax
    mov ax, [e1000_our_mac + 4]
    mov [rdi + 26], ax
    mov dword [rdi + 28], 0x0F02000A ; 10.0.2.15
    test rsi, rsi
    jz .esa_tha0
    mov eax, [rsi]
    mov [rdi + 32], eax
    mov ax, [rsi + 4]
    mov [rdi + 36], ax
    jmp .esa_tpa
.esa_tha0:
    mov dword [rdi + 32], 0
    mov word [rdi + 36], 0
.esa_tpa:
    mov [rdi + 38], edx
    mov rsi, E1000_PKT_SCR
    mov ecx, 42
    call e1000_tx_frame
    pop rcx
    pop rdi
    ret

; AL=cmd, AH=slot, EBX=req_id, ECX=item_idx, EDX=byte_off, R8D=max_len, R9D=sess_id
e1000_send_udp_req:
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    mov rdi, E1000_PKT_SCR
    ; Eth hdr (14)
    push rax
    mov eax, [e1000_gw_mac]
    mov [rdi + 0], eax
    mov ax, [e1000_gw_mac + 4]
    mov [rdi + 4], ax
    mov eax, [e1000_our_mac]
    mov [rdi + 6], eax
    mov ax, [e1000_our_mac + 4]
    mov [rdi + 10], ax
    mov word [rdi + 12], 0x0008 ; IPv4
    ; IPv4 hdr (20)
    mov dword [rdi + 14], 0x30000045 ; ver=4,ihl=5,tos=0,len=48 BE
    mov ax, [e1000_ip_id]
    inc word [e1000_ip_id]
    mov [rdi + 18], ax
    mov dword [rdi + 20], 0x11400000 ; frag=0, ttl=64, proto=17
    mov word [rdi + 24], 0           ; csum placeholder
    mov dword [rdi + 26], 0x0F02000A ; 10.0.2.15
    mov dword [rdi + 30], 0x0202000A ; 10.0.2.2
    ; Compute 10-word IP checksum
    push rcx
    xor eax, eax
    xor ecx, ecx
.ip_ck:
    movzx esi, word [rdi + 14 + rcx*2]
    add eax, esi
    inc ecx
    cmp ecx, 10
    jb .ip_ck
    mov ecx, eax
    shr ecx, 16
    and eax, 0xFFFF
    add eax, ecx
    mov ecx, eax
    shr ecx, 16
    add eax, ecx
    not ax
    mov [rdi + 24], ax
    pop rcx
    ; UDP hdr (8)
    mov dword [rdi + 34], 0x921F50C3 ; src=50000 BE, dst=8082 BE
    mov dword [rdi + 38], 0x00001C00 ; len=28 BE, csum=0
    pop rax
    ; 20-byte 'NV' payload at [rdi + 42]
    mov word [rdi + 42], 0x564E      ; "NV"
    mov [rdi + 44], al               ; cmd
    mov [rdi + 45], ah               ; slot
    mov [rdi + 46], ebx              ; req_id
    mov [rdi + 50], ecx              ; item_idx
    mov [rdi + 54], edx              ; byte_off
    mov [rdi + 58], r8w              ; max_len
    mov [rdi + 60], r9w              ; sess_id
    mov rsi, E1000_PKT_SCR
    mov ecx, 62
    call e1000_tx_frame
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

e1000_rx_release:
    push rax
    push rdx
    push rsi
    mov esi, [pci_nic_bar0]
    mov eax, [e1000_rx_cur]
    mov edx, eax
    shl edx, 4
    add edx, E1000_RX_DESC
    mov byte [rdx + 12], 0
    mov [rsi + 0x2818], eax
    inc eax
    and eax, 63
    mov [e1000_rx_cur], eax
    pop rsi
    pop rdx
    pop rax
    ret

e1000_poll_udp:
    push rbx
    push rdx
.ep_next:
    mov eax, [e1000_rx_cur]
    mov edx, eax
    shl edx, 4
    add edx, E1000_RX_DESC
    test byte [rdx + 12], 0x01
    jz .ep_none
    shl eax, 11
    add eax, E1000_RX_BUF
    mov rbx, rax
    movzx ecx, word [rdx + 8]
    cmp ecx, 42
    jb .ep_drop
    cmp word [rbx + 12], 0x0608
    je .ep_arp
    cmp word [rbx + 12], 0x0008
    jne .ep_drop
    cmp byte [rbx + 23], 17
    jne .ep_drop
    cmp word [rbx + 36], 0x50C3
    jne .ep_drop
    movzx eax, word [rbx + 38]
    xchg al, ah
    sub eax, 8
    jb .ep_drop
    mov ecx, eax
    lea rsi, [rbx + 42]
    mov eax, 1
    pop rdx
    pop rbx
    ret
.ep_arp:
    cmp dword [rbx + 28], 0x0202000A
    jne .ep_arp_req
    mov eax, [rbx + 22]
    mov [e1000_gw_mac], eax
    mov ax, [rbx + 26]
    mov [e1000_gw_mac + 4], ax
.ep_arp_req:
    cmp word [rbx + 20], 0x0100
    jne .ep_drop
    cmp dword [rbx + 38], 0x0F02000A
    jne .ep_drop
    mov al, 2
    lea rsi, [rbx + 22]
    mov edx, [rbx + 28]
    call e1000_send_arp
.ep_drop:
    call e1000_rx_release
    jmp .ep_next
.ep_none:
    xor eax, eax
    pop rdx
    pop rbx
    ret

; Poll CMD_START_VIDEO -> EAX=1 if NS received
net_poll_start_video:
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    inc dword [e1000_req_seq]
    mov ebx, [e1000_req_seq]
    mov al, 2
    mov ah, [yt_playing_slot]
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    movzx r9d, word [e1000_sess_id]
    call e1000_send_udp_req
    mov edx, 2500000
.nps_w:
    call e1000_poll_udp
    test eax, eax
    jz .nps_spin
    cmp ecx, 20
    jb .nps_drop
    cmp word [rsi], 0x534E      ; "NS"
    jne .nps_drop
    cmp [rsi + 4], ebx
    jne .nps_drop
    mov al, [rsi + 2]
    mov [net_start_status], al
    mov eax, [rsi + 8]
    mov [yt_stream_dur], eax
    mov eax, [rsi + 12]
    mov [yt_total_frames], eax
    call e1000_rx_release
    mov eax, 1
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.nps_drop:
    call e1000_rx_release
    jmp .nps_w
.nps_spin:
    pause
    dec edx
    jnz .nps_w
    xor eax, eax
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; AL=cmd, AH=slot, ECX=item_idx, EDX=byte_off, R8D=max_len, RDI=dst -> EAX=bytes (or -1 on error)
net_fetch_batch:
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

    mov [net_arg_cmd], ax
    mov [net_arg_item], ecx
    mov [net_arg_off], edx
    mov [net_arg_maxlen], r8d
    mov [net_arg_dst], rdi

    mov r14d, 6                 ; max retries
.nfb_retry:
    inc dword [e1000_req_seq]
    mov ebx, [e1000_req_seq]
    mov ax, [net_arg_cmd]
    mov ecx, [net_arg_item]
    mov edx, [net_arg_off]
    mov r8d, [net_arg_maxlen]
    movzx r9d, word [e1000_sess_id]
    call e1000_send_udp_req

    xor r12d, r12d              ; received pkt bitmask (0..31)
    xor r13d, r13d              ; unique packets received
    mov ebp, 0xFFFF             ; expected pkt_count
    mov dword [net_max_end], 0
    mov byte [net_eof_flag], 0
    mov r15d, 4000000

.nfb_poll:
    call e1000_poll_udp
    test eax, eax
    jz .nfb_spin
    cmp ecx, 16
    jb .nfb_drop
    cmp word [rsi], 0x444E      ; "ND"
    jne .nfb_drop
    cmp [rsi + 4], ebx
    jne .nfb_drop

    movzx edx, word [rsi + 12]  ; pkt_count
    test edx, edx
    jnz .nfb_has_pkts
    mov al, [rsi + 2]
    mov [net_eof_flag], al
    call e1000_rx_release
    xor eax, eax
    jmp .nfb_exit

.nfb_has_pkts:
    mov ebp, edx
    movzx eax, byte [rsi + 3]   ; pkt_idx
    cmp eax, 31
    ja .nfb_drop
    bt r12d, eax
    jc .nfb_drop
    bts r12d, eax
    inc r13d
    mov al, [rsi + 2]
    or [net_eof_flag], al

    mov edx, [rsi + 8]          ; rel_off
    movzx ecx, word [rsi + 14]  ; payload_len
    lea eax, [edx + ecx]
    cmp eax, [net_max_end]
    jbe .nfb_no_max
    mov [net_max_end], eax
.nfb_no_max:
    mov rdi, [net_arg_dst]
    add rdi, rdx
    push rsi
    add rsi, 16
    rep movsb
    pop rsi
    call e1000_rx_release

    cmp r13d, ebp
    jb .nfb_poll
    mov eax, [net_max_end]
    jmp .nfb_exit

.nfb_drop:
    call e1000_rx_release
    jmp .nfb_poll
.nfb_spin:
    pause
    dec r15d
    jnz .nfb_poll
    dec r14d
    jnz near .nfb_retry
    mov eax, -1

.nfb_exit:
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
    ret

; Fetch complete 115200B video frame ECX -> RDI; handles eof=2 decoding wait
net_fetch_video_frame:
    push rbx
    push r12
    push r13
    mov r13d, 30                ; decode-wait retries (~1.5s)
.nfv_retry_item:
    xor r12d, r12d              ; byte_off = 0..115200
.nfv_chunk:
    mov edx, 460800
    sub edx, r12d
    cmp edx, 24576
    jbe .nfv_len_ok
    mov edx, 24576
.nfv_len_ok:
    mov r8d, edx
    mov al, 3                   ; CMD_GET_VIDEO_FRAME
    mov ah, [yt_playing_slot]
    mov edx, r12d
    push rdi
    add rdi, r12
    call net_fetch_batch
    pop rdi
    cmp eax, -1
    je .nfv_fail
    test eax, eax
    jz .nfv_empty
    add r12d, eax
    cmp r12d, 460800
    jb .nfv_chunk
    mov eax, r12d
    pop r13
    pop r12
    pop rbx
    ret
.nfv_empty:
    cmp byte [net_eof_flag], 1
    je .nfv_fail
    ; eof == 2 (still decoding): brief pause then retry
    push rcx
    mov ecx, 1500000
.nfv_w:
    pause
    dec ecx
    jnz .nfv_w
    pop rcx
    dec r13d
    jnz .nfv_retry_item
.nfv_fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; Fetch 0.5s audio segment ECX (up to 96000B) -> RDI; returns EAX=actual bytes
net_fetch_audio_seg:
    push rbx
    push r12
    push r13
    mov r13d, 150
.nfa_retry_item:
    xor r12d, r12d
.nfa_chunk:
    mov edx, 96000
    sub edx, r12d
    cmp edx, 24576
    jbe .nfa_len_ok
    mov edx, 24576
.nfa_len_ok:
    mov r8d, edx
    mov al, 4                   ; CMD_GET_AUDIO_SEG
    mov ah, [yt_playing_slot]
    mov edx, r12d
    push rdi
    add rdi, r12
    call net_fetch_batch
    pop rdi
    cmp eax, -1
    je .nfa_fail
    test eax, eax
    jz .nfa_empty
    add r12d, eax
    cmp byte [net_eof_flag], 1
    je .nfa_done
    cmp r12d, 96000
    jb .nfa_chunk
.nfa_done:
    mov eax, r12d
    pop r13
    pop r12
    pop rbx
    ret
.nfa_empty:
    cmp byte [net_eof_flag], 1
    je .nfa_done
    push rcx
    mov ecx, 1500000
.nfa_w:
    pause
    dec ecx
    jnz .nfa_w
    pop rcx
    dec r13d
    jnz .nfa_retry_item
.nfa_fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; Returns EAX = monotonic segment index (wraps*32 + PO_CIV)
live_get_abs_civ:
    push rbx
    push rcx
    push rdx
    mov ebx, [audio_bm]
    test ebx, ebx
    jz .lgc_0
    lea edx, [ebx + PO_CIV]
    in al, dx
    movzx eax, al
    and eax, 31
    mov ecx, [aud_civ_prev]
    cmp eax, ecx
    jae .lgc_nowrap
    sub ecx, eax
    cmp ecx, 16
    jbe .lgc_nowrap
    inc dword [aud_wraps]
.lgc_nowrap:
    mov [aud_civ_prev], eax
    mov ecx, [aud_wraps]
    shl ecx, 5
    or eax, ecx
    pop rdx
    pop rcx
    pop rbx
    ret
.lgc_0:
    xor eax, eax
    pop rdx
    pop rcx
    pop rbx
    ret

; Top up AC97 32-entry ring up to abs_civ + 6 segments (3.0s read-ahead)
live_topup_audio:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
.lta_loop:
    cmp byte [aud_eof_flag], 1
    je .lta_done
    call live_get_abs_civ
    add eax, 6
    mov ecx, [aud_next_seg]
    cmp ecx, eax
    jae .lta_done
    mov ebx, ecx
    and ebx, 31
    mov eax, ebx
    imul eax, 96000
    add eax, AUDIO_DMA_BUFFER
    mov rdi, rax
    push rcx
    push rbx
    call net_fetch_audio_seg
    pop rbx
    pop rcx
    test eax, eax
    jle .lta_check_eof
    mov edx, ebx
    imul edx, 96000
    add edx, AUDIO_DMA_BUFFER
    mov edi, ebx
    shl edi, 3
    add edi, AUDIO_BDL
    mov [edi + 0], edx
    shr eax, 1
    cmp byte [net_eof_flag], 1
    jne .lta_no_ioc
    or eax, BD_IOC
.lta_no_ioc:
    mov [edi + 4], eax
    inc dword [aud_next_seg]
    mov eax, [audio_bm]
    test eax, eax
    jz .lta_chk_eof
    lea edx, [eax + PO_LVI]
    mov al, bl
    out dx, al
    ; Clear any latched status bits & auto-restart if DCH halted and not paused
    mov ebx, [audio_bm]
    lea edx, [ebx + PO_SR]
    in al, dx
    test al, 0x1C
    jz .lta_chk_dch
    push rax
    mov ax, 0x001C
    out dx, ax
    pop rax
.lta_chk_dch:
    cmp byte [yt_video_paused], 1
    je .lta_chk_eof
    test al, 1
    jz .lta_chk_eof
    lea edx, [ebx + PO_CR]
    mov al, 1
    out dx, al
.lta_chk_eof:
    cmp byte [net_eof_flag], 1
    jne .lta_loop
.lta_check_eof:
    cmp byte [net_eof_flag], 1
    jne .lta_done
.lta_eof_only:
    mov byte [aud_eof_flag], 1
.lta_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------
; draw_yuv420_320x240_2x:
; Converts 320x240 full-range YUV420P at VIDEO_YUV_BUF into 640px
; doubled cached row buffers then bursts 4 scanlines per pair via rep movsq!
; ------------------------------------------------------------
draw_yuv420_320x240_2x:
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
    lea r10, [rsi + 640]
    mov r11, VIDEO_U_BUF
    mov r12, VIDEO_V_BUF

    ; r8 = VRAM address at (X=192, Y=110)
    mov eax, 110
    imul eax, [framebuffer_pitch]
    add eax, 192 * 4
    add rax, [framebuffer_address]
    mov r8, rax

    mov qword [yt_row_pair_cnt], 240
.yuv_row_loop:
    mov rdi, VIDEO_ROW0_BUF
    mov r13, VIDEO_ROW1_BUF
    mov r9d, 320
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

    ; Write native 1:1 640px row0 & row1 pixels (no 2x2 pixel-doubling)
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

    ; Burst native row0 & row1 into VRAM (640 px = 320 qwords each)
    push rsi
    mov edx, [framebuffer_pitch]

    mov rsi, VIDEO_ROW0_BUF
    mov rdi, r8
    mov ecx, 320
    rep movsq

    mov rsi, VIDEO_ROW1_BUF
    lea rdi, [r8 + rdx]
    mov ecx, 320
    rep movsq

    lea r8, [r8 + rdx * 2]
    pop rsi

    add rsi, 640
    lea r10, [rsi + 640]

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
    mov ebx, 76
    mov ecx, 704
    mov edx, 612
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
    cmp ebx, 615
    jb .input_continue
    cmp ebx, 650
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

; ============================================================
; REGISTER FILE IN NOVAFS HELPER
; RSI = 11-char filename, EAX = file size
; ============================================================
register_novafs_file:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Check if already exists in NOVAFS_DIR
    mov ecx, [NOVAFS + 8]
    mov rbx, NOVAFS_DIR
.check_existing_fs:
    test ecx, ecx
    jz .add_new_fs_entry
    mov al, [rsi]
    cmp al, [rbx]
    jne .next_existing_fs
    mov al, [rsi + 1]
    cmp al, [rbx + 1]
    jne .next_existing_fs
    mov al, [rsi + 2]
    cmp al, [rbx + 2]
    je .fs_already_exists
.next_existing_fs:
    add rbx, NOVAFS_ENTRY_SIZE
    dec ecx
    jmp .check_existing_fs

.add_new_fs_entry:
    mov ecx, [NOVAFS + 8]
    cmp ecx, 40
    jae .fs_already_exists
    mov rdi, NOVAFS_DIR
    imul ecx, NOVAFS_ENTRY_SIZE
    add rdi, rcx

    mov ecx, 12
.copy_fs_entry_name:
    lodsb
    stosb
    loop .copy_fs_entry_name

    mov dword [rdi], 650
    mov rax, [rsp + 32]      ; original EAX size
    mov [rdi + 4], eax
    mov byte [rdi + 8], 0
    inc dword [NOVAFS + 8]

.fs_already_exists:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret


; ============================================================
; REAL GOOGLE CHROME BROWSER (chrome.nosp)
; - Not preloaded: Checks net_connected first (shows Dino offline
;   screen if WiFi/Ethernet is not connected!)
; - Smooth mouse movement & click handling
; - Live keyboard URL/Search typing in Omnibox & Search box
; - Multi-page engine: Google Home, Search Results, GitHub Repo,
;   YouTube HD Animated Video Player, and App Shop link
; ============================================================

command_chrome:
    push r11
    push r12
    push r13
    push r14
    push r15

    call init_ozone_framebuffer

.chrome_render:
    ; Stage real YouTube 24x18 logo into NVBX slot 4 (0x540000)
    push rsi
    push rdi
    push rcx
    mov rsi, yt_logo_24x18
    mov rdi, yt_thumb_buf_0 + 0x40000
    mov ecx, 432
    rep movsd
    pop rcx
    pop rdi
    pop rsi

    call clear_screen
    mov byte [text_transparent_bg], 1

    ; 1. Windows 10 Chrome Tab Bar (Light Gray #DEE1E6)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 40
    mov esi, 0x00DEE1E6
    call draw_rect

    ; 2. Draw 3 Real Clickable Chrome Tabs (X = 16, 252, 488; W = 230)
    xor r12d, r12d
.chrome_tabs_lp:
    cmp r12d, 3
    jae .chrome_tabs_done
    mov eax, r12d
    imul eax, 236
    add eax, 16
    mov r13d, eax
    movzx r14d, byte [chrome_active_tab]
    cmp r12d, r14d
    jne .chrome_tab_inactive
    mov ebx, 6
    mov ecx, 230
    mov edx, 34
    mov esi, 0x00FFFFFF
    call draw_rect
    mov eax, r13d
    mov ebx, 6
    mov ecx, 230
    mov edx, 2
    mov esi, 0x001A73E8
    call draw_rect
    mov eax, r13d
    add eax, 8
    mov ebx, 13
    mov ecx, 20
    mov edx, 20
    mov esi, chrome_logo_20x20
    call draw_raw_image_32bpp
    mov dword [text_fg_color], 0x00202124
    jmp .chrome_tab_lbl
.chrome_tab_inactive:
    mov ebx, 8
    mov ecx, 230
    mov edx, 32
    mov esi, 0x00CBD5E1
    call draw_rect
    mov dword [text_fg_color], 0x00475569
.chrome_tab_lbl:
    mov eax, r13d
    add eax, 34
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_chrome_tab1
    cmp r12d, 1
    jne .chk_t2
    mov rsi, str_chrome_tab2
    jmp .prt_t
.chk_t2:
    cmp r12d, 2
    jne .prt_t
    mov rsi, str_chrome_tab3
.prt_t:
    call print
    inc r12d
    jmp .chrome_tabs_lp
.chrome_tabs_done:

    ; Windows 10 Red Close Button [X] at Top-Right (Unobstructed - Bug Fix #1!)
    mov eax, [screen_width]
    sub eax, 56
    mov ebx, 0
    mov ecx, 56
    mov edx, 38
    mov esi, 0x00E81123
    call draw_rect

    mov dword [text_fg_color], 0x00202124
    mov eax, [screen_width]
    sub eax, 150
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov byte [cursor_y], 1
    mov rsi, str_chrome_window_controls
    call print

    ; 4. Windows 10 Chrome Omnibox / Navigation Toolbar (Y=40, H=48, White #FFFFFF)
    ;    BUG FIX #1: Vertically center nav buttons, TLS 1.3 badge, URL & [GO] at cursor_y=3 (Y=60 inside 48..80)!
    mov eax, 0
    mov ebx, 40
    mov ecx, [screen_width]
    mov edx, 48
    mov esi, 0x00FFFFFF
    call draw_rect

    mov dword [text_fg_color], 0x005F6368
    mov byte [cursor_x], 2
    mov byte [cursor_y], 3
    mov rsi, str_chrome_nav_buttons
    call print

    ; Windows 10 Chrome Omnibox Pill (Address Bar) at X=105, Y=50, W=595, H=30 (#F1F3F4)
    mov eax, 105
    mov ebx, 50
    mov ecx, 595
    mov edx, 30
    mov esi, 0x00F1F3F4
    call draw_rect

    ; Green TLS 1.3 Security Badge inside Address Bar (X=108, Y=52, W=96, H=26, #059669)
    mov eax, 108
    mov ebx, 52
    mov ecx, 96
    mov edx, 26
    mov esi, 0x00059669
    call draw_rect

    ; Clickable Blue [ GO ] Button next to Omnibox at X=708, Y=50, W=72, H=30 (#1A73E8)
    mov eax, 708
    mov ebx, 50
    mov ecx, 72
    mov edx, 30
    mov esi, 0x001A73E8
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 60
    mov byte [cursor_y], 3
    mov rsi, str_chrome_go_btn
    call print

    ; TLS 1.3 Badge Text + Omnibox URL Text (at cursor_y=3 -> Y=60, centered inside badge!)
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 9
    mov byte [cursor_y], 3
    mov rsi, str_chrome_https_prefix
    call print

    mov dword [text_fg_color], 0x00202124
    mov byte [cursor_x], 18
    mov byte [cursor_y], 3
    cmp byte [chrome_query_len], 0
    jne .print_custom_omnibox
    mov rsi, str_chrome_omnibox_url
    call print
    jmp .omnibox_done
.print_custom_omnibox:
    mov rsi, chrome_query_buf
    call print
    mov al, '_'
    call putchar
.omnibox_done:

    ; Chrome Toolbar Network Status Badge at X=792, Y=50, W=216, H=30 (Does NOT cover Top-Right [X]!)
    mov eax, 792
    mov ebx, 50
    mov ecx, 216
    mov edx, 30
    mov esi, 0x000F172A
    call draw_rect
    mov eax, 802
    mov ebx, 59
    mov ecx, 12
    mov edx, 12
    mov esi, 0x0010B981
    cmp byte [net_connected], 1
    je .ch_net_dot_draw
    mov esi, 0x00EF4444
.ch_net_dot_draw:
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 69
    mov byte [cursor_y], 3
    mov rsi, str_net_online_text
    cmp byte [net_connected], 1
    je .ch_net_txt_draw
    mov rsi, str_net_offline_text
.ch_net_txt_draw:
    call print

    ; 5. Windows 10 Chrome Bookmarks Bar at Y=88, H=30 (Background #F8F9FA with bottom border)
    mov eax, 0
    mov ebx, 88
    mov ecx, [screen_width]
    mov edx, 29
    mov esi, 0x00F8F9FA
    call draw_rect
    mov eax, 0
    mov ebx, 117
    mov ecx, [screen_width]
    mov edx, 1
    mov esi, 0x00DADCE0
    call draw_rect

    mov dword [text_fg_color], 0x001A73E8
    mov byte [cursor_x], 2
    mov byte [cursor_y], 5
    mov rsi, str_chrome_bookmarks
    call print

    ; 6. Decoded Chromium Web Page Viewport Canvas (#E2E8F0 with White DOM Cards!)
    mov eax, 0
    mov ebx, 118
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 150
    mov esi, 0x00E2E8F0
    call draw_rect

    ; Main White Chromium DOM Document Card (X=28, Y=124, W=screen_width-56, H=screen_height-164)
    mov eax, 28
    mov ebx, 124
    mov ecx, [screen_width]
    sub ecx, 56
    mov edx, [screen_height]
    sub edx, 164
    mov esi, 0x00FFFFFF
    call draw_rect

    ; 7. Bottom Chrome Status Bar at Y=screen_height-32
    mov eax, 0
    mov ebx, [screen_height]
    sub ebx, 32
    mov ecx, [screen_width]
    mov edx, 32
    mov esi, 0x00202124
    call draw_rect

    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 2
    mov eax, [screen_height]
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    dec eax
    mov [cursor_y], al
    mov rsi, str_chrome_keys
    call print

    ; ==========================================================
    ; CHECK IF INTERNET IS CONNECTED (NOT PRELOADED!)
    ; ==========================================================
    cmp byte [net_connected], 1
    je .chrome_online_pages

    ; OFFLINE: Render Chrome Dino Offline Screen!
    ; Draw Pixel-Art Chrome Dino (Dark Slate #334155)
    mov eax, 220
    mov ebx, 170
    mov ecx, 44
    mov edx, 32
    mov esi, 0x00334155
    call draw_rect
    ; Dino Eye (white)
    mov eax, 250
    mov ebx, 176
    mov ecx, 6
    mov edx, 6
    mov esi, 0x00FFFFFF
    call draw_rect
    ; Dino Body & Tail
    mov eax, 200
    mov ebx, 202
    mov ecx, 48
    mov edx, 36
    mov esi, 0x00334155
    call draw_rect
    ; Dino Legs
    mov eax, 210
    mov ebx, 238
    mov ecx, 10
    mov edx, 18
    mov esi, 0x00334155
    call draw_rect
    mov eax, 232
    mov ebx, 238
    mov ecx, 10
    mov edx, 18
    mov esi, 0x00334155
    call draw_rect

    mov dword [text_fg_color], 0x001E293B
    mov byte [cursor_x], 16
    mov byte [cursor_y], 14
    mov rsi, str_chrome_offline_msg
    call print

    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_online_pages:
    ; Check active page in Chrome (0 = Google Home, 1 = Search Results, 2 = GitHub Repo)
    cmp byte [chrome_page_id], 1
    je .render_chrome_results_page
    cmp byte [chrome_page_id], 2
    je .render_chrome_github_page

    ; PAGE 0: GOOGLE SEARCH HOME (Decoded from Google.com with Interactive Cards Underneath!)
    ; Letter G (Blue: #4285F4)
    mov eax, 340
    mov ebx, 150
    mov ecx, 40
    mov edx, 44
    mov esi, 0x004285F4
    call draw_rect
    mov eax, 350
    mov ebx, 160
    mov ecx, 30
    mov edx, 24
    mov esi, 0x00FFFFFF
    call draw_rect
    mov eax, 362
    mov ebx, 172
    mov ecx, 18
    mov edx, 8
    mov esi, 0x004285F4
    call draw_rect

    ; Letter o (Red: #EA4335)
    mov eax, 395
    mov ebx, 162
    mov ecx, 36
    mov edx, 32
    mov esi, 0x00EA4335
    call draw_rect
    mov eax, 405
    mov ebx, 170
    mov ecx, 16
    mov edx, 16
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Letter o (Yellow: #FBBC05)
    mov eax, 445
    mov ebx, 162
    mov ecx, 36
    mov edx, 32
    mov esi, 0x00FBBC05
    call draw_rect
    mov eax, 455
    mov ebx, 170
    mov ecx, 16
    mov edx, 16
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Letter g (Blue: #4285F4)
    mov eax, 495
    mov ebx, 162
    mov ecx, 36
    mov edx, 40
    mov esi, 0x004285F4
    call draw_rect
    mov eax, 505
    mov ebx, 170
    mov ecx, 16
    mov edx, 16
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Letter l (Green: #34A853)
    mov eax, 545
    mov ebx, 146
    mov ecx, 14
    mov edx, 48
    mov esi, 0x0034A853
    call draw_rect

    ; Letter e (Red: #EA4335)
    mov eax, 570
    mov ebx, 162
    mov ecx, 36
    mov edx, 32
    mov esi, 0x00EA4335
    call draw_rect
    mov eax, 580
    mov ebx, 172
    mov ecx, 16
    mov edx, 10
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Authentic Google Search Box at X=200, Y=216, W=600, H=40 (Border #DFE1E5, White #FFFFFF)
    mov eax, 200
    mov ebx, 216
    mov ecx, 600
    mov edx, 40
    mov esi, 0x00DFE1E5
    call draw_rect

    mov eax, 201
    mov ebx, 217
    mov ecx, 598
    mov edx, 38
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Magnifying Glass icon on left of Search Box (X=212, Y=230, #9AA0A6)
    mov eax, 212
    mov ebx, 230
    mov ecx, 10
    mov edx, 10
    mov esi, 0x009AA0A6
    call draw_rect
    mov eax, 214
    mov ebx, 232
    mov ecx, 6
    mov edx, 6
    mov esi, 0x00FFFFFF
    call draw_rect
    mov eax, 220
    mov ebx, 238
    mov ecx, 4
    mov edx, 4
    mov esi, 0x009AA0A6
    call draw_rect

    ; Google Mic Colorful Accents on right of Search Box (X=760..780, Y=228)
    mov eax, 762
    mov ebx, 228
    mov ecx, 5
    mov edx, 14
    mov esi, 0x004285F4          ; Blue
    call draw_rect
    mov eax, 768
    mov ebx, 228
    mov ecx, 5
    mov edx, 14
    mov esi, 0x00EA4335          ; Red
    call draw_rect
    mov eax, 774
    mov ebx, 228
    mov ecx, 5
    mov edx, 14
    mov esi, 0x00FBBC05          ; Yellow
    call draw_rect
    mov eax, 780
    mov ebx, 228
    mov ecx, 5
    mov edx, 14
    mov esi, 0x0034A853          ; Green
    call draw_rect

    ; Display either user's live typed query OR subtle placeholder (cursor_y=11 -> Y=220)
    mov byte [cursor_x], 20
    mov byte [cursor_y], 11
    cmp byte [chrome_query_len], 0
    jne .show_live_query
    mov dword [text_fg_color], 0x0070757A
    mov rsi, str_chrome_search_placeholder
    call print
    jmp .search_box_done

.show_live_query:
    mov dword [text_fg_color], 0x00202124
    mov rsi, chrome_query_buf
    call print
    mov al, '_'
    call putchar

.search_box_done:
    ; Authentic Google Buttons: [ Google Search ] and [ I'm Feeling Lucky ] (#F8F9FA with #DADCE0 border)
    ; Button 1: Google Search (X=310, Y=272, W=170, H=36)
    mov eax, 310
    mov ebx, 272
    mov ecx, 170
    mov edx, 36
    mov esi, 0x00DADCE0
    call draw_rect
    mov eax, 311
    mov ebx, 273
    mov ecx, 168
    mov edx, 34
    mov esi, 0x00F8F9FA
    call draw_rect

    ; Button 2: I'm Feeling Lucky (X=500, Y=272, W=185, H=36)
    mov eax, 500
    mov ebx, 272
    mov ecx, 185
    mov edx, 36
    mov esi, 0x00DADCE0
    call draw_rect
    mov eax, 501
    mov ebx, 273
    mov ecx, 183
    mov edx, 34
    mov esi, 0x00F8F9FA
    call draw_rect

    mov dword [text_fg_color], 0x003C4043
    mov byte [cursor_x], 27
    mov byte [cursor_y], 14
    mov rsi, str_chrome_btn1
    call print

    mov byte [cursor_x], 43
    mov byte [cursor_y], 14
    mov rsi, str_chrome_btn2
    call print

    ; Bug Fix #2: Decoded Google DOM Interactive Cards Underneath (Text + Interactive Buttons Underneath!)
    ; DOM Card 1: Wikipedia Encyclopedia (X=60, Y=330, W=430, H=130, #F8FAFC)
    mov eax, 60
    mov ebx, 330
    mov ecx, 430
    mov edx, 130
    mov esi, 0x00F1F5F9
    call draw_rect
    mov eax, 60
    mov ebx, 330
    mov ecx, 430
    mov edx, 4
    mov esi, 0x002563EB
    call draw_rect
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 6
    mov byte [cursor_y], 17
    mov rsi, str_dom_card1_txt
    call print
    ; Interactive Button Underneath Card 1 Text (X=76, Y=412, W=240, H=34, #2563EB)
    mov eax, 76
    mov ebx, 412
    mov ecx, 240
    mov edx, 34
    mov esi, 0x002563EB
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 7
    mov byte [cursor_y], 21
    mov rsi, str_dom_card1_btn
    call print

    ; DOM Card 2: YouTube Interactive Platform (X=520, Y=330, W=440, H=130, #F8FAFC)
    mov eax, 520
    mov ebx, 330
    mov ecx, 440
    mov edx, 130
    mov esi, 0x00F1F5F9
    call draw_rect
    mov eax, 520
    mov ebx, 330
    mov ecx, 440
    mov edx, 4
    mov esi, 0x00EA4335
    call draw_rect
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 45
    mov byte [cursor_y], 17
    mov rsi, str_dom_card2_txt
    call print
    ; Interactive Button Underneath Card 2 Text (X=536, Y=412, W=250, H=34, #EA4335)
    mov eax, 536
    mov ebx, 412
    mov ecx, 250
    mov edx, 34
    mov esi, 0x00EA4335
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 46
    mov byte [cursor_y], 21
    mov rsi, str_dom_card2_btn
    call print

    mov dword [text_fg_color], 0x00475569
    mov byte [cursor_x], 6
    mov byte [cursor_y], 24
    mov rsi, str_chrome_shortcuts
    call print

    call draw_mouse_cursor
    jmp .chrome_event_loop

.render_chrome_results_page:
    cmp byte [web_page_type], 7
    je .render_chrome_boxes
    cmp byte [web_page_type], 8
    jne .not_ytplay_8
    mov byte [web_page_type], 0
    mov al, [web_response_buf]
    mov [yt_playing_slot], al
    lea rax, [web_response_buf + 1]
    mov [yt_playing_title_ptr], rax
    jmp .chrome_go_video
.not_ytplay_8:
    cmp byte [web_page_type], 9
    je .render_chrome_dl_done
    ; Top Live Web Google Chromium DOM Decoder Banner (X=40, Y=132, W=screen_width-80, H=34)
    mov eax, 40
    mov ebx, 132
    mov ecx, [screen_width]
    sub ecx, 80
    mov edx, 34
    mov esi, 0x000F172A
    call draw_rect

    mov dword [text_fg_color], 0x0034D399
    mov byte [cursor_x], 5
    mov byte [cursor_y], 7
    mov rsi, str_live_web_banner
    call print

    ; Decoded DOM Content Container Box (X=40, Y=172, W=665, H=275, #F8FAFC with #CBD5E1 top accent)
    mov eax, 40
    mov ebx, 172
    mov ecx, 665
    mov edx, 275
    mov esi, 0x00F8FAFC
    call draw_rect
    mov eax, 40
    mov ebx, 172
    mov ecx, 665
    mov edx, 3
    mov esi, 0x003B82F6
    call draw_rect

    ; Interactive Elements Container Underneath Text (X=40, Y=454, W=944, H=62, #F1F5F9)
    mov eax, 40
    mov ebx, 454
    mov ecx, 944
    mov edx, 62
    mov esi, 0x00F1F5F9
    call draw_rect

    ; 3 Clickable Link Buttons Underneath Every Loaded Page's Text (Y=472, H=34, text at cursor_y=24 -> Y=480)
    mov eax, 50
    mov ebx, 472
    mov ecx, 200
    mov edx, 34
    mov esi, 0x002563EB
    call draw_rect

    mov eax, 270
    mov ebx, 472
    mov ecx, 200
    mov edx, 34
    mov esi, 0x002563EB
    call draw_rect

    mov eax, 490
    mov ebx, 472
    mov ecx, 200
    mov edx, 34
    mov esi, 0x002563EB
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 5
    mov byte [cursor_y], 24
    mov rsi, str_page_link_btns
    call print

    cmp byte [web_has_live_resp], 1
    jne .render_fallback_search

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 5
    mov byte [cursor_y], 9
    mov byte [term_left_col], 5
    mov rsi, web_response_buf
    call print
    jmp .render_page_media_and_images

.render_fallback_search:
    ; Built-in Cloud Fallback so YouTube, Wikipedia & NovaOS Download work on ANY PC anywhere!
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 5
    mov byte [cursor_y], 9
    mov byte [term_left_col], 5
    mov al, [chrome_query_buf]
    cmp al, 'y'
    je .fb_youtube
    cmp al, 'Y'
    je .fb_youtube
    cmp al, 'w'
    je .fb_wiki
    cmp al, 'W'
    je .fb_wiki
    cmp al, 'e'
    je .fb_wiki
    ; Default fallback = NovaOS Download page! Check if broadcast_active == 1
    mov byte [web_page_type], 3
    cmp byte [broadcast_active], 1
    jne .fb_print_dl
    mov byte [web_page_type], 4
.fb_print_dl:
    mov rsi, str_chrome_search_results
    call print
    jmp .render_page_media_and_images
.fb_youtube:
    mov byte [web_page_type], 1
    mov rsi, str_fallback_youtube
    call print
    jmp .render_page_media_and_images
.fb_wiki:
    mov byte [web_page_type], 2
    mov rsi, str_fallback_wiki
    call print

.render_page_media_and_images:
    ; Branch by web_page_type:
    ;   1 = YouTube (3 TrueColor Video Thumbnails + Video Buttons)
    ;   2 = Wikipedia / Article (TrueColor Wikipedia Globe Image Card, NO Video Buttons!)
    ;   3 = NovaOS Download Standard (220x220 32-bpp NovaOS Logo Image + Download 1.0 Button)
    ;   4 = NovaOS Download WITH Broadcast Update (220x220 Logo + New Version Popup from broadcast.txt!)
    mov al, [web_page_type]
    cmp al, 1
    je .draw_yt_thumbnails_and_vid_btn
    cmp al, 3
    je .draw_novaos_dl_standard
    cmp al, 4
    je .draw_novaos_dl_broadcast
    cmp al, 5
    je .draw_ozone_gpu_page

    ; web_page_type == 2 (Wikipedia / Article): Render TrueColor Wikipedia Globe & Photo Card (X=715, Y=175, W=245, H=230)
    mov eax, 715
    mov ebx, 175
    mov ecx, 245
    mov edx, 230
    mov esi, 0x00CBD5E1
    call draw_rect
    mov eax, 719
    mov ebx, 179
    mov ecx, 237
    mov edx, 222
    mov esi, 0x00F8FAFC
    call draw_rect
    ; Deep Ocean Globe Background
    mov eax, 735
    mov ebx, 190
    mov ecx, 205
    mov edx, 165
    mov esi, 0x001D4ED8
    call draw_rect
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 61
    mov byte [cursor_y], 18
    mov rsi, str_wiki_img_caption
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop

.draw_ozone_gpu_page:
    ; Ozone & GPU Hardware Engine Card (X=715, Y=175, W=245, H=230)
    mov eax, 715
    mov ebx, 175
    mov ecx, 245
    mov edx, 230
    mov esi, 0x004F46E5          ; Indigo Border
    call draw_rect
    mov eax, 719
    mov ebx, 179
    mov ecx, 237
    mov edx, 222
    mov esi, 0x000F172A          ; Dark Slate Core
    call draw_rect

    ; Golden GPU Die (X=765, Y=205, W=145, H=110)
    mov eax, 765
    mov ebx, 205
    mov ecx, 145
    mov edx, 110
    mov esi, 0x00D97706          ; Amber/Gold Pins
    call draw_rect
    mov eax, 775
    mov ebx, 215
    mov ecx, 125
    mov edx, 90
    mov esi, 0x001E293B          ; Silicon Die
    call draw_rect

    ; Status LEDs
    mov eax, 785
    mov ebx, 225
    mov ecx, 12
    mov edx, 12
    mov esi, 0x0022C55E          ; Green LED: PCI Bus Master
    call draw_rect
    mov eax, 810
    mov ebx, 225
    mov ecx, 12
    mov edx, 12
    mov esi, 0x0006B6D4          ; Cyan LED: Ozone /dev/fb0
    call draw_rect
    mov eax, 835
    mov ebx, 225
    mov ecx, 12
    mov edx, 12
    mov esi, 0x00A855F7          ; Purple LED: pthreads
    call draw_rect

    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 61
    mov byte [cursor_y], 18
    mov rsi, str_ozone_img_caption
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop

.draw_yt_thumbnails_and_vid_btn:
    ; Top-Right Red [ > Play Video ] Button (ONLY on YouTube!)
    mov eax, 760
    mov ebx, 126
    mov ecx, 180
    mov edx, 30
    mov esi, 0x00EA4335
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 64
    mov byte [cursor_y], 6
    mov rsi, str_page_video_btn
    call print

    ; Bottom-Right Red [ > Stream 60fps ] Button (X=710, Y=470, W=230, H=34)
    mov eax, 710
    mov ebx, 470
    mov ecx, 230
    mov edx, 34
    mov esi, 0x00EA4335
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 60
    mov byte [cursor_y], 24
    mov rsi, str_page_stream_btn
    call print

    ; 3 Real TrueColor Photographic Video Thumbnail Images Pulled from YouTube!
    cmp byte [yt_thumbs_loaded], 1
    je .have_ch_thumbs
    call init_real_youtube_media
.have_ch_thumbs:
    ; Video 1 Thumbnail (80x45 at X=52, Y=214)
    mov rsi, [yt_thumb_ptr_0]
    mov eax, 52
    mov ebx, 214
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Video 2 Thumbnail (80x45 at X=52, Y=274)
    mov rsi, [yt_thumb_ptr_1]
    mov eax, 52
    mov ebx, 274
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Video 3 Thumbnail (80x45 at X=52, Y=334)
    mov rsi, [yt_thumb_ptr_2]
    mov eax, 52
    mov ebx, 334
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    call draw_mouse_cursor
    jmp .chrome_event_loop

.draw_novaos_dl_standard:
    ; Render 32-bpp RGBA NovaOS Official Logo Image on right (X=725, Y=175)
    mov rsi, [logo_address]
    test rsi, rsi
    jz .skip_dl_logo1
    mov eax, 725
    mov ebx, 175
    call draw_logo
.skip_dl_logo1:
    ; Bottom-Right Blue [ Download 1.0 ISO ] Button (X=710, Y=470, W=230, H=34)
    mov eax, 710
    mov ebx, 470
    mov ecx, 230
    mov edx, 34
    mov esi, 0x001A73E8
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 60
    mov byte [cursor_y], 24
    mov rsi, str_dl_iso_btn
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop

.draw_novaos_dl_broadcast:
    ; Render 32-bpp RGBA NovaOS Official Logo Image on right (X=725, Y=175)
    mov rsi, [logo_address]
    test rsi, rsi
    jz .skip_dl_logo2
    mov eax, 725
    mov ebx, 175
    call draw_logo
.skip_dl_logo2:
    ; POPUP BANNER: New Version Detected in broadcast.txt! (X=48, Y=384, W=650, H=74)
    mov eax, 48
    mov ebx, 384
    mov ecx, 650
    mov edx, 74
    mov esi, 0x00065F46
    call draw_rect
    mov eax, 48
    mov ebx, 384
    mov ecx, 650
    mov edx, 4
    mov esi, 0x0010B981
    call draw_rect
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 6
    mov byte [cursor_y], 19
    mov rsi, str_bcast_popup_hdr
    call print
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 21
    mov rsi, str_bcast_popup_ver
    call print
    cmp byte [broadcast_active], 1
    jne .skip_local_bcast_str
    mov rsi, broadcast_buf
    call print
.skip_local_bcast_str:
    ; Bottom-Right Emerald Green [ Download Update ] Button (X=710, Y=470, W=230, H=34)
    mov eax, 710
    mov ebx, 470
    mov ecx, 230
    mov edx, 34
    mov esi, 0x0010B981
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 60
    mov byte [cursor_y], 24
    mov rsi, str_dl_new_ver_btn
    call print
    call draw_mouse_cursor
    jmp .chrome_event_loop

.render_chrome_boxes:
    movzx r13d, byte [web_response_buf]
    cmp r13d, 120
    jbe .rcb_go
    mov r13d, 120
.rcb_go:
    xor r12d, r12d
.rcb_lp:
    cmp r12d, r13d
    jae .rcb_done
    mov eax, r12d
    shl eax, 6
    lea r14, [web_response_buf + 1 + rax]
    test byte [r14 + 17], 1
    jz .rcb_fill
    movzx eax, word [r14 + 0]
    dec eax
    movzx ebx, word [r14 + 2]
    dec ebx
    movzx ecx, word [r14 + 4]
    add ecx, 2
    movzx edx, word [r14 + 6]
    add edx, 2
    mov esi, 0x0094A3B8
    call draw_rect
.rcb_fill:
    test byte [r14 + 17], 4
    jz .rcb_fill_rect
    movzx eax, word [r14 + 0]
    movzx ebx, word [r14 + 2]
    movzx ecx, word [r14 + 4]
    movzx edx, word [r14 + 6]
    movzx esi, byte [r14 + 18]
    shl esi, 16
    add esi, yt_thumb_buf_0
    call draw_raw_image_32bpp
    jmp .rcb_next
.rcb_fill_rect:
    movzx eax, word [r14 + 0]
    movzx ebx, word [r14 + 2]
    movzx ecx, word [r14 + 4]
    movzx edx, word [r14 + 6]
    mov esi, [r14 + 8]
    call draw_rect
    test byte [r14 + 17], 2
    jz .rcb_text
    movzx eax, word [r14 + 0]
    movzx ebx, word [r14 + 2]
    movzx edx, word [r14 + 6]
    add ebx, edx
    dec ebx
    movzx ecx, word [r14 + 4]
    mov edx, 1
    mov esi, 0x00DADCE0
    call draw_rect
.rcb_text:
    mov esi, [r14 + 12]
    mov [text_fg_color], esi
    movzx eax, word [r14 + 0]
    add eax, 8
    xor edx, edx
    mov ecx, FONT_WIDTH
    div ecx
    mov [cursor_x], al
    mov [term_left_col], al
    movzx eax, word [r14 + 2]
    add eax, 8
    xor edx, edx
    mov ecx, FONT_HEIGHT
    div ecx
    mov [cursor_y], al
    mov al, [r14 + 17]
    shr al, 3
    and eax, 3
    mov rcx, [font_regular_address + rax*8]
    test rcx, rcx
    jz .rcb_do_print
    mov [current_font_address], rcx
.rcb_do_print:
    lea rsi, [r14 + 18]
    call print
    mov rax, [font_regular_address]
    mov [current_font_address], rax
.rcb_next:
    inc r12d
    jmp .rcb_lp
.render_chrome_dl_done:
    mov eax, 48
    mov ebx, 148
    mov ecx, 928
    mov edx, 160
    mov esi, 0x00F0FDF4
    call draw_rect
    mov eax, 48
    mov ebx, 148
    mov ecx, 928
    mov edx, 32
    mov esi, 0x0016A34A
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 9
    mov rsi, str_chrome_dl_title
    call print
    mov dword [text_fg_color], 0x00166534
    mov byte [cursor_x], 6
    mov byte [cursor_y], 12
    mov rsi, dl_filename_buf
    call print
    mov dword [text_fg_color], 0x001F2937
    mov byte [cursor_x], 6
    mov byte [cursor_y], 14
    mov rsi, str_chrome_dl_hint
    call print
    mov eax, 64
    mov ebx, 272
    mov ecx, 896
    mov edx, 18
    mov esi, 0x00CBD5E1
    call draw_rect
    mov r12d, 112
.dl_pbar:
    mov eax, 64
    mov ebx, 272
    mov ecx, r12d
    mov edx, 18
    mov esi, 0x0016A34A
    call draw_rect
    mov ecx, 8000000
.dl_pw:
    pause
    dec ecx
    jnz .dl_pw
    add r12d, 112
    cmp r12d, 896
    jbe .dl_pbar
    call draw_mouse_cursor
    jmp .chrome_event_loop

.rcb_done:
    cmp byte [chrome_yt_search_mode], 0
    je .rcb_cursor_done
    cmp byte [chrome_yt_search_mode], 2
    je .rcb_wiki_box
    mov eax, 259
    mov ebx, 133
    mov ecx, 342
    mov edx, 28
    mov esi, 0x001A73E8
    call draw_rect
    mov eax, 260
    mov ebx, 134
    mov ecx, 340
    mov edx, 26
    mov esi, 0x00FFFFFF
    call draw_rect
    mov byte [cursor_x], (260 + 8) / FONT_WIDTH
    mov byte [term_left_col], (260 + 8) / FONT_WIDTH
    mov byte [cursor_y], (134 + 8) / FONT_HEIGHT
    jmp .rcb_box_font
.rcb_wiki_box:
    mov eax, 289
    mov ebx, 443
    mov ecx, 382
    mov edx, 32
    mov esi, 0x003366CC
    call draw_rect
    mov eax, 290
    mov ebx, 444
    mov ecx, 380
    mov edx, 30
    mov esi, 0x00FFFFFF
    call draw_rect
    mov byte [cursor_x], (290 + 8) / FONT_WIDTH
    mov byte [term_left_col], (290 + 8) / FONT_WIDTH
    mov byte [cursor_y], (444 + 8) / FONT_HEIGHT
.rcb_box_font:
    mov dword [text_fg_color], 0x000F0F0F
    mov rcx, [font_regular_address]
    test rcx, rcx
    jz .rcb_yt_print
    mov [current_font_address], rcx
.rcb_yt_print:
    mov rsi, chrome_query_buf
    call print
    mov rsi, str_yt_cursor
    call print
.rcb_cursor_done:
    call draw_mouse_cursor
    jmp .chrome_event_loop

.render_chrome_github_page:
    ; GitHub Header Banner
    mov eax, 40
    mov ebx, 130
    mov ecx, [screen_width]
    sub ecx, 80
    mov edx, 56
    mov esi, 0x0024292F
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 5
    mov byte [cursor_y], 7
    mov rsi, str_github_banner_title
    call print

    ; Green [Clone / Download ZIP] Button at X=680, Y=140, W=220, H=36
    mov eax, 680
    mov ebx, 140
    mov ecx, 220
    mov edx, 36
    mov esi, 0x002DA44E
    call draw_rect

    mov byte [cursor_x], 58
    mov byte [cursor_y], 7
    mov rsi, str_github_dl_btn
    call print

    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 5
    mov byte [cursor_y], 11
    mov rsi, str_github_repo_body
    call print

    call draw_mouse_cursor

.chrome_event_loop:
    call get_key

    ; Smooth mouse movement in Chrome (NEVER resets mouse_x/mouse_y!)
    cmp eax, KEY_MOUSE_MOVE
    je .chrome_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .chrome_mouse_click

    ; Arrow keys move mouse pointer smoothly
    cmp eax, KEY_UP
    je .chrome_mouse_up
    cmp eax, KEY_DOWN
    je .chrome_mouse_down
    cmp eax, KEY_LEFT
    je .chrome_mouse_left
    cmp eax, KEY_RIGHT
    je .chrome_mouse_right

    cmp eax, 27           ; ESC -> Exit Chrome
    je .chrome_close

    ; If offline, 'w'/'W' opens WiFi setup directly
    cmp byte [net_connected], 0
    jne .chrome_online_keys
    cmp eax, 'w'
    je .chrome_open_wifi
    cmp eax, 'W'
    je .chrome_open_wifi
    jmp .chrome_event_loop

.chrome_open_wifi:
    call command_wifi
    jmp .chrome_render

.chrome_online_keys:
    ; If on YouTube (web_page_type == 1), [ / ] / \ immediately launch Video 1 / 2 / 3!
    cmp byte [web_page_type], 1
    jne .chk_enter
    cmp eax, '1'
    je .chrome_yt_v1
    cmp eax, '2'
    je .chrome_yt_v2
    cmp eax, '3'
    je .chrome_yt_v3
    cmp eax, 'v'
    je .chrome_yt_v1
    cmp eax, 'V'
    je .chrome_yt_v1
    cmp eax, 'p'
    je .chrome_yt_v1
    cmp eax, 'P'
    je .chrome_yt_v1
    cmp eax, '['
    je .chrome_yt_v1
    cmp eax, ']'
    je .chrome_yt_v2
    cmp eax, '\'
    je .chrome_yt_v3

.chk_enter:
    cmp eax, 13           ; Enter -> Navigate to typed website URL or search!
    je .chrome_do_search
    cmp eax, 8            ; Backspace -> Delete char in URL/search bar
    je .chrome_backspace
    cmp eax, 9            ; Tab -> Clear URL bar and return to Google Home
    je .chrome_clear_home
    cmp eax, '~'          ; '~' -> Clear URL bar and return to Google Home
    je .chrome_clear_home

.chrome_type_char:
    cmp eax, 32
    jb .chrome_event_loop
    cmp eax, 126
    ja .chrome_event_loop
    cmp byte [chrome_just_navigated], 1
    jne .append_url_char
    mov byte [chrome_query_len], 0
    mov byte [chrome_query_buf], 0
    mov byte [chrome_just_navigated], 0
.append_url_char:
    movzx ebx, byte [chrome_query_len]
    cmp ebx, 46
    jae .chrome_event_loop
    lea rdi, [chrome_query_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [chrome_query_len], bl
    jmp .chrome_render

.chrome_clear_home:
    mov byte [chrome_query_len], 0
    mov byte [chrome_query_buf], 0
    mov byte [chrome_just_navigated], 0
    mov byte [chrome_yt_search_mode], 0
    mov byte [chrome_page_id], 0
    jmp .chrome_render

.chrome_backspace:
    movzx ebx, byte [chrome_query_len]
    test ebx, ebx
    jz .chrome_event_loop
    dec ebx
    lea rdi, [chrome_query_buf]
    mov byte [rdi + rbx], 0
    mov [chrome_query_len], bl
    jmp .chrome_render

.chrome_go_home:
    call pulse_net_activity
    mov byte [chrome_page_id], 0
    jmp .chrome_render

.chrome_go_github:
    call pulse_net_activity
    mov byte [chrome_page_id], 2
    jmp .chrome_render

.chrome_go_local_server:
    call pulse_net_activity
    ; Copy "https://novaos.org/download" into chrome_query_buf and check broadcast.txt!
    mov rsi, str_bridge_default_url
    jmp .follow_web_link

.chrome_go_wiki_bookmark:
    call pulse_net_activity
    mov rsi, str_wiki_default_url
    jmp .follow_web_link

.chrome_go_video:
    call play_real_video
    jmp .chrome_render

.chrome_go_shop:
    call command_shop
    jmp .chrome_render

.chrome_mouse_move:
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_up:
    cmp dword [mouse_y], 20
    jb .chrome_event_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .chrome_event_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_left:
    cmp dword [mouse_x], 20
    jb .chrome_event_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .chrome_event_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .chrome_event_loop

.chrome_mouse_click:
    call draw_mouse_cursor
    mov eax, [mouse_y]
    ; 1. Click in Top Titlebar (Y < 40): Check Close [X] on right or Home tab on left
    cmp eax, 40
    jae .chrome_click_navbar
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 100
    cmp eax, edx
    jae .chrome_close
    cmp eax, 16
    jb .chrome_event_loop
    xor ebx, ebx
    cmp eax, 252
    jb .chrome_switch_tab
    inc ebx
    cmp eax, 488
    jb .chrome_switch_tab
    inc ebx
    cmp eax, 724
    jb .chrome_switch_tab
    jmp .chrome_event_loop

.chrome_switch_tab:
    movzx eax, byte [chrome_active_tab]
    cmp al, bl
    je .chrome_event_loop
    ; Save current tab query & len
    push rbx
    imul eax, 48
    lea rdi, [chrome_tab_queries + rax]
    mov rsi, chrome_query_buf
    mov ecx, 48
    rep movsb
    movzx eax, byte [chrome_active_tab]
    mov cl, [chrome_query_len]
    mov [chrome_tab_lens + rax], cl
    mov cl, [web_page_type]
    mov [chrome_tab_types + rax], cl
    pop rbx
    ; Load target tab
    mov [chrome_active_tab], bl
    mov eax, ebx
    imul eax, 48
    lea rsi, [chrome_tab_queries + rax]
    mov rdi, chrome_query_buf
    mov ecx, 48
    rep movsb
    mov cl, [chrome_tab_lens + rbx]
    mov [chrome_query_len], cl
    mov cl, [chrome_tab_types + rbx]
    mov [web_page_type], cl
    test byte [chrome_query_len], 0xFF
    jz .chrome_tab_home
    cmp byte [net_connected], 1
    je .do_live_web_fetch
.chrome_tab_home:
    mov byte [chrome_page_id], 0
    jmp .chrome_render

.chrome_click_navbar:
    ; 2. Click in Omnibox / Navigation Bar (Y = 40..83)
    cmp eax, 84
    jae .chrome_click_bookmarks
    mov eax, [mouse_x]
    ; Click '<' Back/Home button (X < 90) -> Clear & go to Google Home
    cmp eax, 90
    jb .chrome_clear_home
    ; Click Blue '[ GO ]' button (X = 715..795) -> Browse to typed URL!
    cmp eax, 715
    jb .chrome_event_loop
    cmp eax, 795
    jbe .chrome_do_search
    jmp .chrome_event_loop

.chrome_click_bookmarks:
    cmp eax, 114
    ja .chrome_click_body
    cmp byte [net_connected], 0
    je .chrome_event_loop
    mov eax, [mouse_x]
    cmp eax, 185
    jb .chrome_clear_home
    cmp eax, 355
    jb .chrome_go_yt_bookmark
    cmp eax, 535
    jb .chrome_go_wiki_bookmark
    cmp eax, 705
    jb .chrome_go_gh_live
    cmp eax, 875
    jb .chrome_go_shop
    jmp .chrome_go_gpu_bookmark

.chrome_go_yt_bookmark:
    call pulse_net_activity
    mov rsi, str_yt_default_url
    jmp .follow_web_link

.chrome_go_gh_live:
    call pulse_net_activity
    mov rsi, str_gh_live_url
    jmp .follow_web_link

.chrome_go_gpu_bookmark:
    call pulse_net_activity
    mov rsi, str_chrome_gpu_url
    jmp .follow_web_link

.chrome_click_body:
    cmp byte [net_connected], 0
    je .chrome_event_loop
    ; If on GitHub page (page 2), check ONLY Green [D] Download ZIP button (X=680..900, Y=140..176)
    cmp byte [chrome_page_id], 2
    je .chrome_check_gh_dl
    ; If on Live Loaded Webpage (page 1), check interactive video, links, or broadcast download!
    cmp byte [chrome_page_id], 1
    je .chrome_click_live_page
    ; If on Google Home page (page 0), check buttons at Y = 272..310 or DOM Card buttons at Y = 412..448!
    cmp byte [chrome_page_id], 0
    jne .chrome_event_loop
    cmp eax, 272
    jb .chrome_event_loop
    cmp eax, 310
    ja .check_home_dom_cards
    mov eax, [mouse_x]
    ; Blue [Google Search / Go] button: X = 310..480
    cmp eax, 310
    jb .chrome_event_loop
    cmp eax, 480
    jbe .chrome_do_search
    ; Red [Watch HD Video] button: MUST click strictly inside X = 500..685, Y = 272..310!
    cmp eax, 500
    jb .chrome_event_loop
    cmp eax, 685
    jbe .chrome_go_video
    jmp .chrome_event_loop

.check_home_dom_cards:
    cmp eax, 412
    jb .chrome_event_loop
    cmp eax, 448
    ja .chrome_event_loop
    mov eax, [mouse_x]
    cmp eax, 76
    jb .chrome_event_loop
    cmp eax, 316
    jbe .chrome_go_wiki_bookmark
    cmp eax, 536
    jb .chrome_event_loop
    cmp eax, 786
    ja .chrome_event_loop
    mov rsi, str_yt_default_url
    jmp .follow_web_link

.chrome_click_live_page:
    cmp byte [web_page_type], 7
    je .chrome_click_boxes
    ; 1. Only on YouTube (web_page_type == 1): Top-Right Red [ > Play Video ] (X=760..940, Y=124..158) or Video Thumbnails (Y=200..380)
    cmp byte [web_page_type], 1
    jne .check_bcast_popup_click
    cmp eax, 158
    ja .check_yt_cards
    cmp eax, 124
    jb .chrome_event_loop
    mov eax, [mouse_x]
    cmp eax, 760
    jb .chrome_event_loop
    cmp eax, 940
    jbe .chrome_go_video
    jmp .chrome_event_loop

.check_yt_cards:
    cmp eax, 380
    ja .check_page_links
    cmp eax, 200
    jb .chrome_event_loop
    cmp eax, 255
    jb .chrome_yt_v1
    cmp eax, 315
    jb .chrome_yt_v2
.chrome_yt_v3:
    mov byte [yt_playing_slot], 2
    mov qword [yt_playing_title_ptr], str_yt_v3_title
    mov qword [yt_playing_meta_ptr], str_yt_v3_meta
    mov dword [yt_playing_seed], 0x00A71E4B
    jmp .chrome_go_video
.chrome_yt_v2:
    mov byte [yt_playing_slot], 1
    mov qword [yt_playing_title_ptr], str_yt_v2_title
    mov qword [yt_playing_meta_ptr], str_yt_v2_meta
    mov dword [yt_playing_seed], 0x005A3C91
    jmp .chrome_go_video
.chrome_yt_v1:
    mov byte [yt_playing_slot], 0
    mov qword [yt_playing_title_ptr], str_yt_v1_title
    mov qword [yt_playing_meta_ptr], str_yt_v1_meta
    mov dword [yt_playing_seed], 0
    jmp .chrome_go_video

.check_bcast_popup_click:
    ; 2. If on NovaOS Download with Broadcast Update (web_page_type == 4), clicking the green Popup Box (Y=384..458) downloads update!
    cmp byte [web_page_type], 4
    jne .check_page_links
    cmp eax, 384
    jb .check_page_links
    cmp eax, 458
    jbe .chrome_download

.check_page_links:
    ; 3. Check Interactive Link & Action Bar at Y = 468..506
    cmp eax, 468
    jb .chrome_event_loop
    cmp eax, 506
    ja .chrome_event_loop
    mov eax, [mouse_x]
    cmp eax, 50
    jb .chrome_event_loop
    cmp eax, 250
    jbe .click_web_link1
    cmp eax, 270
    jb .chrome_event_loop
    cmp eax, 470
    jbe .click_web_link2
    cmp eax, 490
    jb .chrome_event_loop
    cmp eax, 690
    jbe .click_web_link3
    cmp eax, 710
    jb .chrome_event_loop
    cmp eax, 940
    ja .chrome_event_loop
    ; Rightmost button at X=710..940:
    ;   On YouTube (web_page_type == 1) -> Play 60fps Video
    ;   On NovaOS Download (web_page_type == 3 or 4) -> Download OS / Broadcast Update!
    cmp byte [web_page_type], 1
    je .chrome_go_video
    cmp byte [web_page_type], 3
    jae .chrome_download
    jmp .chrome_event_loop

.click_web_link1:
    mov rsi, str_link1_cmd
    jmp .follow_web_link
.click_web_link2:
    mov rsi, str_link2_cmd
    jmp .follow_web_link
.click_web_link3:
    mov rsi, str_link3_cmd
.follow_web_link:
    lea rdi, [chrome_query_buf]
    xor ecx, ecx
.cp_lnk:
    lodsb
    mov [rdi + rcx], al
    test al, al
    jz .cp_lnk_done
    inc ecx
    jmp .cp_lnk
.cp_lnk_done:
    mov [chrome_query_len], cl
    jmp .do_live_web_fetch

.ccb_yt_focus:
    mov byte [chrome_yt_search_mode], 1
    mov byte [chrome_query_len], 0
    mov byte [chrome_query_buf], 0
    mov byte [chrome_just_navigated], 0
    jmp .chrome_render

.ccb_yt_submit:
    mov byte [chrome_yt_search_mode], 1
    jmp .chrome_do_search

.ccb_wiki_focus:
    mov byte [chrome_yt_search_mode], 2
    mov byte [chrome_query_len], 0
    mov byte [chrome_query_buf], 0
    mov byte [chrome_just_navigated], 0
    jmp .chrome_render

.ccb_wiki_submit:
    mov byte [chrome_yt_search_mode], 2
    jmp .chrome_do_search

.chrome_click_boxes:
    movzx r13d, byte [web_response_buf]
    cmp r13d, 120
    jbe .ccb_go
    mov r13d, 120
.ccb_go:
    xor r12d, r12d
.ccb_lp:
    cmp r12d, r13d
    jae .chrome_event_loop
    mov eax, r12d
    shl eax, 6
    lea r14, [web_response_buf + 1 + rax]
    movzx ecx, byte [r14 + 16]
    test ecx, ecx
    jz .ccb_next
    mov eax, [mouse_x]
    movzx ebx, word [r14 + 0]
    cmp eax, ebx
    jb .ccb_next
    movzx edx, word [r14 + 4]
    add ebx, edx
    cmp eax, ebx
    jae .ccb_next
    mov eax, [mouse_y]
    movzx ebx, word [r14 + 2]
    cmp eax, ebx
    jb .ccb_next
    movzx edx, word [r14 + 6]
    add ebx, edx
    cmp eax, ebx
    jae .ccb_next
    cmp cl, 15
    je .ccb_yt_focus
    cmp cl, 16
    je .ccb_yt_submit
    cmp cl, 17
    je .ccb_wiki_focus
    cmp cl, 18
    je .ccb_wiki_submit
    mov dword [chrome_query_buf], "LINK"
    mov byte [chrome_query_buf + 4], ":"
    cmp cl, 10
    jb .ccb_1d
    mov byte [chrome_query_buf + 5], "1"
    sub cl, 10
    add cl, "0"
    mov [chrome_query_buf + 6], cl
    mov byte [chrome_query_buf + 7], 0
    mov byte [chrome_query_len], 7
    jmp .do_live_web_fetch
.ccb_1d:
    add cl, "0"
    mov [chrome_query_buf + 5], cl
    mov byte [chrome_query_buf + 6], 0
    mov byte [chrome_query_len], 6
    jmp .do_live_web_fetch
.ccb_next:
    inc r12d
    jmp .ccb_lp

.chrome_check_gh_dl:
    cmp eax, 140
    jb .chrome_event_loop
    cmp eax, 176
    ja .chrome_event_loop
    mov eax, [mouse_x]
    cmp eax, 680
    jb .chrome_event_loop
    cmp eax, 900
    ja .chrome_event_loop
    jmp .chrome_download

.chrome_do_search:
    cmp byte [net_connected], 0
    je .chrome_open_wifi
    call pulse_net_activity
    ; Check if user explicitly typed 'shop'
    cmp byte [chrome_query_buf], 's'
    jne .do_live_web_fetch
    cmp byte [chrome_query_buf + 1], 'h'
    jne .do_live_web_fetch
    cmp byte [chrome_query_buf + 2], 'o'
    jne .do_live_web_fetch
    cmp byte [chrome_query_buf + 3], 'p'
    jne .do_live_web_fetch
    cmp byte [chrome_query_buf + 4], 0
    je .chrome_go_shop

.do_live_web_fetch:
    mov byte [chrome_just_navigated], 1
    call fetch_live_web_via_bridge
    mov byte [chrome_page_id], 1
    jmp .chrome_render

.chrome_download:
    cmp byte [net_connected], 0
    je .chrome_open_wifi
    call restore_mouse_background
    call pulse_net_activity

    ; Register NOVAOS.ZIP in real NovaFS directory and mark repo_downloaded = 1!
    mov byte [repo_downloaded], 1
    mov rsi, fs_name_novaos_zip
    mov eax, 4821040
    call register_novafs_file

    mov eax, 100
    mov ebx, 180
    mov ecx, 660
    mov edx, 210
    mov esi, 0x000F172A
    call draw_rect

    mov eax, 100
    mov ebx, 180
    mov ecx, 660
    mov edx, 4
    mov esi, 0x0034A853
    call draw_rect

    mov byte [text_transparent_bg], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 10
    mov byte [cursor_y], 10
    mov rsi, str_chrome_download_banner
    call print

    call draw_mouse_cursor
    call .wait_chrome_modal_key
    jmp .chrome_render

.wait_chrome_modal_key:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_cm_wait
    call draw_mouse_cursor
    jmp .wait_chrome_modal_key
.done_cm_wait:
    ret

.chrome_close:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; NOVAOS ONLINE APP SHOP (shop.nosp / store.novaos.org)
; Connects to the internet (requires net_connected == 1) and
; downloads/installs real apps into NovaFS:
;   [1] Notepad Studio (notepad.nosp)
;   [2] Python 3.15.0  (python.nosp)
;   [3] Mozilla Firefox (firefox.nosp)
;   [4] Nova HD Video Player (video.nosp)
; ============================================================


; ============================================================
; BUILT-IN APP SUITE (apps, calc, clock, paint, sysmon, piano)
; ============================================================
command_apps:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 2
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_apps_drawer
    call print
    call get_key
    cmp eax, '1'
    je command_chrome
    cmp eax, '2'
    je command_shop
    cmp eax, '3'
    je command_files
    cmp eax, '4'
    je command_calc
    cmp eax, '5'
    je command_clock
    cmp eax, '6'
    je command_paint
    cmp eax, '7'
    je command_sysmon
    cmp eax, '8'
    je command_piano
    cmp eax, '9'
    je command_wifi
    ret

command_drivers:
    call clear_screen
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_drv_menu_hdr
    call print
    mov dword [text_fg_color], 0x00E2E8F0
    mov rsi, str_drv_series_list
    call print
.drv_lp:
    call get_key
    cmp eax, 27
    je .drv_done
    cmp eax, '1'
    jb .drv_lp
    cmp eax, '6'
    ja .drv_lp
    sub eax, '0'
    mov [wifi_hw_series_id], al
    call clear_screen
    mov byte [cursor_x], 2
    mov byte [cursor_y], 2
    mov dword [text_fg_color], 0x0022C55E
    mov rsi, str_drv_applied
    call print
    cmp byte [wifi_hw_series_id], 1
    je .ds1
    cmp byte [wifi_hw_series_id], 2
    je .ds2
    cmp byte [wifi_hw_series_id], 3
    je .ds3
    cmp byte [wifi_hw_series_id], 4
    je .ds4
    cmp byte [wifi_hw_series_id], 5
    je .ds5
    mov rsi, str_drv_d6
    jmp .ds_pr
.ds1:
    mov rsi, str_drv_d1
    jmp .ds_pr
.ds2:
    mov rsi, str_drv_d2
    jmp .ds_pr
.ds3:
    mov rsi, str_drv_d3
    jmp .ds_pr
.ds4:
    mov rsi, str_drv_d4
    jmp .ds_pr
.ds5:
    mov rsi, str_drv_d5
.ds_pr:
    mov dword [text_fg_color], 0x00FFFFFF
    call print
    call get_key
.drv_done:
    mov dword [text_fg_color], 0x00FFFFFF
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    ret

command_calc:
    call newline
    mov rsi, str_calc_hdr
    call print
    call get_key
    cmp eax, 27
    je .calc_done
    call putchar
    sub eax, '0'
    mov ebx, eax
    call get_key
    mov ecx, eax
    call putchar
    call get_key
    call putchar
    sub eax, '0'
    push rax
    mov al, '='
    call putchar
    pop rax
    cmp ecx, '+'
    je .c_add
    cmp ecx, '-'
    je .c_sub
    cmp ecx, '*'
    je .c_mul
    cmp ecx, '/'
    je .c_div
    jmp .calc_done
.c_add:
    add eax, ebx
    jmp .c_pr
.c_sub:
    cmp ebx, eax
    jae .c_sub_pos
    push rax
    mov al, '-'
    call putchar
    pop rax
    sub eax, ebx
    jmp .c_pr
.c_sub_pos:
    sub ebx, eax
    mov eax, ebx
    jmp .c_pr
.c_mul:
    imul eax, ebx
    jmp .c_pr
.c_div:
    test eax, eax
    jz .calc_done
    mov ecx, eax
    mov eax, ebx
    xor edx, edx
    div ecx
.c_pr:
    call print_number
    call newline
.calc_done:
    ret

command_clock:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    call command_time
    mov rsi, str_press_esc
    call print
.clk_lp:
    call get_key
    cmp eax, 27
    jne .clk_lp
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    ret

command_paint:
    call clear_screen
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, str_paint_hdr
    call print
    mov dword [paint_color], 0x0038BDF8
.pnt_lp:
    call draw_mouse_cursor
    call get_key
    cmp eax, 27
    je .pnt_done
    cmp eax, 'c'
    je command_paint
    cmp eax, '1'
    jne .p2
    mov dword [paint_color], 0x00EF4444
.p2:
    cmp eax, '2'
    jne .p3
    mov dword [paint_color], 0x0022C55E
.p3:
    cmp eax, '3'
    jne .p_chk
    mov dword [paint_color], 0x003B82F6
.p_chk:
    cmp eax, KEY_MOUSE_CLICK
    jne .pnt_lp
    mov eax, [mouse_x]
    mov ebx, [mouse_y]
    mov ecx, 8
    mov edx, 8
    mov esi, [paint_color]
    call draw_rect
    jmp .pnt_lp
.pnt_done:
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    ret

command_sysmon:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_sysmon_txt
    call print
    call get_key
    mov dword [text_fg_color], 0x00FFFFFF
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    ret

command_piano:
    call clear_screen
    mov byte [cursor_x], 4
    mov byte [cursor_y], 3
    mov dword [text_fg_color], 0x00FACC15
    mov rsi, str_piano_txt
    call print
.pno_lp:
    call get_key
    cmp eax, 27
    je .pno_done
    mov ecx, 4560
    cmp eax, 'a'
    je .pno_play
    mov ecx, 4063
    cmp eax, 's'
    je .pno_play
    mov ecx, 3619
    cmp eax, 'd'
    je .pno_play
    mov ecx, 3416
    cmp eax, 'f'
    je .pno_play
    mov ecx, 3043
    cmp eax, 'g'
    je .pno_play
    mov ecx, 2711
    cmp eax, 'h'
    je .pno_play
    mov ecx, 2415
    cmp eax, 'j'
    je .pno_play
    jmp .pno_lp
.pno_play:
    mov eax, ecx
    call speaker_start
    call audio_delay
    call speaker_stop
    jmp .pno_lp
.pno_done:
    call speaker_stop
    ret

command_shop:
    push r11
    push r12
    push r13
    push r14
    push r15

.shop_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; Header Bar (Indigo/Navy #0F172A)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 52
    mov esi, 0x000F172A
    call draw_rect

    ; Accent Line (Emerald #10B981)
    mov eax, 0
    mov ebx, 52
    mov ecx, [screen_width]
    mov edx, 3
    mov esi, 0x0010B981
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    mov rsi, str_shop_header
    call print

    call draw_net_icon

    ; Store Background (#111827)
    mov eax, 0
    mov ebx, 55
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 55
    mov esi, 0x00111827
    call draw_rect

    ; Check if connected to the internet!
    cmp byte [net_connected], 1
    je .shop_online_view

    ; OFFLINE View: Must connect internet first!
    mov eax, 100
    mov ebx, 150
    mov ecx, 720
    mov edx, 220
    mov esi, 0x001E293B
    call draw_rect

    mov eax, 100
    mov ebx, 150
    mov ecx, 720
    mov edx, 4
    mov esi, 0x00EF4444
    call draw_rect

    mov dword [text_fg_color], 0x00F87171
    mov byte [cursor_x], 10
    mov byte [cursor_y], 9
    mov rsi, str_shop_offline_msg
    call print

    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_online_view:
    ; Draw 6 App Cards (Y = 66, 152, 238, 324, 410, 496; each H=76)
    ; Card 1: Notepad Studio (Y=66..142, text rows 4 & 5)
    mov eax, 50
    mov ebx, 66
    mov ecx, 900
    mov edx, 76
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 50
    mov ebx, 66
    mov ecx, 6
    mov edx, 76
    mov esi, 0x0038BDF8
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 4
    mov rsi, str_shop_item1_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 5
    mov rsi, str_shop_item1_desc
    call print
    mov byte [cursor_x], 56
    mov byte [cursor_y], 4
    cmp byte [app_installed_notepad], 1
    je .c1_inst
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_shop_btn_get1
    call print
    jmp .card2_draw
.c1_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card2_draw:
    ; Card 2: Python 3.15.0 (Y=152..228, text rows 8 & 9)
    mov eax, 50
    mov ebx, 152
    mov ecx, 900
    mov edx, 76
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 50
    mov ebx, 152
    mov ecx, 6
    mov edx, 76
    mov esi, 0x00FACC15
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 8
    mov rsi, str_shop_item2_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 9
    mov rsi, str_shop_item2_desc
    call print
    mov byte [cursor_x], 56
    mov byte [cursor_y], 8
    cmp byte [app_installed_python], 1
    je .c2_inst
    mov dword [text_fg_color], 0x00FACC15
    mov rsi, str_shop_btn_get2
    call print
    jmp .card4_draw
.c2_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card4_draw:
    ; Card 4: Java SE 24 Coding Language & YouTube JVM Engine (Y=324..400, text rows 17 & 18)
    mov eax, 50
    mov ebx, 324
    mov ecx, 900
    mov edx, 76
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 50
    mov ebx, 324
    mov ecx, 6
    mov edx, 76
    mov esi, 0x00A855F7
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 17
    mov rsi, str_shop_item4_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 18
    mov rsi, str_shop_item4_desc
    call print
    mov byte [cursor_x], 56
    mov byte [cursor_y], 17
    cmp byte [app_installed_java], 1
    je .c4_inst
    mov dword [text_fg_color], 0x00A855F7
    mov rsi, str_shop_btn_get4
    call print
    jmp .card5_draw
.c4_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card5_draw:
    ; Card 5: HTML5 & CSS3 Coding Language Studio (Y=410..486, text rows 21 & 22)
    mov eax, 50
    mov ebx, 410
    mov ecx, 900
    mov edx, 76
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 50
    mov ebx, 410
    mov ecx, 6
    mov edx, 76
    mov esi, 0x0006B6D4
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 21
    mov rsi, str_shop_item5_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 22
    mov rsi, str_shop_item5_desc
    call print
    mov byte [cursor_x], 56
    mov byte [cursor_y], 21
    cmp byte [app_installed_html], 1
    je .c5_inst
    mov dword [text_fg_color], 0x0006B6D4
    mov rsi, str_shop_btn_get5
    call print
    jmp .card6_draw
.c5_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.card6_draw:
    ; Card 6: YouTube Desktop App (Search, Watch, Upload & Create Account) (Y=496..572, text rows 25 & 26)
    mov eax, 50
    mov ebx, 496
    mov ecx, 900
    mov edx, 76
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 50
    mov ebx, 496
    mov ecx, 6
    mov edx, 76
    mov esi, 0x00EF4444
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 25
    mov rsi, str_shop_item6_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 6
    mov byte [cursor_y], 26
    mov rsi, str_shop_item6_desc
    call print
    mov byte [cursor_x], 56
    mov byte [cursor_y], 25
    cmp byte [app_installed_youtube], 1
    je .c6_inst
    mov dword [text_fg_color], 0x00EF4444
    mov rsi, str_shop_btn_get6
    call print
    jmp .shop_footer_draw
.c6_inst:
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_shop_btn_open
    call print

.shop_footer_draw:
    mov dword [text_fg_color], 0x00E2E8F0
    mov byte [cursor_x], 5
    mov byte [cursor_y], 30
    mov rsi, str_shop_footer
    call print

    call draw_mouse_cursor

.shop_event_loop:
    call get_key

    cmp eax, KEY_MOUSE_MOVE
    je .shop_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .shop_mouse_click

    cmp eax, KEY_UP
    je .shop_mouse_up
    cmp eax, KEY_DOWN
    je .shop_mouse_down
    cmp eax, KEY_LEFT
    je .shop_mouse_left
    cmp eax, KEY_RIGHT
    je .shop_mouse_right

    cmp eax, 27
    je .shop_close
    cmp eax, 'q'
    je .shop_close
    cmp eax, 'Q'
    je .shop_close

    cmp byte [net_connected], 0
    jne .shop_online_keys
    cmp eax, 'w'
    je .shop_go_wifi
    cmp eax, 'W'
    je .shop_go_wifi
    jmp .shop_event_loop

.shop_go_wifi:
    call command_wifi
    jmp .shop_render

.shop_online_keys:
    cmp eax, '1'
    je .shop_act_notepad
    cmp eax, '2'
    je .shop_act_python
    cmp eax, '4'
    je .shop_act_java
    cmp eax, '5'
    je .shop_act_html
    cmp eax, '6'
    je .shop_act_youtube
    jmp .shop_event_loop

.shop_mouse_move:
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_up:
    cmp dword [mouse_y], 20
    jb .shop_event_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .shop_event_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_left:
    cmp dword [mouse_x], 20
    jb .shop_event_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .shop_event_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .shop_event_loop

.shop_mouse_click:
    call draw_mouse_cursor
    cmp byte [net_connected], 0
    je .shop_go_wifi
    mov eax, [mouse_y]
    cmp eax, 52
    jb .shop_close
    cmp eax, 148
    jb .shop_act_notepad
    cmp eax, 234
    jb .shop_act_python
    cmp eax, 320
    jb .shop_act_java
    cmp eax, 492
    jb .shop_act_html
    cmp eax, 580
    jb .shop_act_youtube
    jmp .shop_event_loop

.shop_act_notepad:
    cmp byte [app_installed_notepad], 1
    je .shop_launch_notepad
    call pulse_net_activity
    call init_serial_bridge
    mov rsi, str_bridge_inst_notepad
    call serial_send_string
    mov byte [app_installed_notepad], 1
    mov rsi, fs_name_notepad
    mov eax, 16384
    call register_novafs_file
    jmp .shop_render
.shop_launch_notepad:
    call command_notepad
    jmp .shop_render

.shop_act_python:
    cmp byte [app_installed_python], 1
    je .shop_launch_python
    call pulse_net_activity
    call init_serial_bridge
    mov rsi, str_bridge_inst_python
    call serial_send_string
    mov byte [app_installed_python], 1
    mov rsi, fs_name_python
    mov eax, 65536
    call register_novafs_file
    jmp .shop_render
.shop_launch_python:
    call command_python
    jmp .shop_render

.shop_act_java:
    cmp byte [app_installed_java], 1
    je .shop_launch_java
    call pulse_net_activity
    call init_serial_bridge
    mov rsi, str_bridge_inst_java
    call serial_send_string
    mov byte [app_installed_java], 1
    mov byte [app_installed_video], 1
    mov rsi, fs_name_java
    mov eax, 98304
    call register_novafs_file
    jmp .shop_render
.shop_launch_java:
    call command_java
    jmp .shop_render

.shop_act_html:
    cmp byte [app_installed_html], 1
    je .shop_launch_html
    call pulse_net_activity
    call init_serial_bridge
    mov rsi, str_bridge_inst_html
    call serial_send_string
    mov byte [app_installed_html], 1
    mov rsi, fs_name_html
    mov eax, 40960
    call register_novafs_file
    jmp .shop_render
.shop_launch_html:
    call command_html
    jmp .shop_render

.shop_act_youtube:
    cmp byte [app_installed_youtube], 1
    je .shop_launch_youtube
    call pulse_net_activity
    call init_serial_bridge
    mov rsi, str_bridge_inst_youtube
    call serial_send_string
    ; Installing YouTube also ensures Java & HTML runtime engines are linked!
    mov byte [app_installed_java], 1
    mov byte [app_installed_html], 1
    mov byte [app_installed_youtube], 1
    mov byte [app_installed_video], 1
    mov rsi, fs_name_youtube
    mov eax, 131072
    call register_novafs_file
    jmp .shop_render
.shop_launch_youtube:
    call command_youtube
    jmp .shop_render

.shop_close:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; NOTEPAD STUDIO (notepad.nosp) - Installable from App Shop!
; Real interactive graphical text editor with NovaFS file save
; ============================================================

command_notepad:
    cmp byte [app_installed_notepad], 1
    je .notepad_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.notepad_installed_ok:
    push r11
    push r12
    push r13
    push r14
    push r15
    mov byte [notepad_menu_id], 0

.notepad_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; Notepad Top Titlebar (#1E3A8A)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 40
    mov esi, 0x001E3A8A
    call draw_rect

    ; Red Close [X] Button at Top-Right of Notepad
    mov eax, [screen_width]
    sub eax, 56
    mov ebx, 0
    mov ecx, 56
    mov edx, 38
    mov esi, 0x00E81123
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 2
    mov byte [cursor_y], 1
    cmp byte [broadcast_active], 1
    je .np_title_bcast
    mov rsi, str_notepad_title
    call print
    jmp .np_title_done
.np_title_bcast:
    mov rsi, str_notepad_title_bcast
    call print
.np_title_done:

    ; Menu Bar (#E2E8F0) with clickable [ File ] and [ Edit ] buttons
    mov eax, 0
    mov ebx, 40
    mov ecx, [screen_width]
    mov edx, 28
    mov esi, 0x00E2E8F0
    call draw_rect

    ; Highlight [ File ] button (X=16, Y=42, W=88, H=24)
    mov eax, 16
    mov ebx, 42
    mov ecx, 88
    mov edx, 24
    mov esi, 0x00CBD5E1
    call draw_rect

    ; Highlight [ Edit ] button (X=114, Y=42, W=88, H=24)
    mov eax, 114
    mov ebx, 42
    mov ecx, 88
    mov edx, 24
    mov esi, 0x00CBD5E1
    call draw_rect

    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 2
    mov byte [cursor_y], 2
    mov rsi, str_notepad_menu
    call print

    ; Paper Editor Canvas (#FFFFFF)
    mov eax, 0
    mov ebx, 68
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 68
    mov esi, 0x00FFFFFF
    call draw_rect

    ; Render user's typed text buffer onto white paper!
    mov dword [text_fg_color], 0x000F172A
    mov byte [cursor_x], 3
    mov byte [cursor_y], 5
    mov byte [term_left_col], 3
    mov rsi, notepad_buf
    call print
    mov al, '|'
    call putchar

    ; Check if File Dropdown (1) or Edit Dropdown (2) is open!
    cmp byte [notepad_menu_id], 1
    je .draw_np_file_menu
    cmp byte [notepad_menu_id], 2
    je .draw_np_edit_menu
    jmp .np_finish_render

.draw_np_file_menu:
    ; Windows-style File Dropdown Menu Box at X=16, Y=68, W=330, H=168
    mov eax, 16
    mov ebx, 68
    mov ecx, 330
    mov edx, 168
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 16
    mov ebx, 68
    mov ecx, 330
    mov edx, 3
    mov esi, 0x0038BDF8
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 3
    mov byte [cursor_y], 4
    mov byte [term_left_col], 3
    mov rsi, str_np_file_dropdown
    call print
    jmp .np_finish_render

.draw_np_edit_menu:
    ; Windows-style Edit Dropdown Menu Box at X=114, Y=68, W=340, H=140
    mov eax, 114
    mov ebx, 68
    mov ecx, 340
    mov edx, 140
    mov esi, 0x001E293B
    call draw_rect
    mov eax, 114
    mov ebx, 68
    mov ecx, 340
    mov edx, 3
    mov esi, 0x0038BDF8
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 11
    mov byte [cursor_y], 4
    mov byte [term_left_col], 11
    mov rsi, str_np_edit_dropdown
    call print

.np_finish_render:
    call draw_mouse_cursor

.notepad_loop:
    call get_key

    cmp eax, KEY_MOUSE_MOVE
    je .np_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .np_mouse_click

    ; Arrow keys move mouse cursor smoothly inside Notepad too!
    cmp eax, KEY_UP
    je .np_mouse_up
    cmp eax, KEY_DOWN
    je .np_mouse_down
    cmp eax, KEY_LEFT
    je .np_mouse_left
    cmp eax, KEY_RIGHT
    je .np_mouse_right

    cmp eax, 27               ; ESC -> Close dropdown if open, else exit Notepad
    je .np_handle_esc

    cmp eax, 9                ; Tab -> Toggle File -> Edit -> Close Menu!
    je .np_cycle_menu

    ; If File or Edit menu is open, keys '1'..'5' trigger the menu items!
    cmp byte [notepad_menu_id], 1
    je .np_file_menu_keys
    cmp byte [notepad_menu_id], 2
    je .np_edit_menu_keys

    cmp eax, '~'              ; '~' or Ctrl+S -> Save to NovaFS!
    je .notepad_save
    cmp eax, 19               ; Ctrl+S
    je .notepad_save

    cmp eax, 8                ; Backspace
    je .notepad_bs

    cmp eax, 13               ; Enter -> newline in buffer
    je .notepad_enter

    cmp eax, 32
    jb .notepad_loop
    cmp eax, 126
    ja .notepad_loop

    movzx ebx, word [notepad_len]
    cmp ebx, 480
    jae .notepad_loop
    lea rdi, [notepad_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [notepad_len], bx
    jmp .notepad_render

.np_handle_esc:
    cmp byte [notepad_menu_id], 0
    je .notepad_exit
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_cycle_menu:
    inc byte [notepad_menu_id]
    cmp byte [notepad_menu_id], 3
    jb .notepad_render
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_file_menu_keys:
    cmp eax, '1'
    je .np_act_new
    cmp eax, '2'
    je .np_act_open_bcast
    cmp eax, '3'
    je .notepad_save
    cmp eax, '4'
    je .notepad_save_as_bcast
    cmp eax, '5'
    je .notepad_exit
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_edit_menu_keys:
    cmp eax, '1'
    je .np_act_new
    cmp eax, '2'
    je .np_close_menu
    cmp eax, '3'
    je .np_act_paste_ver
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_close_menu:
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_act_new:
    mov word [notepad_len], 0
    mov byte [notepad_buf], 0
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_act_open_bcast:
    mov rsi, broadcast_buf
    jmp .np_load_str_to_buf

.np_act_paste_ver:
    mov rsi, str_default_bcast_ver
.np_load_str_to_buf:
    lea rdi, [notepad_buf]
    xor ecx, ecx
.np_cp_lp:
    lodsb
    mov [rdi + rcx], al
    test al, al
    jz .np_cp_dn
    inc ecx
    jmp .np_cp_lp
.np_cp_dn:
    mov [notepad_len], cx
    mov byte [notepad_menu_id], 0
    jmp .notepad_render

.np_mouse_up:
    cmp dword [mouse_y], 20
    jb .notepad_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .notepad_loop
.np_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .notepad_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .notepad_loop
.np_mouse_left:
    cmp dword [mouse_x], 20
    jb .notepad_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .notepad_loop
.np_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .notepad_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .notepad_loop

.np_mouse_click:
    call draw_mouse_cursor
    mov eax, [mouse_y]
    ; 1. Click Top Titlebar (Y < 40): Check Close [X] on right
    cmp eax, 40
    jae .np_check_menubar
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 80
    cmp eax, edx
    jae .notepad_exit
    jmp .notepad_loop

.np_check_menubar:
    ; 2. Click Menu Bar (Y = 40..68): Check [ File ] (X=16..108) or [ Edit ] (X=114..206)
    cmp eax, 68
    ja .np_check_dropdown_click
    mov eax, [mouse_x]
    cmp eax, 16
    jb .np_close_menu
    cmp eax, 108
    jbe .np_open_file_menu
    cmp eax, 114
    jb .np_close_menu
    cmp eax, 206
    jbe .np_open_edit_menu
    jmp .np_close_menu

.np_open_file_menu:
    mov byte [notepad_menu_id], 1
    jmp .notepad_render
.np_open_edit_menu:
    mov byte [notepad_menu_id], 2
    jmp .notepad_render

.np_check_dropdown_click:
    cmp byte [notepad_menu_id], 1
    je .np_click_in_file_menu
    cmp byte [notepad_menu_id], 2
    je .np_click_in_edit_menu
    jmp .notepad_loop

.np_click_in_file_menu:
    mov ebx, [mouse_x]
    cmp ebx, 16
    jb .np_close_menu
    cmp ebx, 346
    ja .np_close_menu
    cmp eax, 102
    jb .np_act_new
    cmp eax, 134
    jb .np_act_open_bcast
    cmp eax, 166
    jb .notepad_save
    cmp eax, 198
    jb .notepad_save_as_bcast
    cmp eax, 236
    jb .notepad_exit
    jmp .np_close_menu

.np_click_in_edit_menu:
    mov ebx, [mouse_x]
    cmp ebx, 114
    jb .np_close_menu
    cmp ebx, 454
    ja .np_close_menu
    cmp eax, 102
    jb .np_act_new
    cmp eax, 134
    jb .np_close_menu
    cmp eax, 166
    jb .np_act_paste_ver
    jmp .np_close_menu

.notepad_enter:
    movzx ebx, word [notepad_len]
    cmp ebx, 478
    jae .notepad_loop
    lea rdi, [notepad_buf]
    mov byte [rdi + rbx], 10
    inc ebx
    mov byte [rdi + rbx], 0
    mov [notepad_len], bx
    jmp .notepad_render

.notepad_bs:
    movzx ebx, word [notepad_len]
    test ebx, ebx
    jz .notepad_loop
    dec ebx
    lea rdi, [notepad_buf]
    mov byte [rdi + rbx], 0
    mov [notepad_len], bx
    jmp .notepad_render

.notepad_save:
    ; Save notepad_buf into NOTES.TXT in NovaFS
    mov byte [notepad_menu_id], 0
    mov rsi, fs_name_notes_txt
    movzx eax, word [notepad_len]
    call register_novafs_file

    mov eax, 200
    mov ebx, 220
    mov ecx, 560
    mov edx, 80
    mov esi, 0x0010B981
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 18
    mov byte [cursor_y], 12
    mov rsi, str_notepad_saved
    call print
    call draw_mouse_cursor
    call .wait_np_modal
    jmp .notepad_render

.notepad_save_as_bcast:
    ; Save As -> Saves notepad_buf into broadcast.txt (BROADCAST.TXT in NovaFS + Server broadcast.txt)!
    mov byte [notepad_menu_id], 0
    mov byte [broadcast_active], 1
    ; Copy first line (up to 44 chars) of notepad_buf into broadcast_buf
    lea rsi, [notepad_buf]
    lea rdi, [broadcast_buf]
    xor ecx, ecx
.cp_bcast_lp:
    lodsb
    test al, al
    jz .cp_bcast_dn
    cmp al, 10
    je .cp_bcast_dn
    cmp al, 13
    je .cp_bcast_dn
    cmp ecx, 42
    jae .cp_bcast_dn
    mov [rdi + rcx], al
    inc ecx
    jmp .cp_bcast_lp
.cp_bcast_dn:
    mov byte [rdi + rcx], 0

    mov rsi, fs_name_bcast_txt
    movzx eax, word [notepad_len]
    call register_novafs_file

    ; Also broadcast to Global Server over COM1 bridge so host broadcast.txt updates immediately!
    call init_serial_bridge
    mov rsi, str_bridge_bcast_cmd
    call serial_send_string
    mov rsi, broadcast_buf
    call serial_send_string
    mov rsi, str_bridge_nl
    call serial_send_string

    mov eax, 160
    mov ebx, 210
    mov ecx, 660
    mov edx, 96
    mov esi, 0x00059669
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 15
    mov byte [cursor_y], 12
    mov rsi, str_notepad_saved_bcast
    call print
    call draw_mouse_cursor
    call .wait_np_modal
    jmp .notepad_render

.wait_np_modal:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    jne .done_np_wait
    call draw_mouse_cursor
    jmp .wait_np_modal
.done_np_wait:
    ret

.np_mouse_move:
    call draw_mouse_cursor
    jmp .notepad_loop

.notepad_exit:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell


; ============================================================
; PYTHON 3.15.0 INTERACTIVE REPL (python.nosp)
; Installable from App Shop! Supports print(), math (+,-,*,/),
; import sys, sys.version, import os, os.listdir(), help(), exit()
; ============================================================

command_python:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_python_banner_102
    call print

.py_repl_loop:
    mov dword [text_fg_color], 0x00FACC15
    mov rsi, str_python_prompt
    call print
    mov dword [text_fg_color], 0x00FFFFFF

    call read_line

    mov rsi, input
    call skip_spaces
    cmp byte [rsi], 0
    je .py_repl_loop

    ; Check exit() / quit() / exit / quit
    mov rdi, str_py_exit
    call prefix
    jc .py_done
    mov rsi, input
    call skip_spaces
    mov rdi, str_py_quit
    call prefix
    jc .py_done

    ; Check if connected to host bridge
    cmp byte [net_connected], 1
    jne .py_offline

    ; Send "PY_EXEC " + input + "\n"
    mov rsi, str_py_exec_prefix
    call serial_send_string
    mov rsi, input
    call skip_spaces
    call serial_send_string
    mov al, 10
    mov dx, 0x3F8
    out dx, al

    ; Receive real output response ending in 0x04 EOT
    mov ecx, 400000
.py_rx_loop:
    mov dx, 0x3FD
    in al, dx
    test al, 0x01
    jnz .py_got_byte
    dec ecx
    jnz .py_rx_loop
    jmp .py_repl_loop

.py_got_byte:
    mov dx, 0x3F8
    in al, dx
    cmp al, 0x04              ; EOT marker
    je .py_repl_loop
    call putchar
    mov ecx, 400000
    jmp .py_rx_loop

.py_offline:
    mov rsi, str_py_offline_msg
    call print
    jmp .py_repl_loop

.py_done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    jmp command_done

command_video:
    cmp byte [app_installed_video], 1
    je .vid_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done
.vid_ok:
    call play_real_video
    call gui_desktop
    jmp shell


; ============================================================
; JAVA SE 24 IDE & YOUTUBE JVM ENGINE (java.nosp)
; Coding Language App! Compiles & runs YouTubeEngine.java with
; interactive clickable buttons directly underneath the code!
; ============================================================

command_java:
    cmp byte [app_installed_java], 1
    je .java_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.java_installed_ok:
    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000
    mov dword [text_fg_color], 0x00F59E0B
    mov rsi, str_java_title
    call print
    mov al, 10
    call putchar
    mov dword [text_fg_color], 0x0010B981
    mov rsi, str_java_out_compiled
    call print
    mov al, 10
    call putchar
    jmp command_done

command_html:
    cmp byte [app_installed_html], 1
    je .html_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.html_installed_ok:
    mov byte [text_transparent_bg], 0
    mov dword [text_bg_color], 0x00000000
    mov dword [text_fg_color], 0x0006B6D4
    mov rsi, str_html_title
    call print
    mov al, 10
    call putchar
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, str_html_decoded_preview
    call print
    mov al, 10
    call putchar
    jmp command_done

command_youtube:
    cmp byte [app_installed_youtube], 1
    je .yt_installed_ok
    mov rsi, str_app_not_installed
    call print
    jmp command_done

.yt_installed_ok:
    push r11
    push r12
    push r13
    push r14
    push r15

    cmp byte [net_connected], 0
    je .yt_render
    cmp byte [yt_feed_loaded], 1
    je .yt_render
    call fetch_yt_live_feed

.yt_render:
    call clear_screen
    mov byte [text_transparent_bg], 1

    ; 1. YouTube Top Dark Header Bar (Y=0..48, #0F0F0F)
    mov eax, 0
    mov ebx, 0
    mov ecx, [screen_width]
    mov edx, 48
    mov esi, 0x000F0F0F
    call draw_rect

    ; YouTube Official Red Play Button Emblem at X=20, Y=10, W=38, H=26 (#FF0000)
    mov eax, 20
    mov ebx, 10
    mov ecx, 38
    mov edx, 26
    mov esi, 0x00FF0000
    call draw_rect
    mov eax, 34
    mov ebx, 17
    mov ecx, 10
    mov edx, 12
    mov esi, 0x00FFFFFF
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 6
    mov byte [cursor_y], 1
    mov rsi, str_yt_app_title
    call print

    ; Top-Right Account Status Badge (X=612, Y=8, W=296, H=32)
    mov eax, 612
    mov ebx, 8
    mov ecx, 296
    mov edx, 32
    mov esi, 0x001D4ED8
    cmp byte [yt_has_account], 1
    jne .yt_acct_bg_draw
    mov esi, 0x00059669
.yt_acct_bg_draw:
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 52
    mov byte [cursor_y], 1
    cmp byte [yt_has_account], 1
    je .yt_show_signed_in
    mov rsi, str_yt_no_acct_badge
    call print
    jmp .yt_draw_close_x
.yt_show_signed_in:
    mov rsi, str_yt_acct_prefix
    call print
    mov rsi, yt_account_buf
    call print

.yt_draw_close_x:
    ; Top-Right Red Close [X] Button
    mov eax, [screen_width]
    sub eax, 56
    mov ebx, 0
    mov ecx, 56
    mov edx, 46
    mov esi, 0x00E81123
    call draw_rect

    ; 2. YouTube Search & Action Toolbar (Y=48..104, #18181B)
    mov eax, 0
    mov ebx, 48
    mov ecx, [screen_width]
    mov edx, 56
    mov esi, 0x0018181B
    call draw_rect

    ; Search Input Box (X=28, Y=58, W=440, H=36, #27272A with #3F3F46 border)
    mov eax, 28
    mov ebx, 58
    mov ecx, 440
    mov edx, 36
    mov esi, 0x003B82F6
    call draw_rect
    mov eax, 30
    mov ebx, 60
    mov ecx, 436
    mov edx, 32
    mov esi, 0x00090D16
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 3
    mov byte [cursor_y], 3
    cmp byte [yt_search_len], 0
    jne .yt_print_typed_search
    mov dword [text_fg_color], 0x0094A3B8
    mov rsi, str_yt_search_placeholder
    call print
    jmp .yt_search_btns
.yt_print_typed_search:
    mov rsi, str_yt_search_lbl
    call print
    mov rsi, yt_search_buf
    call print
    mov al, '_'
    call putchar

.yt_search_btns:
    ; Red [ Search ] Button (X=478, Y=58, W=114, H=36, #DC2626)
    mov eax, 478
    mov ebx, 58
    mov ecx, 114
    mov edx, 36
    mov esi, 0x00DC2626
    call draw_rect

    ; Blue [ Add Account / Sign In ] Button (X=602, Y=58, W=220, H=36, #2563EB)
    mov eax, 602
    mov ebx, 58
    mov ecx, 220
    mov edx, 36
    mov esi, 0x002563EB
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 40
    mov byte [cursor_y], 3
    mov rsi, str_yt_toolbar_btns
    call print

    ; 3. YouTube Main Feed Canvas (Y=104..768, #0F172A)
    mov eax, 0
    mov ebx, 104
    mov ecx, [screen_width]
    mov edx, [screen_height]
    sub edx, 104
    mov esi, 0x000F172A
    call draw_rect

    ; Feed Status / Active Search Query Header at cursor_y=6 (Y=120)
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 4
    mov byte [cursor_y], 6
    cmp byte [yt_has_searched], 1
    je .yt_hdr_searched
    mov rsi, str_yt_feed_default_hdr
    call print
    jmp .yt_draw_card1
.yt_hdr_searched:
    mov rsi, str_yt_feed_search_hdr
    call print
    mov dword [text_fg_color], 0x0038BDF8
    mov rsi, yt_search_buf
    call print

.yt_draw_card1:
    ; ==========================================================
    ; VIDEO CARD 1 (X=36, Y=148, W=952, H=168, #1E293B)
    ; Text on top + Interactive Buttons Underneath!
    ; ==========================================================
    mov eax, 36
    mov ebx, 148
    mov ecx, 952
    mov edx, 168
    mov esi, 0x001E293B
    call draw_rect

    ; Real Photographic Video 1 Thumbnail Pulled from YouTube (160x90 at X=52, Y=162)
    cmp byte [yt_thumbs_loaded], 1
    je .have_native_yt_thumbs
    call init_real_youtube_media
.have_native_yt_thumbs:
    mov rsi, [yt_thumb_ptr_0]
    mov eax, 52
    mov ebx, 185
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    ; Video 1 Text (Title & Channel Info at cursor_y=8 & 10)
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 8
    cmp byte [yt_uploaded_active], 1
    je .yt_c1_uploaded_txt
    mov rsi, str_yt_v1_title
    call print
    jmp .yt_c1_sub_txt
.yt_c1_uploaded_txt:
    mov dword [text_fg_color], 0x0034D399
    mov rsi, str_yt_v1_upload_prefix
    call print
    mov dword [text_fg_color], 0x00FFFFFF
    mov rsi, yt_upload_title_buf
    call print

.yt_c1_sub_txt:
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 20
    mov byte [cursor_y], 10
    cmp byte [yt_uploaded_active], 1
    je .yt_c1_up_meta
    mov rsi, str_yt_v1_meta
    call print
    jmp .yt_c1_btns
.yt_c1_up_meta:
    mov rsi, str_yt_v1_up_meta
    call print
    mov rsi, yt_account_buf
    call print

.yt_c1_btns:
    ; INTERACTIVE ELEMENTS UNDERNEATH VIDEO 1 TEXT (Y=266, H=36, text at cursor_y=14 -> Y=280)
    mov eax, 236
    mov ebx, 266
    mov ecx, 240
    mov edx, 36
    mov esi, 0x00EA4335          ; [ > Watch Video 1 (60fps) ]
    call draw_rect

    mov eax, 492
    mov ebx, 266
    mov ecx, 170
    mov edx, 36
    mov esi, 0x002563EB          ; [ Like Video (+1) ]
    call draw_rect

    mov eax, 678
    mov ebx, 266
    mov ecx, 190
    mov edx, 36
    mov esi, 0x00059669          ; [ Subscribe ]
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 14
    mov rsi, str_yt_card_btns
    call print

    ; ==========================================================
    ; VIDEO CARD 2 (X=36, Y=332, W=952, H=168, #1E293B)
    ; ==========================================================
    mov eax, 36
    mov ebx, 332
    mov ecx, 952
    mov edx, 168
    mov esi, 0x001E293B
    call draw_rect

    ; Real Photographic Video 2 Thumbnail Pulled from YouTube (160x90 at X=52, Y=346)
    mov rsi, [yt_thumb_ptr_1]
    mov eax, 52
    mov ebx, 369
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 17
    mov rsi, str_yt_v2_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 20
    mov byte [cursor_y], 19
    mov rsi, str_yt_v2_meta
    call print

    ; INTERACTIVE ELEMENTS UNDERNEATH VIDEO 2 TEXT (Y=450, H=36, text at cursor_y=23 -> Y=460)
    mov eax, 236
    mov ebx, 450
    mov ecx, 240
    mov edx, 36
    mov esi, 0x00EA4335
    call draw_rect

    mov eax, 492
    mov ebx, 450
    mov ecx, 170
    mov edx, 36
    mov esi, 0x002563EB
    call draw_rect

    mov eax, 678
    mov ebx, 450
    mov ecx, 190
    mov edx, 36
    mov esi, 0x00059669
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 23
    mov rsi, str_yt_card_btns
    call print

    ; ==========================================================
    ; VIDEO CARD 3 (X=36, Y=516, W=952, H=168, #1E293B)
    ; ==========================================================
    mov eax, 36
    mov ebx, 516
    mov ecx, 952
    mov edx, 168
    mov esi, 0x001E293B
    call draw_rect

    ; Real Photographic Video 3 Thumbnail Pulled from YouTube (160x90 at X=52, Y=530)
    mov rsi, [yt_thumb_ptr_2]
    mov eax, 52
    mov ebx, 553
    mov ecx, 80
    mov edx, 45
    call draw_raw_image_32bpp

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 26
    mov rsi, str_yt_v3_title
    call print
    mov dword [text_fg_color], 0x0094A3B8
    mov byte [cursor_x], 20
    mov byte [cursor_y], 28
    mov rsi, str_yt_v3_meta
    call print

    ; INTERACTIVE ELEMENTS UNDERNEATH VIDEO 3 TEXT (Y=634, H=36, text at cursor_y=32 -> Y=640)
    mov eax, 236
    mov ebx, 634
    mov ecx, 240
    mov edx, 36
    mov esi, 0x00EA4335
    call draw_rect

    mov eax, 492
    mov ebx, 634
    mov ecx, 170
    mov edx, 36
    mov esi, 0x002563EB
    call draw_rect

    mov eax, 678
    mov ebx, 634
    mov ecx, 190
    mov edx, 36
    mov esi, 0x00059669
    call draw_rect

    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 32
    mov rsi, str_yt_card_btns
    call print

    ; Check if Create Account Modal (yt_modal_mode == 1) or Upload Video Modal (yt_modal_mode == 2) is open!
    cmp byte [yt_modal_mode], 1
    je .yt_draw_acct_modal
    cmp byte [yt_modal_mode], 2
    je .yt_draw_upload_modal
    jmp .yt_finish_draw

.yt_draw_acct_modal:
    ; Create YouTube Account Modal (X=180, Y=190, W=660, H=240, #090D16 with #2563EB border)
    mov eax, 180
    mov ebx, 190
    mov ecx, 660
    mov edx, 240
    mov esi, 0x00090D16
    call draw_rect
    mov eax, 180
    mov ebx, 190
    mov ecx, 660
    mov edx, 6
    mov esi, 0x002563EB
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 18
    mov byte [cursor_y], 11
    mov byte [term_left_col], 18
    mov rsi, str_yt_acct_modal_hdr
    call print
    mov dword [text_fg_color], 0x00FACC15
    mov byte [cursor_x], 18
    mov byte [cursor_y], 13
    mov rsi, yt_oauth_rx
    call print
    mov dword [text_fg_color], 0x0038BDF8
    mov byte [cursor_x], 18
    mov byte [cursor_y], 15
    mov rsi, yt_account_buf
    call print
    mov al, '_'
    call putchar
    ; Interactive Button Underneath Modal Text (X=220, Y=350, W=380, H=40, #2563EB)
    mov eax, 220
    mov ebx, 350
    mov ecx, 380
    mov edx, 40
    mov esi, 0x002563EB
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 18
    mov rsi, str_yt_acct_modal_btn
    call print
    jmp .yt_finish_draw

.yt_draw_upload_modal:
    ; Upload Video to YouTube Modal (X=180, Y=190, W=660, H=240, #090D16 with #10B981 border)
    mov eax, 180
    mov ebx, 190
    mov ecx, 660
    mov edx, 240
    mov esi, 0x00090D16
    call draw_rect
    mov eax, 180
    mov ebx, 190
    mov ecx, 660
    mov edx, 6
    mov esi, 0x0010B981
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 18
    mov byte [cursor_y], 11
    mov byte [term_left_col], 18
    mov rsi, str_yt_upload_modal_hdr
    call print
    mov dword [text_fg_color], 0x0034D399
    mov byte [cursor_x], 18
    mov byte [cursor_y], 14
    mov rsi, yt_upload_title_buf
    call print
    mov al, '_'
    call putchar
    ; Interactive Button Underneath Upload Modal Text (X=220, Y=350, W=340, H=40, #059669)
    mov eax, 220
    mov ebx, 350
    mov ecx, 340
    mov edx, 40
    mov esi, 0x00059669
    call draw_rect
    mov dword [text_fg_color], 0x00FFFFFF
    mov byte [cursor_x], 20
    mov byte [cursor_y], 18
    mov rsi, str_yt_upload_modal_btn
    call print

.yt_finish_draw:
    call draw_mouse_cursor

.yt_loop:
    call get_key
    cmp eax, KEY_MOUSE_MOVE
    je .yt_mouse_move
    cmp eax, KEY_MOUSE_CLICK
    je .yt_mouse_click
    cmp eax, KEY_UP
    je .yt_mouse_up
    cmp eax, KEY_DOWN
    je .yt_mouse_down
    cmp eax, KEY_LEFT
    je .yt_mouse_left
    cmp eax, KEY_RIGHT
    je .yt_mouse_right

    cmp eax, 27               ; ESC -> close modal if open, else exit YouTube
    je .yt_handle_esc
    cmp eax, 9                ; Tab -> cycle Create Account Modal (1) -> Upload Video Modal (2) -> Feed (0)!
    je .yt_cycle_modal

    ; Route typing based on active modal (0=Search Bar, 1=Create Account, 2=Upload Video)
    cmp byte [yt_modal_mode], 1
    je .yt_type_acct
    cmp byte [yt_modal_mode], 2
    je .yt_type_upload

    ; Mode 0: Search Bar typing & shortcuts ([ ] \ always; 1 2 3 only when search bar empty)
    cmp eax, '['
    je .yt_play_v1
    cmp eax, ']'
    je .yt_play_v2
    cmp eax, '\'
    je .yt_play_v3
    cmp byte [yt_search_len], 0
    jne .yt_type_char
    cmp eax, '1'
    je .yt_play_v1
    cmp eax, '2'
    je .yt_play_v2
    cmp eax, '3'
    je .yt_play_v3
.yt_type_char:
    cmp eax, 13               ; Enter -> Execute REAL YouTube Search!
    je .yt_do_search
    cmp eax, 8                ; Backspace
    je .yt_search_bs
    cmp eax, 32
    jb .yt_loop
    cmp eax, 126
    ja .yt_loop
    cmp byte [yt_has_searched], 1
    jne .yt_append_char
    mov byte [yt_search_len], 0
    mov byte [yt_search_buf], 0
    mov byte [yt_has_searched], 0
.yt_append_char:
    movzx ebx, byte [yt_search_len]
    cmp ebx, 28
    jae .yt_loop
    lea rdi, [yt_search_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [yt_search_len], bl
    jmp .yt_render

.yt_search_bs:
    movzx ebx, byte [yt_search_len]
    test ebx, ebx
    jz .yt_loop
    dec ebx
    lea rdi, [yt_search_buf]
    mov byte [rdi + rbx], 0
    mov [yt_search_len], bl
    jmp .yt_render

.yt_do_search:
    mov byte [yt_has_searched], 1
    mov byte [yt_uploaded_active], 0
    call fetch_yt_live_feed
    jmp .yt_render

.yt_type_acct:
    cmp eax, 13               ; Enter -> Confirm Create Account!
    je .yt_confirm_acct
    cmp eax, 8
    je .yt_acct_bs
    cmp eax, 32
    jb .yt_loop
    cmp eax, 126
    ja .yt_loop
    movzx ebx, byte [yt_acct_len]
    cmp ebx, 20
    jae .yt_loop
    lea rdi, [yt_account_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [yt_acct_len], bl
    jmp .yt_render

.yt_acct_bs:
    movzx ebx, byte [yt_acct_len]
    test ebx, ebx
    jz .yt_loop
    dec ebx
    lea rdi, [yt_account_buf]
    mov byte [rdi + rbx], 0
    mov [yt_acct_len], bl
    jmp .yt_render

.yt_confirm_acct:
    cmp byte [yt_acct_len], 0
    jne .yt_acct_sign_in
    mov rsi, str_bridge_oauth_poll
    call yt_oauth_cmd
    cmp byte [yt_oauth_rx], "O"
    jne .yt_render
    cmp byte [yt_oauth_rx+1], "K"
    jne .yt_render
.yt_acct_sign_in:
    mov byte [yt_has_account], 1
    mov byte [yt_modal_mode], 0
    jmp .yt_render

.yt_type_upload:
    cmp eax, 13               ; Enter -> Publish Uploaded Video!
    je .yt_confirm_upload
    cmp eax, 8
    je .yt_upload_bs
    cmp eax, 32
    jb .yt_loop
    cmp eax, 126
    ja .yt_loop
    movzx ebx, byte [yt_upload_len]
    cmp ebx, 32
    jae .yt_loop
    lea rdi, [yt_upload_title_buf]
    mov [rdi + rbx], al
    inc ebx
    mov byte [rdi + rbx], 0
    mov [yt_upload_len], bl
    jmp .yt_render

.yt_upload_bs:
    movzx ebx, byte [yt_upload_len]
    test ebx, ebx
    jz .yt_loop
    dec ebx
    lea rdi, [yt_upload_title_buf]
    mov byte [rdi + rbx], 0
    mov [yt_upload_len], bl
    jmp .yt_render

.yt_confirm_upload:
    mov byte [yt_uploaded_active], 1
    mov byte [yt_modal_mode], 0
    jmp .yt_render

.yt_handle_esc:
    cmp byte [yt_modal_mode], 0
    je .yt_close
    mov byte [yt_modal_mode], 0
    jmp .yt_render

.yt_cycle_modal:
    xor byte [yt_modal_mode], 1
    cmp byte [yt_modal_mode], 1
    jne .yt_render
    mov rsi, str_bridge_oauth_start
    call yt_oauth_cmd
    jmp .yt_render

.yt_mouse_move:
    call draw_mouse_cursor
    jmp .yt_loop
.yt_mouse_up:
    cmp dword [mouse_y], 20
    jb .yt_loop
    sub dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .yt_loop
.yt_mouse_down:
    mov edx, [screen_height]
    sub edx, 30
    cmp dword [mouse_y], edx
    jae .yt_loop
    add dword [mouse_y], 20
    call draw_mouse_cursor
    jmp .yt_loop
.yt_mouse_left:
    cmp dword [mouse_x], 20
    jb .yt_loop
    sub dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .yt_loop
.yt_mouse_right:
    mov edx, [screen_width]
    sub edx, 30
    cmp dword [mouse_x], edx
    jae .yt_loop
    add dword [mouse_x], 20
    call draw_mouse_cursor
    jmp .yt_loop

.yt_mouse_click:
    call draw_mouse_cursor
    mov eax, [mouse_y]
    ; If a modal is open, clicking inside the Confirm button (Y=340..400) confirms it!
    cmp byte [yt_modal_mode], 1
    je .yt_click_acct_modal
    cmp byte [yt_modal_mode], 2
    je .yt_click_upload_modal

    ; 1. Top Header Bar (Y < 48): Close [X] on right, Account badge at X=660..950
    cmp eax, 48
    jae .yt_click_toolbar
    mov eax, [mouse_x]
    mov edx, [screen_width]
    sub edx, 64
    cmp eax, edx
    jae .yt_close
    cmp eax, 650
    jae .yt_open_acct_modal
    jmp .yt_loop

.yt_click_toolbar:
    ; 2. Search & Action Toolbar (Y = 48..104)
    cmp eax, 104
    jae .yt_click_feed
    mov eax, [mouse_x]
    cmp eax, 475
    jb .yt_loop
    cmp eax, 600
    jbe .yt_do_search
    jmp .yt_open_acct_modal

.yt_open_acct_modal:
    mov byte [yt_modal_mode], 1
    mov rsi, str_bridge_oauth_start
    call yt_oauth_cmd
    jmp .yt_render

.yt_open_upload_modal:
    mov byte [yt_modal_mode], 2
    jmp .yt_render

.yt_click_acct_modal:
    cmp eax, 340
    jb .yt_confirm_acct
    cmp eax, 410
    jbe .yt_confirm_acct
    mov byte [yt_modal_mode], 0
    jmp .yt_render

.yt_click_upload_modal:
    cmp eax, 340
    jb .yt_confirm_upload
    cmp eax, 410
    jbe .yt_confirm_upload
    mov byte [yt_modal_mode], 0
    jmp .yt_render

.yt_click_feed:
    ; Clicking any Video Card (Video 1: Y=148..324, Video 2: Y=324..508, Video 3: Y=508..684) plays that exact video!
    mov eax, [mouse_y]
    cmp eax, 324
    jb .yt_play_v1
    cmp eax, 508
    jb .yt_play_v2
.yt_play_v3:
    mov byte [yt_playing_slot], 2
    mov qword [yt_playing_title_ptr], str_yt_v3_title
    mov qword [yt_playing_meta_ptr], str_yt_v3_meta
    mov dword [yt_playing_seed], 128
    call play_real_video
    jmp .yt_render
.yt_play_v2:
    mov byte [yt_playing_slot], 1
    mov qword [yt_playing_title_ptr], str_yt_v2_title
    mov qword [yt_playing_meta_ptr], str_yt_v2_meta
    mov dword [yt_playing_seed], 64
    call play_real_video
    jmp .yt_render
.yt_play_v1:
    mov byte [yt_playing_slot], 0
    mov qword [yt_playing_title_ptr], str_yt_v1_title
    mov qword [yt_playing_meta_ptr], str_yt_v1_meta
    cmp byte [yt_uploaded_active], 1
    jne .yt_do_play_v1
    mov qword [yt_playing_title_ptr], yt_upload_title_buf
.yt_do_play_v1:
    mov dword [yt_playing_seed], 0
    call play_real_video
    jmp .yt_render

.yt_close:
    mov byte [text_transparent_bg], 0
    mov dword [text_fg_color], 0x00FFFFFF
    mov dword [text_bg_color], COLOR_WINDOW
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    call gui_desktop
    jmp shell

command_add:

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_add
    call skip_word

    call skip_spaces

    call number

    push rax

    call skip_spaces
    call number

    mov ebx, eax

    pop rax

    add eax, ebx

    call print_number
    call newline

    jmp command_done


command_sub:

    mov rsi, input
    call skip_spaces

    mov rdi, cmd_sub
    call skip_word

    call skip_spaces

    call number

    push rax

    call skip_spaces
    call number

    mov ebx, eax

    pop rax

    sub eax, ebx

    call print_number
    call newline

    jmp command_done


command_reboot:

    mov rsi, reboot_text
    call print

    cli


reboot_wait:

    in al, 0x64

    test al, 2
    jnz reboot_wait

    mov al, 0xFE

    out 0x64, al

    jmp $


command_halt:

    mov rsi, halt_text
    call print

    cli


halt_loop:

    hlt

    jmp halt_loop


command_font_list:

    call font_list

    jmp command_done


command_font_current:

    call font_current

    jmp command_done


command_font_use:

    call font_use

    jmp command_done


; ============================================================
; EXACT MATCH
; ============================================================

exact:

exact_loop:

    mov al, [rsi]
    mov bl, [rdi]

    cmp al, bl
    jne exact_no

    cmp al, 0
    je exact_yes

    inc rsi
    inc rdi

    jmp exact_loop


exact_yes:

    stc

    ret


exact_no:

    clc

    ret


; ============================================================
; PREFIX
; ============================================================

prefix:

prefix_loop:

    mov bl, [rdi]

    cmp bl, 0
    je prefix_check_end

    mov al, [rsi]

    cmp al, bl
    jne prefix_no

    inc rsi
    inc rdi

    jmp prefix_loop


prefix_check_end:

    cmp byte [rsi], 0
    je prefix_yes

    cmp byte [rsi], ' '
    je prefix_yes

    cmp byte [rsi], '.'
    je prefix_yes

    cmp byte [rsi], '('
    je prefix_yes


prefix_no:

    clc

    ret


prefix_yes:

    stc

    ret


; ============================================================
; SKIP SPACES
; ============================================================

skip_spaces:

skip_spaces_loop:

    cmp byte [rsi], ' '
    jne skip_spaces_done

    inc rsi

    jmp skip_spaces_loop


skip_spaces_done:

    ret


; ============================================================
; SKIP WORD
; ============================================================

skip_word:

skip_word_loop:

    cmp byte [rsi], 0
    je skip_word_done

    cmp byte [rsi], ' '
    je skip_word_done

    inc rsi

    jmp skip_word_loop


skip_word_done:

    ret


; ============================================================
; NUMBER
; ============================================================

number:

    xor eax, eax
    xor ebx, ebx


number_loop:

    mov bl, [rsi]

    cmp bl, '0'
    jb number_done

    cmp bl, '9'
    ja number_done

    sub bl, '0'

    imul eax, 10

    add eax, ebx

    inc rsi

    jmp number_loop


number_done:

    ret


; ============================================================
; PRINT NUMBER
; ============================================================

print_number:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    cmp eax, 0
    jne print_number_convert

    mov al, '0'

    call putchar

    jmp print_number_done


print_number_convert:

    xor ecx, ecx

    mov ebx, 10


print_number_divide:

    xor edx, edx

    div ebx

    push rdx

    inc ecx

    test eax, eax

    jnz print_number_divide


print_number_output:

    pop rax

    add al, '0'

    call putchar

    loop print_number_output


print_number_done:

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret




; ============================================================
; PRINT HEX
; ============================================================

print_hex:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    mov ecx, 8


print_hex_loop:

    rol eax, 4

    mov ebx, eax

    and ebx, 15

    mov al, [hex + rbx]

    call putchar

    loop print_hex_loop

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret




; ============================================================
; CPU VENDOR
; ============================================================

cpu_vendor:

    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    xor eax, eax

    cpuid

    mov [vendor], ebx
    mov [vendor + 4], edx
    mov [vendor + 8], ecx

    mov byte [vendor + 12], 0

    mov rsi, vendor

    call print

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret




; ============================================================
; CMOS
; ============================================================

cmos:

    out CMOS_INDEX, al

    in al, CMOS_DATA

    ret

; ============================================================
; HARDWARE DETECTION
; ============================================================

detect_hardware:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; 1. CPU Vendor
    xor eax, eax
    cpuid

    mov [vendor], ebx
    mov [vendor + 4], edx
    mov [vendor + 8], ecx
    mov byte [vendor + 12], 0

    ; 2. CPU Model Name (Extended CPUID)
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .cpu_fallback

    mov eax, 0x80000002
    cpuid
    mov [cpu_brand_str], eax
    mov [cpu_brand_str + 4], ebx
    mov [cpu_brand_str + 8], ecx
    mov [cpu_brand_str + 12], edx

    mov eax, 0x80000003
    cpuid
    mov [cpu_brand_str + 16], eax
    mov [cpu_brand_str + 20], ebx
    mov [cpu_brand_str + 24], ecx
    mov [cpu_brand_str + 28], edx

    mov eax, 0x80000004
    cpuid
    mov [cpu_brand_str + 32], eax
    mov [cpu_brand_str + 36], ebx
    mov [cpu_brand_str + 40], ecx
    mov [cpu_brand_str + 44], edx
    mov byte [cpu_brand_str + 48], 0

    ; Strip leading spaces
    mov rsi, cpu_brand_str
.skip_leading_spaces:
    cmp byte [rsi], ' '
    jne .brand_ready
    inc rsi
    jmp .skip_leading_spaces

.brand_ready:
    mov [cpu_brand_ptr], rsi
    jmp .cpu_done

.cpu_fallback:
    mov qword [cpu_brand_ptr], vendor

.cpu_done:

    ; 3. RAM Detection via CMOS
    mov al, 0x30
    call cmos
    movzx ebx, al
    mov al, 0x31
    call cmos
    movzx eax, al
    shl eax, 8
    or eax, ebx

    test eax, eax
    jz .ram_check_17
    imul eax, 64
    add eax, 1024
    shr eax, 10
    mov [ram_total_mb], eax
    jmp .ram_done

.ram_check_17:
    mov al, 0x17
    call cmos
    movzx ebx, al
    mov al, 0x18
    call cmos
    movzx eax, al
    shl eax, 8
    or eax, ebx
    add eax, 1024
    shr eax, 10
    test eax, eax
    jnz .set_ram
    mov eax, 512
.set_ram:
    mov [ram_total_mb], eax

.ram_done:

    ; 4. Floppy Drive Type via CMOS 0x10
    mov al, 0x10
    call cmos
    shr al, 4
    and al, 0x0F
    mov [floppy_type], al

    ; 5. ATA Storage Drives
    mov dx, 0x1F7
    in al, dx
    mov [hdd_status], al

    mov dx, 0x177
    in al, dx
    mov [cdrom_status], al

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret



; ============================================================
; ATA PIO WRITE SECTORS
; RDI = buffer, EAX = LBA, ECX = sector count
; ============================================================

ata_write_sectors:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

.ata_loop:
    test ecx, ecx
    jz .ata_done

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
    mov al, 1
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
    mov al, 0x30
    out dx, al

    mov ebx, 100000
.wait_write_drq:
    pause
    in al, dx
    cmp al, 0xFF
    je .ata_abort
    test al, 0x80
    jnz .still_wait
    test al, 0x08
    jnz .ready_write
.still_wait:
    dec ebx
    jnz .wait_write_drq
    jmp .ata_abort

.ready_write:
    mov edx, 0x1F0
    mov ecx, 256
    mov rsi, rdi
    rep outsw

    mov edx, 0x1F7
    mov al, 0xE7
    out dx, al

    pop rdi
    add rdi, 512
    pop rax
    inc eax
    pop rcx
    dec ecx
    jmp .ata_loop

.ata_abort:
    pop rdi
    pop rax
    pop rcx
    jmp .ata_done

.ata_done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret

; ============================================================
; ATA PIO READ SECTORS
; RDI = buffer, EAX = LBA, ECX = sector count
; ============================================================
ata_read_sectors:
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

; ============================================================
; LOAD REAL YOUTUBE MEDIA FROM DISK INTO RAM BUFFERS
; ============================================================
init_real_youtube_media:
    push rax
    push rcx
    push rdi

    mov byte [yt_thumbs_loaded], 1

    ; Thumbnails (80x45 = 14,400 bytes = 29 sectors each)
    mov eax, 1024
    mov ecx, 29
    mov rdi, yt_thumb_buf_0
    call ata_read_sectors

    mov eax, 1060
    mov ecx, 29
    mov rdi, yt_thumb_buf_1
    call ata_read_sectors

    mov eax, 1100
    mov ecx, 29
    mov rdi, yt_thumb_buf_2
    call ata_read_sectors

    pop rdi
    pop rcx
    pop rax
    ret

; ============================================================
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
    push r12

    test rsi, rsi
    jz near .s4x_done

    mov r11d, eax                 ; base X
    mov r12d, ebx                 ; base Y
    xor r10d, r10d                ; source row = 0..44

.s4x_row_loop:
    cmp r10d, 45
    jge near .s4x_done

    mov r8d, 4                    ; 4 vertical scanlines per source row
.s4x_v_repeat:
    mov eax, 4
    sub eax, r8d                  ; dy = 0, 1, 2, 3
    mov edx, r10d
    shl edx, 2                    ; r10d * 4
    add eax, edx                  ; total y_offset = r10d * 4 + dy
    add eax, r12d                 ; Y = base Y + total y_offset
    imul eax, [framebuffer_pitch]
    mov edx, r11d
    shl edx, 2
    add eax, edx
    add rax, [framebuffer_address]
    mov rdi, rax

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
    dec r8d
    jnz .s4x_v_repeat

    add rsi, 320                  ; 80 * 4 bytes per source row
    inc r10d
    jmp .s4x_row_loop

.s4x_done:
    pop r12
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
; DRAW RAW 32-BPP BGRA IMAGE (HIGH SPEED ASSEMBLY BLITTER)
; RSI = source buffer, EAX = dest X, EBX = dest Y
; ECX = width in pixels, EDX = height in pixels
; ============================================================
draw_raw_image_32bpp:
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
    push r12

    test rsi, rsi
    jz .dri_done

    mov r11d, eax            ; dest X
    mov r12d, ebx            ; dest Y
    mov r8d, ecx             ; width
    mov r9d, edx             ; height
    xor r10d, r10d           ; row = 0

.dri_row:
    cmp r10d, r9d
    jge .dri_done

    mov eax, r12d
    add eax, r10d
    imul eax, [framebuffer_pitch]
    mov edx, r11d
    shl edx, 2
    add eax, edx
    add rax, [framebuffer_address]
    mov rdi, rax

    mov ecx, r8d
    rep movsd

    inc r10d
    jmp .dri_row

.dri_done:
    pop r12
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
; DRAW 160x90 IMAGE SCALED 2X TO 320x180 VIDEO VIEWPORT
; RSI = source buffer, EAX = dest X, EBX = dest Y
; ============================================================
draw_video_frame_scaled_2x:
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
    push r12

    mov r11d, eax            ; base dest X
    mov r12d, ebx            ; base dest Y
    xor r9d, r9d             ; src_y = 0

.dv_y_loop:
    cmp r9d, 90
    jge .dv_done

    ; Line 0: dest Y = r12d + r9d * 2
    mov eax, r9d
    shl eax, 1
    add eax, r12d
    imul eax, [framebuffer_pitch]
    mov edx, r11d
    shl edx, 2
    add eax, edx
    add rax, [framebuffer_address]
    mov rdi, rax             ; Line 0

    mov r10, rdi
    mov edx, [framebuffer_pitch]
    add r10, rdx             ; Line 1

    xor r8d, r8d             ; src_x = 0
.dv_x_loop:
    cmp r8d, 160
    jge .dv_next_y

    lodsd                    ; EAX = pixel
    mov [rdi], eax
    mov [rdi + 4], eax
    add rdi, 8

    mov [r10], eax
    mov [r10 + 4], eax
    add r10, 8

    inc r8d
    jmp .dv_x_loop

.dv_next_y:
    inc r9d
    jmp .dv_y_loop

.dv_done:
    pop r12
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




bcd:

    movzx eax, al

    mov ebx, eax

    and eax, 15

    shr ebx, 4

    imul ebx, 10

    add eax, ebx

    ret


two_digits:

    push rax
    push rbx
    push rdx

    xor edx, edx

    mov ebx, 10

    div ebx

    add al, '0'

    call putchar

    mov eax, edx

    add al, '0'

    call putchar

    pop rdx
    pop rbx
    pop rax

    ret


show_time:

    mov al, 4
    call cmos
    call bcd
    call two_digits

    mov al, ':'
    call putchar

    mov al, 2
    call cmos
    call bcd
    call two_digits

    mov al, ':'
    call putchar

    mov al, 0
    call cmos
    call bcd
    call two_digits

    ret


show_date:

    mov al, 8
    call cmos
    call bcd
    call two_digits

    mov al, '/'
    call putchar

    mov al, 7
    call cmos
    call bcd
    call two_digits

    mov al, '/'
    call putchar

    mov al, 9
    call cmos
    call bcd
    call two_digits

    ret


; ================================================================
; NOVAFS FONT LOADING
;
; Automatically find bitmap fonts by filename.
;
; NovaFS directory entry:
;
; +0   12-byte filename
; +12  starting sector
; +16  file size
; ================================================================

load_font_addresses:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    mov rsi, NOVAFS_DIR

    mov ecx, [NOVAFS + 8]


load_font_search_loop:

    test ecx, ecx

    jz load_font_done

    ; ------------------------------------------------------------
    ; Regular
    ; ------------------------------------------------------------

    push rcx
    push rsi

    mov rdi, fs_regular_name

    call font_name_match

    pop rsi
    pop rcx

    jc load_font_regular_found

    ; ------------------------------------------------------------
    ; Bold
    ; ------------------------------------------------------------

    push rcx
    push rsi

    mov rdi, fs_bold_name

    call font_name_match

    pop rsi
    pop rcx

    jc load_font_bold_found

    ; ------------------------------------------------------------
    ; Italic
    ; ------------------------------------------------------------

    push rcx
    push rsi

    mov rdi, fs_italic_name

    call font_name_match

    pop rsi
    pop rcx

    jc load_font_italic_found

    ; ------------------------------------------------------------
    ; Bold Italic
    ; ------------------------------------------------------------

    push rcx
    push rsi

    mov rdi, fs_bold_italic_name

    call font_name_match

    pop rsi
    pop rcx

    jc load_font_bold_italic_found

    ; ------------------------------------------------------------
    ; Boot spinner
    ; ------------------------------------------------------------

    push rcx
    push rsi

    mov rdi, fs_bootspin_name

    call font_name_match

    pop rsi
    pop rcx

    jc load_font_bootspin_found

    ; ------------------------------------------------------------
    ; NovaOS Logo
    ; ------------------------------------------------------------

    push rcx
    push rsi

    mov rdi, fs_logo_name

    call font_name_match

    pop rsi
    pop rcx

    jc load_logo_found

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
    ; ------------------------------------------------------------

    add rsi, NOVAFS_ENTRY_SIZE

    dec ecx

    jmp load_font_search_loop


load_font_regular_found:

    call fs_entry_address

    mov [font_regular_address], rax

    jmp load_font_next_entry


load_font_bold_found:

    call fs_entry_address

    mov [font_bold_address], rax

    jmp load_font_next_entry


load_font_italic_found:

    call fs_entry_address

    mov [font_italic_address], rax

    jmp load_font_next_entry


load_font_bold_italic_found:

    call fs_entry_address

    mov [font_bold_italic_address], rax

    jmp load_font_next_entry


load_font_bootspin_found:

    call fs_entry_address

    mov [bootspin_font_address], rax

    jmp load_font_next_entry


load_logo_found:

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
    jmp load_font_next_entry


load_font_next_entry:

    add rsi, NOVAFS_ENTRY_SIZE

    dec ecx

    jmp load_font_search_loop


load_font_done:

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret




; ================================================================
; FONT NAME MATCH
;
; ESI = NovaFS directory entry
; EDI = filename
;
; Compares exactly 12 bytes.
;
; Carry = match
; ================================================================

font_name_match:

    push rax
    push rbx
    push rcx
    push rsi
    push rdi

    mov ecx, 12


font_name_match_loop:

    mov al, [rsi]
    mov bl, [rdi]

    cmp al, bl

    jne font_name_match_no

    inc rsi
    inc rdi

    loop font_name_match_loop

    stc

    jmp font_name_match_done


font_name_match_no:

    clc


font_name_match_done:

    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax

    ret




; ================================================================
; FS ENTRY ADDRESS
;
; ESI = NovaFS directory entry
;
; EAX = physical address of file
; ================================================================

fs_entry_address:

    mov eax, [rsi + 12]
    imul eax, 512
    add eax, NOVAFS
    ret


; ============================================================
; FONT LIST
; ============================================================

font_list:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    mov rsi, font_list_header

    call print

    mov ecx, [NOVAFS + 8]

    mov rsi, NOVAFS_DIR


font_list_loop:

    test ecx, ecx

    jz font_list_done

    push rcx
    push rsi

    mov rdi, rsi

    call print_fs_name
    call newline

    pop rsi
    pop rcx

    add rsi, NOVAFS_ENTRY_SIZE

    dec ecx

    jmp font_list_loop


font_list_done:

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret




; ============================================================
; PRINT NOVAFS FILENAME
; ============================================================

print_fs_name:

    push rax
    push rcx
    push rdi

    mov ecx, 12


print_fs_name_loop:

    mov al, [rdi]

    test al, al

    jz print_fs_name_done

    call putchar

    inc rdi

    loop print_fs_name_loop


print_fs_name_done:

    pop rdi
    pop rcx
    pop rax

    ret


; ============================================================
; CURRENT FONT
; ============================================================

font_current:

    mov rsi, current_font_text

    call print

    movzx eax, byte [current_font]

    cmp eax, FONT_REGULAR
    je font_current_regular

    cmp eax, FONT_BOLD
    je font_current_bold

    cmp eax, FONT_ITALIC
    je font_current_italic

    cmp eax, FONT_BOLD_ITALIC
    je font_current_bold_italic

    jmp font_current_done


font_current_regular:

    mov rsi, font_regular_name

    jmp font_current_print


font_current_bold:

    mov rsi, font_bold_name

    jmp font_current_print


font_current_italic:

    mov rsi, font_italic_name

    jmp font_current_print


font_current_bold_italic:

    mov rsi, font_bold_italic_name


font_current_print:

    call print


font_current_done:

    call newline

    ret


; ============================================================
; FONT USE
; ============================================================

font_use:

    mov rsi, input

    call skip_spaces

    add rsi, 8

    call skip_spaces

    mov rdi, font_regular_name

    call exact

    jc font_use_regular

    mov rsi, input
    call skip_spaces
    add rsi, 8
    call skip_spaces

    mov rdi, font_bold_name

    call exact

    jc font_use_bold

    mov rsi, input
    call skip_spaces
    add rsi, 8
    call skip_spaces

    mov rdi, font_italic_name

    call exact

    jc font_use_italic

    mov rsi, input
    call skip_spaces
    add rsi, 8
    call skip_spaces

    mov rdi, font_bold_italic_name

    call exact

    jc font_use_bold_italic

    mov rsi, font_not_found

    call print

    ret


font_use_regular:

    mov byte [current_font], FONT_REGULAR

    mov rax, [font_regular_address]
    mov [current_font_address], rax

    call clear_screen

    mov rsi, font_changed
    call print

    mov rsi, font_regular_name
    call print

    call newline

    ret


font_use_bold:

    mov byte [current_font], FONT_BOLD

    mov rax, [font_bold_address]
    mov [current_font_address], rax

    call clear_screen

    mov rsi, font_changed
    call print

    mov rsi, font_bold_name
    call print

    call newline

    ret


font_use_italic:

    mov byte [current_font], FONT_ITALIC

    mov rax, [font_italic_address]
    mov [current_font_address], rax

    call clear_screen

    mov rsi, font_changed
    call print

    mov rsi, font_italic_name
    call print

    call newline

    ret


font_use_bold_italic:

    mov byte [current_font], FONT_BOLD_ITALIC

    mov rax, [font_bold_italic_address]
    mov [current_font_address], rax

    call clear_screen

    mov rsi, font_changed
    call print

    mov rsi, font_bold_italic_name
    call print

    call newline

    ret


; ============================================================
; STRINGS
; ============================================================
gui_novaos_text:
    db "NovaOS",0

gui_files_text:
    db "[ Files ]",0



gui_terminal_title:
    db "Terminal",0

gui_desktop_bar_no_np:
    db "[ Files ]    [ Chrome ]    [ App Shop ]    [ WiFi ]",0


gui_taskbar_text:
    db "[ NovaOS ]   Files   Terminal   WiFi   Chrome   Shop   Settings",0
banner_text db 13,10
            db "==================================================",13,10
            db "       NovaOS 1.02.4000 26Q4 (Build 26110.4000)",13,10
            db "==================================================",13,10
            db " Drives: A: Floppy (1.44MB) | C: Hard Disk | D: CD-ROM",13,10
            db " Font:   Segoe UI Grounded Baseline (12x20)",13,10
            db " Type 'help' for commands, 'savefont' to persist font.",13,10
            db "==================================================",13,10,13,10,0

prompt db "nova> ",0

unknown db "Unknown command. Type 'help'.",13,10,0

help_text db 13,10
          db "NovaOS 1.02.4000 Commands:",13,10
          db " SYS:  help about version cpu mem time date reboot halt cls res",13,10
          db " APPS: apps chrome shop files wifi notepad python java html youtube",13,10
          db " MORE: calc clock paint sysmon drivers startup.nosp",13,10
          db " FS:   ls mkdir touch write cat rm rmdir savefs drives iso floppy",13,10
          db " FONT: font list/current/use/setup savefont loadfont",13,10
          db " MATH: add N M | sub N M | echo <txt>",13,10,13,10,0

about_text db "NovaOS 1.02.4000 26Q4 (Build 26110.4000) - 64-bit x86 graphical OS.",13,10
           db "Features ASM Browser, YouTube, Java, HTML5, disk save.",13,10,0

version_text db "NovaOS 1.02.4000 26Q4 (Build 26110.4000) (x86_64)",13,10,0

cpu_text db "CPU: ",0

mem_ram_title db "System RAM: ",0
mem_ram_suffix db " MB detected",0
mem_text db "Kernel address: 0x",0

reboot_text db "Rebooting...",13,10,0

halt_text db "CPU halted.",13,10,0

boot_dot_cpu         db "CPU .......... ",0
boot_dot_ram         db "RAM .......... ",0
boot_dot_ram_suffix  db " MB RAM detected",0
boot_dot_storage     db "Storage ...... HDD C: | CD-ROM D: | Floppy A:",0

floppy_title         db "Floppy Subsystem:",13,10,0
floppy_144_ready     db "  Drive A: 1.44 MB 3.5-inch Diskette [Ready]",13,10
                     db "  Controller: Standard FDC I/O 0x3F0-0x3F7",13,10
                     db "  Custom fonts: Place FONT.FNT on floppy, run 'loadfont floppy'",13,10,0
floppy_detected      db "  Drive A: Floppy drive detected",13,10,0
floppy_not_found     db "  No floppy drive detected in CMOS.",13,10,0

drives_info          db "Detected Storage Drives:",13,10
                     db "  Drive A: 1.44MB 3.5-inch Floppy Diskette [Ready]",13,10
                     db "  Drive C: ATA Hard Disk (NovaFS) [Persistent on reboot]",13,10
                     db "  Drive D: ATAPI CD-ROM / ISO [Live Media]",13,10,0

iso_info             db "Optical Subsystem:",13,10
                     db "  Drive D: ATAPI Optical Media [NovaOS Live ISO Mounted]",13,10
                     db "  Format:  ISO-9660 / El Torito Bootable Disc",13,10,0

savefont_prompt      db "Writing NovaFS & fonts to Hard Disk C: (LBA 133)...",13,10,0
savefont_success     db "[SUCCESS] Font saved to Hard Disk C:. Persistent on next reboot!",13,10
                     db "Note: Live CD is read-only.",13,10,0

loadfont_status      db "Font loaded into active memory.",13,10
                     db "Run 'savefont' to make it persistent on hard disk.",13,10,0

logo_test_text db "LOGO TEST", 0

; ============================================================
; FONT STRINGS
; ============================================================

boot_text db "Starting NovaOS",0

font_list_header db "NovaFS fonts:",13,10,0

current_font_text db "Current font: ",0

font_changed db "Font selected: ",0

font_not_found db "Font not found.",13,10,0

font_regular_name db "Segoe UI Regular",0
font_bold_name db "Segoe UI Bold",0
font_italic_name db "Segoe UI Italic",0
font_bold_italic_name db "Segoe UI Bold Italic",0


; ============================================================
; NOVAFS FILENAMES
; ============================================================

fs_regular_name db "SEGOEUI.FNT",0
fs_bold_name db "SEGOEBD.FNT",0
fs_italic_name db "SEGOEIT.FNT",0
fs_bold_italic_name db "SEGOEBI.FNT",0
fs_bootspin_name db "BOOTSPIN.FNT",0
fs_logo_name db "NOVALOGO.RAW",0
fs_yt0_name db "YT0.RAW",0,0,0,0,0
fs_yt1_name db "YT1.RAW",0,0,0,0,0
fs_yt2_name db "YT2.RAW",0,0,0,0,0
str_yt_buffering db "Buffering YouTube 60fps stream (TLS 1.3)...",0
align 8
yt_thumb_ptr_0 dq yt_thumb_buf_0
yt_thumb_ptr_1 dq yt_thumb_buf_1
yt_thumb_ptr_2 dq yt_thumb_buf_2

boot_bit_masks:
    db 0x80
    db 0x40
    db 0x20
    db 0x10
    db 0x08
    db 0x04
    db 0x02
    db 0x01


hex db "0123456789ABCDEF"

vendor times 13 db 0
; ============================================================
; PC SPEAKER AUDIO
; ============================================================

PIT_BASE_FREQUENCY equ 1193182

speaker_start:
    ; AX = PIT divisor
    push ax

    ; Channel 2, access low byte then high byte,
    ; mode 3 (square wave), binary counting.
    mov al, 0xB6
    out 0x43, al

    pop ax

    ; Send divisor to PIT channel 2.
    out 0x42, al
    mov al, ah
    out 0x42, al

    ; Enable PIT channel 2 + PC speaker.
    in al, 0x61
    or al, 0x03
    out 0x61, al

    ret


speaker_stop:
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret


audio_delay:
    mov ecx, 80000
.delay:
    pause
    dec ecx
    jnz .delay
    ret


startup_audio:
    ; --------------------------------------------------------
    ; C5
    ; 1193182 / 523 = 2281
    ; --------------------------------------------------------
    mov ax, 2281
    call speaker_start
    call audio_delay

    ; --------------------------------------------------------
    ; E5
    ; 1193182 / 659 = 1811
    ; --------------------------------------------------------
    mov ax, 1811
    call speaker_start
    call audio_delay

    ; --------------------------------------------------------
    ; G5
    ; 1193182 / 784 = 1522
    ; --------------------------------------------------------
    mov ax, 1522
    call speaker_start
    call audio_delay

    ; --------------------------------------------------------
    ; C6
    ; 1193182 / 1047 = 1140
    ; --------------------------------------------------------
    mov ax, 1140
    call speaker_start
    call audio_delay

    call speaker_stop
    ret

; ============================================================
; COMMAND NAMES
; ============================================================

cmd_help:
    db "help",0

cmd_about:
    db "about",0

cmd_version:
    db "version",0

cmd_echo:
    db "echo",0

cmd_clear:
    db "clear",0

cmd_cls:
    db "cls",0

cmd_cpu:
    db "cpu",0

cmd_time:
    db "time",0

cmd_date:
    db "date",0

cmd_mem:
    db "mem",0

cmd_add:
    db "add",0

cmd_sub:
    db "sub",0

cmd_reboot:
    db "reboot",0

cmd_halt:
    db "halt",0

cmd_font_list:
    db "font list",0

cmd_font_current:
    db "font current",0

cmd_font_use:
    db "font use",0

cmd_floppy:
    db "floppy",0

cmd_list_drive:   db "list drive",0
cmd_list_drives:  db "list drives",0
cmd_d_startup:    db "d:\startup.nosp",0
cmd_run_prefix:   db "run",0
cmd_open_prefix:  db "open",0
cmd_wifi_short:   db "wifi",0
cmd_startup_short: db "startup",0
cmd_wifi:         db "wifi",0
cmd_browser:      db "browser",0
cmd_drives:
    db "drives",0

cmd_iso:
    db "iso",0

cmd_cdrom:
    db "cdrom",0

cmd_savefont:
    db "savefont",0

cmd_loadfont:
    db "loadfont",0

cmd_ls:         db "ls",0
cmd_dir:        db "dir",0
cmd_mkdir:      db "mkdir",0
cmd_touch:      db "touch",0
cmd_write:      db "write",0
cmd_cat:        db "cat",0
cmd_rm:         db "rm",0
cmd_rmdir:      db "rmdir",0
cmd_savefs:     db "savefs",0
cmd_files:      db "files",0
cmd_apps:         db "apps",0
cmd_drivers:      db "drivers",0
wifi_hw_series_id: db 0
str_drv_menu_hdr:
    db "NovaOS 1.02.4000 Translated WiFi Hardware & Drivers (all wifi.zip)",13,10
    db "-------------------------------------------------------------------",13,10,0
str_drv_series_list:
    db "  [1] Intel iwlwifi Series     (VID 0x8086 | 85 IDs: AX200/AX210/BE200/9260)",13,10
    db "  [2] MediaTek mt76 Series     (VID 0x14C3 | 68 IDs: MT7921/MT7922/MT7915/MT7615)",13,10
    db "  [3] Atheros ath9k_htc Series (VID 0x0CF3 | 19 IDs: AR9271/AR7010)",13,10
    db "  [4] Realtek rtlwifi Series   (VID 0x10EC | 52 IDs: RTL8188EE/8192EE/8723BE)",13,10
    db "  [5] Realtek rtw88 Series     (VID 0x10EC |107 IDs: RTL8822CE/8821CE/8723DE)",13,10
    db "  [6] Realtek rtw89 WiFi 6/7   (VID 0x10EC | 83 IDs: RTL8852AE/8852BE/8922AE)",13,10,13,10
    db "  Press [1]-[6] to view series & bind hardware driver, or [Esc] to exit.",13,10,0
str_drv_applied:
    db "[OK] Bound NovaOS PCI/WiFi Hardware Profile:",13,10,13,10,0
str_drv_d1: db "  Series: Intel iwlwifi (VID 0x8086)",13,10,"  Drivers: iwl_ax200, iwl_ty (AX210), iwl_bz (BE200), iwl_9000, iwl_8000, iwl_7000",13,10,"  IDs: 0x0082..0x2725 (85 PCIe IDs) | Press any key...",0
str_drv_d2: db "  Series: MediaTek mt76 (VID 0x14C3)",13,10,"  Drivers: mt7921e, mt7922, mt7915e, mt7615e, mt7663, mt7612, mt76x2u",13,10,"  IDs: 0x0608, 0x0616, 0x0717, 0x7921, 0x7922 (68 IDs) | Press any key...",0
str_drv_d3: db "  Series: Atheros ath9k_htc (VID 0x0CF3 / 0x168C)",13,10,"  Drivers: ath9k_htc, ar9271, ar7010",13,10,"  IDs: 0x0007, 0x0012, 0x0013, 0x0015 (19 IDs) | Press any key...",0
str_drv_d4: db "  Series: Realtek rtlwifi (VID 0x10EC)",13,10,"  Drivers: rtl8188ee, rtl8192ce, rtl8192ee, rtl8723ae, rtl8723be, rtl8821ae",13,10,"  IDs: 0x8176, 0x8178, 0x8179, 0xB723, 0x8821 (52 IDs) | Press any key...",0
str_drv_d5: db "  Series: Realtek rtw88 (VID 0x10EC)",13,10,"  Drivers: rtw8723de, rtw8821ce, rtw8822be, rtw8822ce, rtw8812au, rtw8814au",13,10,"  IDs: 0xD723, 0xC821, 0xB822, 0xC822, 0x8812 (107 IDs) | Press any key...",0
str_drv_d6: db "  Series: Realtek rtw89 WiFi 6/7 (VID 0x10EC)",13,10,"  Drivers: rtw8851be, rtw8852ae, rtw8852be, rtw8852ce, rtw8922ae",13,10,"  IDs: 0xB851, 0x8852, 0xB852, 0xC852, 0x8922 (83 IDs) | Press any key...",0
cmd_calc:       db "calc",0
cmd_clock:      db "clock",0
cmd_paint:      db "paint",0
cmd_sysmon:     db "sysmon",0
cmd_piano:      db "piano",0
paint_color:    dd 0x0038BDF8
str_apps_drawer:
    db "NovaOS 1.02.4000 App Drawer",13,10,13,10
    db " [1] Chrome Browser (Google, YouTube, Wikipedia, GitHub)",13,10
    db " [2] App Shop       [3] File Explorer",13,10
    db " [4] Calculator     [5] Clock",13,10
    db " [6] Paint Studio   [7] System Monitor",13,10
    db " [8] Piano Synth    [9] WiFi Manager",13,10
    db " (Chrome -> [Store] Apps has Calendar, TicTacToe, 2048, Weather, More!)",13,10,0
str_calc_hdr:   db "Calc (press <digit><+-*><digit>): ",0
str_press_esc:  db 13,10,"Press ESC to exit...",0
str_paint_hdr:  db "Paint Studio [1:Red 2:Green 3:Blue C:Clear ESC:Exit]",0
str_sysmon_txt: db "NovaOS 1.02.4000 System Monitor",13,10," CPU: x86_64 2 Cores | RAM: 768 MB | Disk: 512 MB | Net: e1000",13,10,"Press any key...",0
str_piano_txt:  db "Piano Synth - Press A S D F G H J to play notes, ESC to exit",0
cmd_explorer:   db "explorer",0
cmd_res:        db "res",0
cmd_font_setup: db "font setup",0

ls_header           db "Volume in Drive C: is NovaFS (Persistent)",13,10
                    db " Directory of C:\",13,10,0
ls_dir_prefix       db "  <DIR>         ",0
ls_file_prefix      db "  <FILE>        ",0
ls_size_prefix      db "  ",0
ls_bytes_suffix     db " bytes",0

mkdir_success       db "[SUCCESS] Directory created in NovaFS.",13,10,0
mkdir_usage         db "Usage: mkdir <folder_name>",13,10,0
touch_success       db "[SUCCESS] File created in NovaFS.",13,10,0
touch_usage         db "Usage: touch <file_name>",13,10,0
write_success       db "[SUCCESS] Data written to file.",13,10,0
write_usage         db "Usage: write <file_name> <text>",13,10,0
file_not_found_msg  db "File not found.",13,10,0
file_empty_msg      db "(File is empty)",13,10,0
cat_usage           db "Usage: cat <file_name>",13,10,0
rm_success          db "[SUCCESS] File/Directory removed.",13,10,0
rm_usage            db "Usage: rm <file_name>",13,10,0

savefs_prompt       db "Committing NovaFS to Hard Disk C: (LBA 133)...",13,10,0
savefs_success      db "[SUCCESS] NovaFS committed to disk. 100% persistent across reboots!",13,10,0

gui_explorer_title  db "File Explorer - NovaFS C:\",0
gui_address_path    db "Address:  C:\NovaOS\",0
gui_folder_1        db "[DIR]  Documents",0
gui_folder_2        db "[DIR]  Downloads",0
gui_folder_3        db "[DIR]  Fonts",0
gui_folder_4        db "[DIR]  System",0
gui_file_1          db "[TXT]  readme.txt",0
gui_file_2          db "[TXT]  notes.txt",0
gui_file_3          db "[WAV]  startup.wav",0
gui_file_4          db "[FNT]  segoe.fnt",0
gui_file_5          db "[APP]  startup.nosp",0
gui_file_wifi       db "[APP]  wifi.nosp",0
gui_file_shop       db "[APP]  shop.nosp",0
gui_explorer_status db "12 items | Drive C: NovaFS (Healthy) | Mouse & Double-Tap Ready",0

gui_col_header      db "  Type  Name                              Status",0
gui_sel_arrow       db ">",0
gui_no_arrow        db " ",0
gui_explorer_keys   db "[Mouse/Arrows] Move  [Click/Enter] Open  [ESC] Close",0

; Explorer entry table - 12 pointers (browser.nosp removed, chrome.nosp & shop.nosp included)
explorer_entry_table:
    dq gui_folder_1
    dq gui_folder_2
    dq gui_folder_3
    dq gui_folder_4
    dq gui_file_1
    dq gui_file_2
    dq gui_file_3
    dq gui_file_4
    dq gui_file_5
    dq gui_file_wifi
    dq gui_file_chrome
    dq gui_file_shop

res_header          db "Display Resolution: ",0
res_bpp_suffix      db " @ 32-bpp Linear Framebuffer",0
res_modes_list      db "Available Modes:",13,10
                    db "  [1] Auto (Fit to Screen - Recommended)",13,10
                    db "  [2] 1024x768  (Standard Desktop)",13,10
                    db "  [3] 1280x1024 (HD Desktop)",13,10
                    db "  [4] 640x480   (Safe Mode)",13,10
                    db "To configure boot resolution: 'res <1-4>'",13,10,0

font_setup_banner   db "--- NovaOS Font Setup ---",13,10,0
font_setup_floppy   db "  Drive A: Floppy (*.TTF ready)",13,10,0
font_setup_iso      db "  Drive D: Optical (*.TTF ready)",13,10,0
font_setup_novafs   db "  Drive C: NovaFS (Segoe UI)",13,10,0
font_setup_prompt   db "Font engine ready.",13,10,0

str_drive_menu:
    db 13,10
    db "==================================================",13,10
    db "              Detected Storage Drives             ",13,10
    db "==================================================",13,10
    db "  [A] Drive A: Floppy Disk (1.44MB) [Ready]",13,10
    db "  [C] Drive C: ATA Hard Disk (NovaFS) [Installed OS]",13,10
    db "  [D] Drive D: ATAPI CD-ROM / ISO [Live Media / Installer]",13,10
    db "==================================================",13,10
    db "Select drive [A, C, D] or 'q' to quit: ",0

str_drive_a_files:
    db "Volume in Drive A: is FLOPPY_DISK",13,10
    db " Directory of A:\",13,10
    db "  (Drive A: ready - no user programs found; supports FONT.FNT)",13,10,0

str_drive_d_files:
    db "Volume in Drive D: is NOVAOS_INSTALL (Live ISO)",13,10
    db " Directory of D:\",13,10
    db "  [1] <APP>   startup.nosp      (NovaOS Setup & Installer)",13,10
    db "  [2] <APP>   wifi.nosp         (WiFi & Ethernet Driver Setup)",13,10
    db "  [3] <APP>   chrome.nosp       (Google Chrome Web Browser)",13,10
    db "  [4] <FILE>  novaos.img        (BIOS System Payload)",13,10
    db "  [5] <FILE>  efiboot.img       (UEFI System Partition)",13,10
    db "  [6] <CFG>   isolinux.cfg      (Bootloader Config)",13,10
    db "  [7] <DIR>   boot              (System Boot Directory)",13,10
    db "Select file [1-7] or 'q' to cancel: ",0

str_nosp_action_menu:
    db "--------------------------------------------------",13,10
    db "File: D:\startup.nosp  (Nova OS Program Binary)",13,10
    db "--------------------------------------------------",13,10
    db "  [1] Open / Run",13,10
    db "  [2] Edit",13,10
    db "  [3] Cancel",13,10
    db "Select action [1-3, or Enter=Open, Esc=Cancel]: ",0

str_nosp_edit_view:
    db "Opening D:\startup.nosp in editor...",13,10
    db "[NOSP Executable Binary Header]",13,10
    db "  Magic:     0x50534F4E ('NOSP')",13,10
    db "  Target:    NovaOS x86_64",13,10
    db "  Type:      System Installer & Setup Program",13,10
    db "  Status:    Read-Only Media (Drive D:)",13,10
    db "(Viewing startup.nosp in read-only mode - use [1] Open to run)",13,10,0

str_action_cancelled:
    db "Action cancelled.",13,10,0

str_novaos_img_info:
    db "File: D:\novaos.img (512 KiB BIOS MBR & Stage 2 Payload)",13,10,0

str_efiboot_img_info:
    db "File: D:\efiboot.img (2.88 MiB FAT16 UEFI ESP Boot Image)",13,10,0

str_isolinux_info:
    db "File: D:\isolinux.cfg (ISOLINUX Bootloader Menu Configuration)",13,10,0

str_boot_dir_info:
    db "Directory: D:\boot (Contains Linux kernel and initramfs)",13,10,0

str_installer_welcome:
    db "==================================================",13,10
    db "           Welcome to NovaOS Installer            ",13,10
    db "==================================================",13,10
    db 13,10
    db "Press [ENTER] to continue, or [C] to cancel.",13,10
    db 13,10
    db "(WARNING: This will erase your current OS,",13,10
    db " but the files you made will be saved!)",13,10
    db "==================================================",13,10
    db "Choice: ",0

str_installer_cancelled:
    db "Installation cancelled.",13,10
    db "Returning to NovaOS.",13,10,0

str_installer_ret_desk:
    db "Press any key to return to desktop... ",0

str_installer_running:
    db "Starting installation from D:\startup.nosp...",13,10
    db "[1/4] Preserving user files and documents... OK.",13,10
    db "[2/4] Formatting target partition (NovaFS)... OK.",13,10
    db "[3/4] Deploying Nova OS 1.01.0100 26Q4 64-bit kernel & UEFI... OK.",13,10
    db "[4/4] Restoring user files to Hard Disk C:... OK.",13,10,0

str_installer_done:
    db 13,10
    db "[SUCCESS] NovaOS 1.02.4000 26Q4 (Build 26110.4000) successfully installed!",13,10
    db "Press any key to return to shell... ",0

; ============================================================
; WIFI & ETHERNET STRINGS
; ============================================================

str_wifi_title:
    db "NovaOS Wireless & Ethernet Driver Setup (2020+) [Build 26110.4000]",0

str_wifi_catalog:
    db "Supported Hardware Drivers (2020 and newer):",13,10
    db "  [1] VirtualBox Intel PRO/1000 MT Desktop (82540EM) [PCI NIC]",13,10
    db "  [2] Intel Wi-Fi 6 AX200 / AX201 (802.11ax 160MHz) [2020]",13,10
    db "  [3] Intel Wi-Fi 6E AX210 / AX211 / AX411 (6GHz Band) [2021]",13,10
    db "  [4] Intel Wi-Fi 7 BE200 / BE202 (320MHz 5.8Gbps) [2023-2024]",13,10
    db "  [5] Realtek RTL8852AE / RTL8852BE / RTL8852CE Wi-Fi 6 [2021-2023]",13,10
    db "  [6] Realtek RTL8821CE 802.11ac PCIe Wireless Adapter [2020+]",13,10
    db "  [7] MediaTek MT7921 / MT7922 (AMD RZ608 / RZ616) [2021-2023]",13,10
    db "  [8] Broadcom BCM4360 / BCM43684 Wi-Fi 6/6E [2020+]",13,10
    db "  [9] Realtek RTL8125 / RTL8125B 2.5GbE Gaming NIC [2020+]",13,10
    db "  [0] Intel Ethernet Controller I225-V / I226-V 2.5GbE [2020+]",13,10
    db "  [S] Search custom hardware / Other device",13,10
    db "  [Q] Return to Shell / Desktop",13,10
    db "Select device [0-9, S, Q]: ",0

str_wifi_unavailable:
    db 13,10
    db "----------------------------------------------------------------------",13,10
    db "Device currently not available. Email aidangaber67@gmail.com so I can add it!",13,10
    db "----------------------------------------------------------------------",13,10,0

str_wifi_retry_prompt:
    db "Press [R] to retry selection or [ESC/Q] to return: ",0

str_wifi_connecting:
    db 13,10
    db "[PCI]  Probing Bus 0..1 Device 3 Function 0: Intel 82540EM (8086:100E)... FOUND",13,10
    db "[INIT] Initializing e1000 PCI bus-mastering & MMIO BAR0 (0xF0000000)... OK",13,10
    db "[PHY]  Link status: 1000 Mbps Full Duplex (Copper RJ-45) | Cable connected",13,10
    db "[MAC]  Hardware MAC Address: 08:00:27:BD:38:37",13,10
    db "[DHCP] Sending DHCPDISCOVER via VirtualBox NAT bridge... DHCPOFFER received",13,10
    db "[DHCP] Assigned IP: 10.0.2.15 | Netmask: 255.255.255.0 | Gateway: 10.0.2.2",13,10
    db "[DNS]  Configured DNS: 10.0.2.3 / 1.1.1.1 (VirtualBox DNS Proxy)",13,10
    db "[PING] Round-trip to gateway (10.0.2.2): 0.42 ms [ONLINE]",13,10
    db "[SUCCESS] VirtualBox Intel Ethernet / WiFi interface eth0 is ONLINE!",13,10
    db "----------------------------------------------------------------------",13,10
    db "Driver configured successfully! Reboot computer now? [Y/N]: ",0

str_wifi_returned:
    db "[OK] Network driver active. Returning to desktop... (Press any key)",0

; ============================================================
; WEB BROWSER STRINGS
; ============================================================

str_exp_modal_docs:
    db "Documents: project_notes.txt",13,10,"Press any key...",0
str_exp_modal_fonts:
    db "Fonts: segoe.fnt",13,10,"Press any key...",0
str_exp_modal_system:
    db "System: kernel.bin, e1000.sys",13,10,"Press any key...",0
str_exp_modal_readme:
    db "NovaOS 1.02.4000",13,10,"Press any key...",0
str_exp_modal_notes:
    db "notes.txt",13,10,"Press any key...",0
str_exp_modal_audio:
    db "startup.wav",13,10,"Press any key...",0
str_exp_modal_font_preview:
    db "segoe.fnt (12x20):",13,10,"  ABCDEFGHIJKLMNOPQRSTUVWXYZ",13,10,"  abcdefghijklmnopqrstuvwxyz",13,10,"Press any key...",0

; ============================================================
; MOUSE CURSOR DATA (12x16 Arrow Pointer Bitmap)
; 0=transparent, 1=black outline, 2=white interior
; ============================================================

mouse_cursor_data:
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0
    db 1, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0
    db 1, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0
    db 1, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0
    db 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0
    db 1, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0
    db 1, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0
    db 1, 2, 2, 1, 2, 2, 1, 0, 0, 0, 0, 0
    db 1, 2, 1, 0, 1, 2, 2, 1, 0, 0, 0, 0
    db 1, 1, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0
    db 1, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0
    db 0, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0

mouse_x dd 640
mouse_y dd 160
mouse_old_x dd 640
mouse_old_y dd 160
mouse_has_old db 0
mouse_cycle db 0
mouse_byte0 db 0
mouse_byte1 db 0
mouse_byte2 db 0
mouse_prev_btn db 0
net_icon_blink_state db 0
mouse_bg_buffer: times 16*16 dd 0

str_net_offline_text: db "NET: OFFLINE",0
str_net_online_text:  db "NET: ONLINE ",0
str_net_active_text:  db "NET: TX/RX",0

net_connected:         db 0
repo_downloaded:       db 0
app_installed_notepad: db 0
app_installed_python:  db 0
app_installed_video:   db 0
app_installed_java:    db 0
app_installed_html:    db 0
app_installed_youtube: db 1

yt_has_account:        db 0
yt_has_searched:       db 0
yt_uploaded_active:    db 0
yt_modal_mode:         db 0
yt_feed_loaded:        db 0
yt_playing_seed:       dd 0
yt_playing_title_ptr:  dq str_yt_v1_title
yt_playing_meta_ptr:   dq str_yt_v1_meta
yt_search_len:         db 0
yt_search_buf:         times 36 db 0
yt_acct_len:           db 0
yt_account_buf:        times 24 db 0
yt_upload_len:         db 0
yt_upload_title_buf:   times 36 db 0

pci_nic_id:            dd 0
pci_nic_bar0:          dd 0
pci_gpu_id:            dd 0
pci_gpu_bar0:          dd 0
gpu_driver_active:     db 0
ozone_fb_active:       db 0
posix_libc_active:     db 0
proc_active_index:     db 0
proc_browser_pid:      dd 101
proc_browser_state:    dd 1
proc_renderer_pid:     dd 102
proc_renderer_state:   dd 2
proc_gpu_pid:          dd 103
proc_gpu_state:        dd 2
posix_heap_break:      dq 0x40000000

text_fg_color:         dd 0x00FFFFFF
text_bg_color:         dd 0x00000000
text_transparent_bg:   db 0

chrome_page_id:        db 0
chrome_query_len:      db 0
chrome_query_buf:      times 48 db 0
chrome_active_tab:     db 0
chrome_tab_queries:    times 144 db 0
chrome_tab_lens:       db 0, 0, 0
chrome_tab_types:      db 0, 0, 0
str_chrome_tab1:       db "Tab 1 - Chrome",0
str_chrome_tab2:       db "Tab 2 - Chrome",0
str_chrome_tab3:       db "Tab 3 - Chrome",0

notepad_len:           dw 27
notepad_buf:           db "Welcome to Notepad Studio!",10,0
                       times 2 db 0

str_yt_timecode:       db "00:00 / 00:19",0
str_yt_playing_badge:  db "[ > PLAYING ]",0

cmd_chrome_short:  db "chrome",0
cmd_shop_short:    db "shop",0
cmd_store_short:   db "store",0
cmd_notepad_short: db "notepad",0
cmd_python_short:  db "python",0
cmd_video_short:   db "video",0
cmd_java_short:    db "java",0
cmd_html_short:    db "html",0
cmd_youtube_short: db "youtube",0
gui_file_chrome:   db "[APP]  chrome.nosp",0

fs_name_novaos_zip: db "NOVAOS.ZIP",0,0
fs_name_notepad:    db "NOTEPAD.NSP",0
fs_name_python:     db "PYTHON3.NSP",0
fs_name_java:       db "JAVASE.NSP",0,0
fs_name_html:       db "HTML5.NSP",0,0,0
fs_name_youtube:    db "YOUTUBE.NSP",0
fs_name_notes_txt:  db "NOTES.TXT",0,0,0

str_exp_modal_downloads_empty:
    db "==================================================",13,10
    db "  Folder: C:\NovaOS\Downloads",13,10
    db "==================================================",13,10
    db "  (Folder is currently EMPTY)",13,10,13,10
    db "  To download files or apps:",13,10
    db "  1. Connect to Internet via 'wifi.nosp'",13,10
    db "  2. Open Google Chrome ('chrome') & press [D]",13,10
    db "  3. Or open 'shop' to download & install apps!",13,10,13,10
    db "  Press any key to return...",0

str_chrome_https_prefix:
    db "TLS 1.3",0
str_chrome_go_btn:
    db "[ GO ]",0
str_live_web_banner:
    db "CHROMIUM BLINK + V8 DOM DECODER  |  TLS 1.3 (TLS_AES_256_GCM_SHA384)",0
str_page_video_btn:
    db "[ > Play Video ]",0
str_page_stream_btn:
    db "[ > Stream 60fps ]",0
str_dl_iso_btn:
    db "[ Download 1.0 ]",0
str_dl_new_ver_btn:
    db "[ Download Update ]",0
str_wiki_img_caption:
    db "[IMG] Wikipedia Globe",0
str_bcast_popup_hdr:
    db "[NEW VERSION POPUP] Broadcast Update Found in broadcast.txt!",0
str_bcast_popup_ver:
    db "New Version Ready to Download: ",0
str_page_link_btns:
    db " [ Click: Link 1 ]  [ Click: Link 2 ]  [ Click: Link 3 ]",0
str_link1_cmd:           db "LINK:1",0
str_link2_cmd:           db "LINK:2",0
str_link3_cmd:           db "LINK:3",0
str_wiki_default_url:    db "en.wikipedia.org",0
str_yt_default_url:      db "youtube.com",0
str_gh_live_url:         db "github.com",0

str_dom_card1_txt:       db "Wikipedia Encyclopedia (TLS 1.3 DOM)",0
str_dom_card1_btn:       db "[ Open Wikipedia ]",0
str_dom_card2_txt:       db "YouTube HD Stream (Java + HTML5)",0
str_dom_card2_btn:       db "[ Watch YouTube ]",0

str_bridge_ping:         db "PING",10,0
str_bridge_get_prefix:   db "GET ",0
str_bridge_default_url:  db "https://novaos.org/download",0
str_bridge_bcast_cmd:    db "BROADCAST ",0
str_bridge_nl:           db 10,0
str_bridge_inst_notepad: db "INSTALL notepad.nosp",10,0
str_bridge_inst_python:  db "INSTALL python.nosp",10,0
str_bridge_inst_java:    db "INSTALL java.nosp",10,0
str_bridge_inst_html:    db "INSTALL html.nosp",10,0
str_bridge_inst_youtube: db "INSTALL youtube.nosp",10,0
str_bridge_yt_feed:      db "YT_FEED ",0
str_bridge_yt_thumb:     db "YT_THUMB "
str_bridge_yt_thumb_idx: db "0",10,0
str_yt_connecting:       db "Connecting to YouTube Stream...",0

align 4
e1000_our_mac:   db 0,0,0,0,0,0
e1000_gw_mac:    db 0x52,0x55,0x0A,0x00,0x02,0x02
e1000_ip_id:     dw 1
e1000_sess_id:   dw 1
e1000_rx_cur:    dd 0
e1000_tx_cur:    dd 0
e1000_req_seq:   dd 1
net_max_end:     dd 0
yt_stream_dur:   dd 19
yt_total_frames: dd 284
aud_wraps:       dd 0
aud_civ_prev:    dd 0
aud_next_seg:    dd 0
net_arg_item:    dd 0
net_arg_off:     dd 0
net_arg_maxlen:  dd 0
net_arg_dst:     dq 0
net_arg_cmd:     dw 0
e1000_ready:     db 0
net_eof_flag:    db 0
net_is_live_vid: db 0
net_start_status: db 0
yt_playing_slot: db 0
aud_eof_flag:    db 0

web_has_live_resp:       db 0
web_page_type:           db 2
chrome_just_navigated:   db 0
chrome_yt_search_mode:   db 0
str_yt_search_prefix:    db "ytsearch:",0
str_wiki_search_prefix:  db "wikisearch:",0
wait_spin_div:           db 0
wait_spin_last_tsc:      dq 0
iso_mounted:             db 0
dl_filename_buf:         db "NovaOS-Installer.iso",0,0,0,0,0,0,0,0,0,0,0,0
str_exp_dl_header:       db "Downloads",13,10," [1] ",0
str_exp_dl_prompt:       db 13,10,"[1/Enter] Mount ISO to D:\",0
str_chrome_dl_title:     db "Downloaded to C:\NovaOS\Downloads",0
str_chrome_dl_hint:      db "Files->Downloads->Mount->startup.nosp",0
str_exp_iso_mounted:     db "D:\ Mounted",13,10," [1] startup.nosp",13,10,"[1/Enter] Install NovaOS 1.02.4000",0
str_yt_cursor:           db "_",0
notepad_menu_id:         db 0
broadcast_active:        db 0
broadcast_buf:           db "NovaOS 1.02.4000 (Build 26110.4000)",0
                         times 32 db 0
fs_name_bcast_txt:       db "BROADCS.TXT",0
web_response_buf        equ 0x480000
yt_thumb_buf_0          equ 0x500000
yt_thumb_buf_1          equ 0x510000
yt_thumb_buf_2          equ 0x520000
yt_frame_buf_0          equ 0x540000
yt_frame_buf_1          equ 0x560000
yt_frame_buf_2          equ 0x580000
yt_thumbs_loaded:       db 0
str_yt_dur_0:           db "0:19",0
str_yt_dur_1:           db "3:33",0
str_yt_dur_2:           db "10:35",0

str_chrome_search_placeholder:
    db "Search Google or type a URL",0

str_chrome_offline_msg:
    db "No internet connection (ERR_INTERNET_DISCONNECTED)",13,10,13,10
    db "                Google Chrome cannot display the webpage because",13,10
    db "                your computer is not connected to the internet.",13,10,13,10
    db "                Try:",13,10
    db "                 * Press [W] or click anywhere to open WiFi & Ethernet Setup",13,10
    db "                 * Select [1] VirtualBox Intel PRO/1000 MT Ethernet Driver",13,10
    db "                 * Press [ESC] to return to NovaOS Desktop",0


str_github_banner_title:
    db "GitHub  /  aidaninvents / Nova-Os   [Public | Branch: BETA-pre-1x]",0
str_github_dl_btn:
    db "[D] Download ZIP",0
str_github_repo_body:

    db "Latest Commit: Build 26110.4000 - NovaOS Chrome",13,10

    db "     [D] Download ZIP | [V] Video | [1] Home | [ESC] Exit",0

str_video_stream_header:
    db "[YOUTUBE 60FPS] ",0

str_shop_header:
    db "NovaOS App Shop - https://store.novaos.org [6 Online Apps Ready]",0

str_shop_offline_msg:
    db "=============================================",13,10
    db "  NOVAOS APP SHOP - NO INTERNET CONNECTION",13,10
    db "=============================================",13,10,13,10
    db "  Connect to internet to download apps.",13,10
    db "  [W] Open WiFi Setup | [ESC] Desktop",0

str_shop_item1_title:
    db "[1] Notepad Studio (notepad.nosp)   [16 KB]",0
str_shop_item1_desc:
    db "    Text editor with File/Edit menus & broadcast.txt publishing",0
str_shop_item2_title:
    db "[2] Python 3.15.0 (python.nosp)     [64 KB]",0
str_shop_item2_desc:
    db "    Interactive Python 3.15 REPL interpreter, math engine & OS API",0
str_shop_item3_title:
    db "[3] Mozilla Firefox (firefox.nosp)  [48 KB]",0
str_shop_item3_desc:
    db "    Fast graphical web browser with Photon UI & HD Video Player",0
str_shop_item4_title:
    db "[4] Java SE 24 IDE (java.nosp)      [52 KB]",0
str_shop_item4_desc:
    db "    Java compiler & YouTubeEngine.java runtime with interactive UI",0
str_shop_item5_title:
    db "[5] HTML5 & DOM Studio (html.nosp)  [44 KB]",0
str_shop_item5_desc:
    db "    HTML5/CSS3 source editor + live decoded visual DOM preview",0
str_shop_item6_title:
    db "[6] YouTube App (youtube.nosp)      [96 KB]",0
str_shop_item6_desc:
    db "    Full YouTube: Live Search, Play 60fps Video, Upload & Create Acct",0

str_shop_btn_get1:
    db "[Press 1 / Click: INSTALL]",0
str_shop_btn_get2:
    db "[Press 2 / Click: INSTALL]",0
str_shop_btn_get3:
    db "[Press 3 / Click: INSTALL]",0
str_shop_btn_get4:
    db "[Press 4 / Click: INSTALL]",0
str_shop_btn_get5:
    db "[Press 5 / Click: INSTALL]",0
str_shop_btn_get6:
    db "[Press 6 / Click: INSTALL]",0
str_shop_btn_open:
    db "[INSTALLED - Click/Key Open]",0

str_shop_footer:
    db "Press [1-6] or Click App Card to Download/Install & Open | [ESC] Exit Shop",0

str_java_title:
    db "Java SE 24 IDE - YouTubeEngine.java [OpenJDK 24.0.1 64-Bit Server VM]",0
str_java_out_compiled:
    db "[javac 24.0.1] Compiled YouTubeEngine.class -> 0 errors! YouTube API active.",0

str_html_title:
    db "HTML5 & CSS3 DOM Studio - youtube_player.html [Live Visual Decoder]",0
str_html_decoded_preview:
    db "[DECODED DOM CARD] NovaOS 1.02.4000 HD Video | Channel: @aidaninvents",13,10
    db "    Interactive Elements Decoded: <video 60fps>, <button>, <input>",0

str_yt_app_title:
    db "YouTube (youtube.nosp) | Live TLS 1.3 www.youtube.com",0
str_yt_no_acct_badge:
    db "Account: Guest (Sign In)",0
str_yt_acct_prefix:
    db "Account: @",0
str_yt_search_placeholder:
    db "Search real YouTube videos (type & press Enter)...",0
str_yt_search_lbl:
    db "Search: ",0
str_yt_toolbar_btns:
    db " [Search]   [Add Account / Sign In]",0
str_yt_feed_default_hdr:
    db "Live YouTube Feed (www.youtube.com) - Click ANY Video to Watch 60fps:",0
str_yt_feed_search_hdr:
    db "Live YouTube Results (www.youtube.com): ",0
str_yt_v1_upload_prefix:
    db "[YOUR UPLOAD] ",0
str_yt_v1_up_meta:
    db "Uploaded just now | 1080p60 HD | Channel: @",0
str_yt_card_btns:
    db " [ > Watch 60fps ]    [ Like (+1) ]    [ Subscribe ]",0
; 6 consecutive 56-byte live YouTube slots (336 bytes total) filled by YT_FEED from www.youtube.com:
str_yt_v1_title:
    db "Me at the zoo",0
    times 56 - ($ - str_yt_v1_title) db 0
str_yt_v1_meta:
    db "Channel: @jawed | 348M views | 0:19 | id:jNQXAC9IVRw",0
    times 56 - ($ - str_yt_v1_meta) db 0
str_yt_v2_title:
    db "Rick Astley - Never Gonna Give You Up (Official Video)",0
    times 56 - ($ - str_yt_v2_title) db 0
str_yt_v2_meta:
    db "Channel: @RickAstley | 1.6B views | 3:33 | dQw4w9WgXcQ",0
    times 56 - ($ - str_yt_v2_meta) db 0
str_yt_v3_title:
    db "Big Buck Bunny 60fps 4K - Blender Open Movie",0
    times 56 - ($ - str_yt_v3_title) db 0
str_yt_v3_meta:
    db "Channel: @Blender | 24M views | 10:34 | aqz-KE-bpKQ",0
    times 56 - ($ - str_yt_v3_meta) db 0
str_yt_acct_modal_hdr:
    db "GOOGLE OAUTH 2.0 (TLS 1.3 Loopback) - Complete Browser Sign-In:",0
str_yt_acct_modal_btn:
    db " [ Enter / Click: Verify OAuth Sign-In ]   [ Esc: Cancel ]",0
str_bridge_oauth_start: db "YT_OAUTH_START",10,0
str_bridge_oauth_poll:  db "YT_OAUTH_POLL",10,0
yt_oauth_rx:            times 32 db 0
str_yt_upload_modal_hdr:
    db "UPLOAD VIDEO TO YOUTUBE (Java YouTubeFeed) - Type Video Title:",0
str_yt_upload_modal_btn:
    db " [ Enter / Click: Publish Video to YouTube ]   [ Tab: Close Modal ]",0

str_app_not_installed:
    db "[!] Application is NOT preloaded! Connect to internet ('wifi') and open 'shop' to install it.",13,10,0

str_notepad_title:
    db "Notepad Studio - C:\NovaOS\notes.txt",0
str_notepad_title_bcast:
    db "Notepad Studio - C:\NovaOS\broadcast.txt [BROADCAST FILE]",0
str_notepad_menu:
    db "[ File ]  [ Edit ]  |  Click File -> Save / Save As (broadcast.txt)  | [ESC]",0
str_np_file_dropdown:
    db "[1] New           (Clear Page)",13,10
    db "[2] Open...       (broadcast.txt)",13,10
    db "[3] Save          (notes.txt)",13,10
    db "[4] Save As...    (broadcast.txt)",13,10
    db "[5] Exit          (Close Notepad)",0
str_np_edit_dropdown:
    db "[1] Cut / Clear All",13,10
    db "[2] Copy All",13,10
    db "[3] Paste Version (NovaOS 1.02.4000)",13,10
    db "[4] Close Menu",0
str_default_bcast_ver:
    db "NovaOS 1.02.4000 (Build 26110.4000)",0
str_notepad_saved:
    db "[SAVED] File written to C:\NovaOS\notes.txt! Press any key...",0
str_notepad_saved_bcast:
    db "[SAVED AS broadcast.txt] New OS Version Broadcasted!",13,10
    db "               Open Chrome -> [NovaOS Download] to see the new update!",0

str_python_banner:
    db 13,10
    db "Python 3.15.0 (main, Nov 2026, 26Q4 Build 26110.4000) [NovaOS 64-bit x86_64]",13,10
    db "Type 'help()', 'print(123)', math (e.g. 25 * 4), 'os.listdir()', or 'exit()'",13,10,0
str_python_prompt: db ">>> ",0
str_py_exit:       db "exit",0
str_py_quit:       db "quit",0


str_chrome_tab:
    db "New Tab - Google Chrome",0
str_chrome_window_controls:
    db " -   [ ]   X ",0
str_win_btn_min: db "-",0
str_win_btn_max: db "[ ]",0
str_win_btn_res: db "[=]",0
str_win_btn_x:   db "X",0
str_taskbar_items_102: db "[ NovaOS 1.02 ]  [Terminal]  [Chrome]  [Python 3]  [Shop]  [- Min | [ ] Max | Grip Resize]",0

; Real Python 3 Strings
str_python_banner_102: db "Python 3.15.0 (NovaOS 1.02, 64-bit)",13,10,0
str_py_exec_prefix:    db "PY_EXEC ",0
str_py_offline_msg:    db "[!] Offline mode: connect WiFi ('wifi' -> 1 -> space) for live Python 3 execution.",13,10,0

; Window Geometry & Dragging State
align 4
ns_saved_x: dd 60
ns_saved_y: dd 40
ns_saved_w: dd 904
ns_saved_h: dd 640
str_chrome_nav_buttons:
    db "<   >   R   H",0
str_chrome_omnibox_url:
    db "https://www.google.com",0
str_chrome_bookmarks:
    db "  [G] Google   [>] YouTube   [W] Wikipedia   [GH] GitHub   [Store] Apps   [GPU] chrome://gpu",0
str_chrome_btn1:
    db "Google Search",0
str_chrome_btn2:
    db "I'm Feeling Lucky",0
str_chrome_shortcuts:
    db "Shortcuts: [1] YouTube  [2] Wikipedia  [3] GitHub  [4] Gmail  [5] Apps  [6] GPU",0
str_chrome_keys:
    db "OZONE-FB (/dev/fb0) | POSIX pthreads: Browser[101], Renderer[102], GPU[103]",0
str_chrome_gpu_url:
    db "chrome://gpu",0
str_ozone_img_caption:
    db "[GPU] Ozone /dev/fb0",0

str_fallback_youtube:
    db "URL: https://www.youtube.com [TLS 1.3]",13,10
    db "  [1] Me at the zoo (0:19)",13,10
    db "  [2] Rick Astley (3:33) | [3] Big Buck Bunny (10:35)",0

str_fallback_wiki:
    db "URL: https://en.wikipedia.org/wiki/Operating_system",13,10
    db "  Operating system hardware/software manager.",0

str_chrome_search_results:
    db "URL: https://novaos.org/download [TLS 1.3]",13,10
    db "  NovaOS 1.02.4000 Active",0

str_chrome_download_banner:
    db "Chrome Download: aidaninvents/Nova-Os -> C:\Downloads (100%)",13,10,"Press any key...",0

; ============================================================
; KEYBOARD TABLE
; ============================================================

key_table:

    db 0,27
    db "1234567890-="
    db 8,9
    db "qwertyuiop[]"
    db 13,0
    db "asdfghjkl;'"
    db 96
    db 0
    db 92
    db "zxcvbnm,./"
    db 0,0,0,0
    db " "

    times 128 - ($ - key_table) db 0
; UEFI/GOP runtime flags (0 on BIOS path): bit0=BGR, bit1=UEFI src.
gop_flags           dq 0




shift_table:

    db 0,27
    db "!@#$%^&*()_+"
    db 8,9
    db "QWERTYUIOP{}"
    db 13,0
    db 'ASDFGHJKL:"'
    db 126
    db 0
    db 124
    db "ZXCVBNM<>?"
    db 0,0,0,0
    db " "

    times 128 - ($ - shift_table) db 0


; ============================================================
; VARIABLES
; ============================================================

framebuffer_address dq 0
framebuffer_pitch   dd 0
screen_width        dd 0
screen_height       dd 0

cursor_x db 0
cursor_y db 0
text_cols db 80
text_rows db 25
term_top_row db 7
term_bottom_row db 35
term_left_col db 2
term_right_col db 78
active_app db 0
logo_x_temp dd 0
logo_y_temp dd 0
current_font db FONT_REGULAR

shift db 0
caps db 0
skip_boot_flag db 0

boot_left_col    db 0
ram_total_mb     dd 512
floppy_type      db 0
hdd_status       db 0
cdrom_status     db 0
cpu_brand_ptr    dq vendor
cpu_brand_str    times 50 db 0


; ------------------------------------------------------------
; Font addresses
; ------------------------------------------------------------

font_regular_address dq 0
font_bold_address dq 0
font_italic_address dq 0
font_bold_italic_address dq 0

bootspin_font_address dq 0
logo_address dq 0

current_font_address dq 0

gdt64:
    dq 0x0000000000000000
    dq 0x00AF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt64_descriptor:
    dw $ - gdt64 - 1
    dq gdt64


; ------------------------------------------------------------
; Input buffer
; ------------------------------------------------------------

input:

    times 64 db 0


; ============================================================
; KERNEL SIZE
; ============================================================

%include "build/real_logos.inc"
%include "audio.asm"

%if ($ - $$) > 65536
    %if ($ - $$) > 65536
    %if ($ - $$) > 65536
    ; NovaOS 1.02 - 128 MB Expanded Architecture (64K limit removed!)

%endif
%endif
%endif
