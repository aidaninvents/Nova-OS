BITS 16
ORG 0x8000

; ================================================================
; Disk layout
; ================================================================

KERNEL_LBA       equ 5
KERNEL_SECTORS   equ 256

FS_LBA           equ 261
FS_SECTORS       equ 880

KERNEL_SEG       equ 0x1000
FS_SEG           equ 0x3000

; ================================================================
; VBE constants
; ================================================================

VBE_INFO         equ 0x9000
VBE_MODE_LFB     equ 0x4000

; Default candidate modes (32-bpp)
MODE_480P        equ 0x0142   ; 640x480x32
MODE_1024        equ 0x0144   ; 1024x768x32
MODE_1280        equ 0x0145   ; 1280x1024x32
VBE_CTRL_INFO    equ 0x6000

; ================================================================
; Page-table workspace (filled in 32-bit protected mode)
; ================================================================

PML4_ADDR        equ 0xA000
PDPT_ADDR        equ 0xB000
PD0_ADDR         equ 0xC000
PD1_ADDR         equ 0xD000
PD2_ADDR         equ 0xE000
PD3_ADDR         equ 0xF000

; ================================================================
; Entry point
; ================================================================

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl

    ; ------------------------------------------------------------
    ; Enable A20 Line (prevents 1 MiB address bit-20 wrap-around
    ; that splits the VBE Linear Framebuffer in BIOS mode!)
    ; ------------------------------------------------------------
    mov ax, 0x2401
    int 0x15                 ; BIOS A20 Enable

    in al, 0x92              ; System Control Port A (Fast A20)
    test al, 0x02
    jnz .a20_fast_done
    or al, 0x02
    and al, 0xFE             ; Ensure bit 0 (reset) is 0
    out 0x92, al
.a20_fast_done:

    ; ------------------------------------------------------------
    ; Resolution Menu (3-second timeout, default Auto 1024x768x32)
    ; ------------------------------------------------------------

    sti                      ; timer interrupt on for BIOS ticks

    mov si, menu_text
    call print

    ; Read starting tick from BIOS Data Area (0x0000:0x046C)
    mov eax, [0x046C]
    add eax, 54              ; ~3 seconds (18.2 ticks/s)
    mov [timeout_tick], eax

    mov byte [user_choice], '1'   ; Default: 1 = Auto (Fit to Screen)

.menu_loop:
    ; Check for key press
    mov ah, 0x01
    int 0x16
    jnz .key_pressed

    ; Check if 3 seconds expired
    mov eax, [0x046C]
    cmp eax, [timeout_tick]
    jae .apply_mode

    jmp .menu_loop

.key_pressed:
    ; Read key
    mov ah, 0x00
    int 0x16

    cmp al, '1'
    je .sel_opt
    cmp al, '2'
    je .sel_opt
    cmp al, '3'
    je .sel_opt
    cmp al, '4'
    je .sel_opt
    jmp .menu_loop

.sel_opt:
    mov [user_choice], al
    jmp .apply_mode

.apply_mode:
    cli

    ; Dynamic VBE Enumeration: find optimal mode on real hardware
    call find_mode
    jnc .mode_set_ok

    jmp vbe_error

.mode_set_ok:

    ; ------------------------------------------------------------
    ; Save framebuffer information for kernel:
    ; 0x9000 = framebuffer address (dword)
    ; 0x9004 = pitch (dword)
    ; 0x9008 = width (dword)
    ; 0x900C = height (dword)
    ; 0x9010 = bits per pixel (dword)
    ; ------------------------------------------------------------

    mov eax, [VBE_INFO + 40]
    mov [0x9000], eax

    movzx eax, word [VBE_INFO + 16]
    mov [0x9004], eax

    movzx eax, word [VBE_INFO + 18]
    mov [0x9008], eax

    movzx eax, word [VBE_INFO + 20]
    mov [0x900C], eax

    movzx eax, byte [VBE_INFO + 25]
    mov [0x9010], eax

    ; ------------------------------------------------------------
    ; Set the VBE graphics mode with linear framebuffer bit
    ; ------------------------------------------------------------

    mov ax, 0x4F02
    mov bx, [actual_mode]
    or  bx, VBE_MODE_LFB
    int 0x10

    cmp ax, 0x004F
    jne vbe_error

    ; ------------------------------------------------------------
    ; Load kernel (LBA 5, 128 sectors) to 0x1000:0 = 0x10000
    ; ------------------------------------------------------------

    mov eax, KERNEL_LBA
    mov ecx, KERNEL_SECTORS
    mov bx, KERNEL_SEG
    call read_blocks
    jc disk_error

    ; ------------------------------------------------------------
    ; Load NovaFS (LBA 133, 788 sectors) to 0x2000:0 = 0x20000
    ; ------------------------------------------------------------

    mov eax, FS_LBA
    mov ecx, FS_SECTORS
    mov bx, FS_SEG
    call read_blocks
    jc disk_error

    ; ------------------------------------------------------------
    ; Enter 32-bit protected mode
    ; ------------------------------------------------------------

    cli
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp CODE32_SEG:protected_mode


; ================================================================
; FIND_MODE: Dynamic VBE mode discovery and selection
; Returns CF=0 on success with [actual_mode] set, CF=1 on failure
; ================================================================

find_mode:
    push es
    push fs
    push ds
    push si
    push di
    push bx
    push dx

    mov word [best_mode], 0
    mov word [best_w], 0

    ; Request VBE 2.0+ Controller Information
    xor ax, ax
    mov es, ax
    mov di, VBE_CTRL_INFO
    mov dword [es:di], 'VBE2'
    mov ax, 0x4F00
    int 0x10

    cmp ax, 0x004F
    jne .try_candidates

    cmp dword [es:di], 'VESA'
    jne .try_candidates

    ; VideoModePtr is at offset 14 (far pointer: offset:segment)
    mov si, [es:di + 14]
    mov ax, [es:di + 16]
    mov fs, ax

.enum_loop:
    mov cx, [fs:si]
    add si, 2
    cmp cx, 0xFFFF
    je .enum_done

    call try_set_vbe
    jc .enum_loop

    ; Mode CX is valid and supported!
    ; Check if user requested Auto ('1') or 1024x768 ('2'):
    cmp byte [user_choice], '1'
    je .want_1024
    cmp byte [user_choice], '2'
    jne .check_3
.want_1024:
    cmp word [VBE_INFO + 18], 1024
    jne .check_best
    cmp word [VBE_INFO + 20], 768
    je .exact_match

.check_3:
    cmp byte [user_choice], '3'
    jne .check_4
    cmp word [VBE_INFO + 18], 1280
    jne .check_best
    cmp word [VBE_INFO + 20], 1024
    je .exact_match

.check_4:
    cmp byte [user_choice], '4'
    jne .check_best
    cmp word [VBE_INFO + 18], 640
    jne .check_best
    cmp word [VBE_INFO + 20], 480
    je .exact_match

.check_best:
    ; Track highest resolution up to 1280 wide for fallback
    mov ax, [VBE_INFO + 18]
    cmp ax, 1280
    ja .enum_loop
    cmp ax, [best_w]
    jbe .enum_loop

    mov [best_w], ax
    mov [best_mode], cx
    jmp .enum_loop

.exact_match:
    mov [actual_mode], cx
    jmp .success

.enum_done:
    ; If an Auto / Best mode was discovered, use it
    mov cx, [best_mode]
    test cx, cx
    jz .try_candidates

    call try_set_vbe
    jnc .success

.try_candidates:
    ; Fallback to standard VESA mode numbers
    mov bx, candidate_modes
.cand_loop:
    mov ax, [bx]
    add bx, 2
    test ax, ax
    jz .failed

    mov cx, ax
    call try_set_vbe
    jnc .success
    jmp .cand_loop

.success:
    pop dx
    pop bx
    pop di
    pop si
    pop ds
    pop fs
    pop es
    clc
    ret

.failed:
    pop dx
    pop bx
    pop di
    pop si
    pop ds
    pop fs
    pop es
    stc
    ret

candidate_modes:
    dw 0x0144, 0x0118, 0x0145, 0x011B, 0x0115, 0x0112, 0x0142, 0

; ================================================================
; TRY_SET_VBE (CX = candidate mode)
; Returns CF=0 on success, CF=1 on failure.
; Sets [actual_mode].
; ================================================================

try_set_vbe:
    push ax
    push di
    push es

    mov [actual_mode], cx

    mov ax, 0x4F01
    xor di, di
    mov es, di
    mov di, VBE_INFO
    int 0x10

    cmp ax, 0x004F
    jne .fail

    ; Must be supported (bit 0) AND have LFB (bit 7)
    mov ax, [VBE_INFO]
    and ax, 0x0081
    cmp ax, 0x0081
    jne .fail

    ; Must be strictly 32 bpp (4 bytes per pixel) for linear framebuffer
    mov al, [VBE_INFO + 25]
    cmp al, 32
    jne .fail
    ; PhysBasePtr must not be 0
    cmp dword [VBE_INFO + 40], 0
    je .fail

    clc
    jmp .done

.fail:
    stc

.done:
    pop es
    pop di
    pop ax
    ret


; ================================================================
; Read disk blocks using BIOS INT 13h extensions (LBA)
; EAX = starting LBA, ECX = sector count, BX = destination segment
; ================================================================

read_blocks:
    mov [read_lba], eax
    mov [read_remaining], cx
    mov [read_segment], bx

read_blocks_next:
    mov ax, [read_remaining]
    cmp ax, 16
    jbe read_blocks_count_ready
    mov ax, 16

read_blocks_count_ready:
    mov [dap_count], ax
    mov ax, [read_segment]
    mov [dap_segment], ax
    mov word [dap_offset], 0
    mov eax, [read_lba]
    mov [dap_lba_low], eax
    mov dword [dap_lba_high], 0

    mov si, dap
    mov dl, [boot_drive]
    mov di, 3

.retry_read:
    mov ah, 0x42
    int 0x13
    jnc .read_success

    xor ax, ax              ; disk reset
    int 0x13
    dec di
    jnz .retry_read

    stc
    ret

.read_success:

    movzx eax, word [dap_count]
    add [read_lba], eax
    mov ax, [dap_count]
    shl ax, 5
    add [read_segment], ax
    mov ax, [dap_count]
    sub [read_remaining], ax
    jnz read_blocks_next

    clc
    ret

read_blocks_error:
    stc
    ret


; ================================================================
; BIOS print helpers
; ================================================================

print:
    push ax
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop ax
    ret

vbe_error:
    mov si, vbe_error_msg
    call print
.hang:
    cli
    hlt
    jmp .hang

disk_error:
    mov si, disk_error_msg
    call print
.hang:
    cli
    hlt
    jmp .hang


; ================================================================
; 32-BIT PROTECTED MODE
; ================================================================

BITS 32

protected_mode:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x100000

    ; Clear PML4 (4 KiB)
    xor eax, eax
    mov edi, PML4_ADDR
    mov ecx, 1024
    rep stosd

    ; Clear PDPT (4 KiB)
    mov edi, PDPT_ADDR
    mov ecx, 1024
    rep stosd

    ; PML4[0] -> PDPT
    mov dword [PML4_ADDR], PDPT_ADDR | 0x003
    mov dword [PML4_ADDR + 4], 0

    ; PDPT[0..3] -> four page directories
    mov dword [PDPT_ADDR + 0],  PD0_ADDR | 0x003
    mov dword [PDPT_ADDR + 4],  0
    mov dword [PDPT_ADDR + 8],  PD1_ADDR | 0x003
    mov dword [PDPT_ADDR + 12], 0
    mov dword [PDPT_ADDR + 16], PD2_ADDR | 0x003
    mov dword [PDPT_ADDR + 20], 0
    mov dword [PDPT_ADDR + 24], PD3_ADDR | 0x003
    mov dword [PDPT_ADDR + 28], 0

    ; Fill four page directories (2048 x 2 MiB entries = 4 GiB identity)
    mov edi, PD0_ADDR
    mov eax, 0x00000083
    mov ecx, 2048

fill_page_directories:
    mov dword [edi], eax
    mov dword [edi + 4], 0
    add eax, 0x200000
    add edi, 8
    loop fill_page_directories

    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Load CR3
    mov eax, PML4_ADDR
    mov cr3, eax

    ; Enable Long Mode in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable Paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    jmp CODE64_SEG:long_mode_start


; ================================================================
; 64-BIT LONG MODE
; ================================================================

BITS 64

long_mode_start:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x400000

    mov rax, 0x10000
    jmp rax


; ================================================================
; Data
; ================================================================

BITS 16

menu_text:
    db 13,10,"NovaOS Boot Resolution Select:",13,10
    db "  [1] Auto (Fit to Screen - Recommended)",13,10
    db "  [2] 1024x768  (Standard)",13,10
    db "  [3] 1280x1024 (HD)",13,10
    db "  [4] 640x480   (Safe Mode)",13,10
    db "Auto-booting in 3s...",13,10,0

vbe_error_msg  db "VBE mode failed!",13,10,0
disk_error_msg db "Disk read error!",13,10,0

user_choice  db '1'
best_mode    dw 0
best_w       dw 0
actual_mode  dw 0
timeout_tick dd 0
boot_drive   db 0

read_lba:        dd 0
read_remaining:  dw 0
read_segment:    dw 0

; Disk Address Packet
dap:
    db 0x10, 0x00
dap_count:    dw 0
dap_offset:   dw 0
dap_segment:  dw 0
dap_lba_low:  dd 0
dap_lba_high: dd 0

; GDT
gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF   ; 32-bit code
    dq 0x00CF92000000FFFF   ; 32-bit data
    dq 0x00AF9A000000FFFF   ; 64-bit code
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE32_SEG equ 0x08
DATA_SEG   equ 0x10
CODE64_SEG equ 0x18

; Pad to exactly 2048 bytes (4 sectors)
%if ($ - $$) > 2048
    %error "stage2.asm is larger than 2048 bytes"
%endif

times 2048 - ($ - $$) db 0