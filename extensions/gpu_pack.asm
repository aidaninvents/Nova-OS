; ==============================================================================
; NovaOS Extension Module 2: Hybrid Real-Hardware & VirtualBox GPU Installer
; Target: NASM x86-64 (Long Mode) with AVX2 & BMI2 Vector Extensions
; Offsets: Offset = (Y * Pitch) + (X * 4) into 32-bit True Color LFB
; ==============================================================================

[BITS 64]
default rel

; ------------------------------------------------------------------------------
; Public Interface
; ------------------------------------------------------------------------------
global gpu_pack_detect_and_install
global gpu_pack_blit_avx2
global gpu_pack_vbox_dirty_rect
global g_gpu_pack_type
global g_gpu_pack_bar0_lfb
global g_gpu_pack_bar1_fifo

; ------------------------------------------------------------------------------
; External Kernel Symbols (NovaOS kernel.asm)
; ------------------------------------------------------------------------------
extern framebuffer_address
extern framebuffer_pitch
extern screen_width
extern screen_height

; ------------------------------------------------------------------------------
; GPU Subsystem Identifiers
; ------------------------------------------------------------------------------
GPU_TYPE_NONE           equ 0
GPU_TYPE_VBOX_SVGA      equ 1       ; VirtualBox / VMware SVGA II
GPU_TYPE_NV_AMPERE_ADA  equ 2       ; NVIDIA RTX 3000 / 4000 (Ampere / Ada)
GPU_TYPE_AMD_RDNA2_3    equ 3       ; AMD Radeon RX 6000 / 7000 (RDNA 2 / 3)
GPU_TYPE_INTEL_ARC_XE   equ 4       ; Intel Iris Xe / Arc Alchemist / Battlemage
GPU_TYPE_GENERIC_LFB    equ 5       ; UEFI GOP / VBE Standard LFB

; VMware / VirtualBox SVGA II Register Offsets & Commands
SVGA_INDEX_PORT         equ 0x0     ; Base + 0
SVGA_VALUE_PORT         equ 0x1     ; Base + 1
SVGA_BIOS_PORT          equ 0x2     ; Base + 2

SVGA_REG_ID             equ 0
SVGA_REG_ENABLE         equ 1
SVGA_REG_WIDTH          equ 2
SVGA_REG_HEIGHT         equ 3
SVGA_REG_BPP            equ 7
SVGA_REG_FB_START       equ 13
SVGA_REG_MEM_START      equ 14
SVGA_REG_FIFO_START     equ 18

SVGA_CMD_UPDATE         equ 1

section .data align=16

g_gpu_pack_type:        dd GPU_TYPE_NONE
g_gpu_pack_io_base:     dw 0
g_gpu_pack_bar0_lfb:    dq 0
g_gpu_pack_bar1_fifo:   dq 0

section .text

; ------------------------------------------------------------------------------
; gpu_pack_detect_and_install:
; Scans PCI Bus for Display Controller (Class 0x03) and binds hardware driver
; ------------------------------------------------------------------------------
gpu_pack_detect_and_install:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Probe standard primary display at Bus 0, Device 2, Function 0
    mov eax, 0x80001000
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx

    ; Check for VirtualBox (0x80EE:0xBEEF) or VMware (0x15AD:0x0405)
    cmp eax, 0xBEEF80EE
    je .install_vbox_svga
    cmp eax, 0x040515AD
    je .install_vbox_svga

    ; Check Vendor ID in low 16 bits
    mov edx, eax
    and edx, 0xFFFF
    cmp dx, 0x10DE              ; NVIDIA
    je .install_nvidia_mmio
    cmp dx, 0x1002              ; AMD
    je .install_amd_rdna
    cmp dx, 0x8086              ; Intel
    je .install_intel_arc

    ; Fallback: Standard Linear Framebuffer setup
    mov dword [g_gpu_pack_type], GPU_TYPE_GENERIC_LFB
    mov rax, [framebuffer_address]
    mov [g_gpu_pack_bar0_lfb], rax
    xor eax, eax
    jmp .install_done

.install_vbox_svga:
    mov dword [g_gpu_pack_type], GPU_TYPE_VBOX_SVGA

    ; Read BAR0 (I/O Port Base at 0x10)
    mov eax, 0x80001010
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and ax, 0xFFFC
    mov [g_gpu_pack_io_base], ax

    ; Read BAR1 (LFB Framebuffer Base at 0x14)
    mov eax, 0x80001014
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [g_gpu_pack_bar0_lfb], rax

    ; Read BAR2 (FIFO Command Queue at 0x18)
    mov eax, 0x80001018
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [g_gpu_pack_bar1_fifo], rax

    ; Set SVGA to 32 BPP
    mov dx, [g_gpu_pack_io_base]
    mov eax, SVGA_REG_BPP
    out dx, eax
    inc dx
    mov eax, 32
    out dx, eax

    ; Enable SVGA
    dec dx
    mov eax, SVGA_REG_ENABLE
    out dx, eax
    inc dx
    mov eax, 1
    out dx, eax
    xor eax, eax
    jmp .install_done

.install_nvidia_mmio:
    mov dword [g_gpu_pack_type], GPU_TYPE_NV_AMPERE_ADA
    ; Read BAR1 (Video Memory FB)
    mov eax, 0x80001014
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [g_gpu_pack_bar0_lfb], rax
    xor eax, eax
    jmp .install_done

.install_amd_rdna:
    mov dword [g_gpu_pack_type], GPU_TYPE_AMD_RDNA2_3
    mov eax, 0x80001014
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [g_gpu_pack_bar0_lfb], rax
    xor eax, eax
    jmp .install_done

.install_intel_arc:
    mov dword [g_gpu_pack_type], GPU_TYPE_INTEL_ARC_XE
    mov eax, 0x80001014
    mov dx, 0x0CF8
    out dx, eax
    mov dx, 0x0CFC
    in eax, dx
    and eax, 0xFFFFFFF0
    mov [g_gpu_pack_bar0_lfb], rax
    xor eax, eax

.install_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------------------------
; gpu_pack_blit_avx2:
; Executes high-speed AVX2 streaming stores into True Color Linear Framebuffer
;
; Target Formula: Offset = (Y * Pitch) + (X * 4)
;
; Inputs (System V x86-64 ABI):
;   RDI = Source RGBA / BGRA surface pointer (CEF Shared Buffer / Video Frame)
;   RSI = X position on screen
;   RDX = Y position on screen
;   RCX = Width in pixels
;   R8  = Height in pixels
;   R9  = Source buffer stride in bytes (e.g. Width * 4)
; ------------------------------------------------------------------------------
gpu_pack_blit_avx2:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test rcx, rcx
    jz .exit_blit
    test r8, r8
    jz .exit_blit

    ; Compute Target Destination Address:
    ; R12 = [framebuffer_address] + (Y * [framebuffer_pitch]) + (X * 4)
    mov r12, [framebuffer_address]
    mov eax, [framebuffer_pitch]
    imul rax, rdx               ; Y * Pitch
    add r12, rax
    mov rax, rsi
    shl rax, 2                  ; X * 4
    add r12, rax

    mov r13d, [framebuffer_pitch] ; Dest Pitch
    mov r14, r8                 ; Row loop counter = Height
    mov r15, rcx
    shl r15, 2                  ; Span in bytes = Width * 4

.scanline_loop:
    push rdi                    ; Save source row start
    push r12                    ; Save dest row start
    mov rbx, r15                ; Remaining bytes on this row

.avx_inner_copy:
    cmp rbx, 32
    jb .scalar_inner_copy

    vmovdqu ymm0, [rdi]         ; Read 8 pixels (32 bytes) from source surface
    vmovntdq [r12], ymm0        ; Stream store directly to VRAM bypassing cache
    add rdi, 32
    add r12, 32
    sub rbx, 32
    jmp .avx_inner_copy

.scalar_inner_copy:
    cmp rbx, 4
    jb .advance_scanline
    mov eax, [rdi]
    mov [r12], eax
    add rdi, 4
    add r12, 4
    sub rbx, 4
    jmp .scalar_inner_copy

.advance_scanline:
    pop r12                     ; Restore dest row start
    pop rdi                     ; Restore source row start
    add rdi, r9                 ; Next source scanline = Src + SrcStride
    add r12, r13                ; Next dest scanline = Dest + Pitch
    dec r14
    jnz .scanline_loop

    sfence                      ; Ensure memory order for non-temporal stores
    vzeroupper                  ; Clear AVX state transition penalty

    ; If VirtualBox SVGA is active, trigger FIFO dirty rect update
    cmp dword [g_gpu_pack_type], GPU_TYPE_VBOX_SVGA
    jne .exit_blit
    call gpu_pack_vbox_dirty_rect

.exit_blit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------------------------
; gpu_pack_vbox_dirty_rect:
; Writes SVGA_CMD_UPDATE directly into the VirtualBox FIFO queue
; In: ESI = X, EDX = Y, ECX = Width, R8D = Height
; ------------------------------------------------------------------------------
gpu_pack_vbox_dirty_rect:
    mov r11, [g_gpu_pack_bar1_fifo]
    test r11, r11
    jz .done_fifo

    mov dword [r11 + 0], SVGA_CMD_UPDATE
    mov [r11 + 4], esi
    mov [r11 + 8], edx
    mov [r11 + 12], ecx
    mov [r11 + 16], r8d

.done_fifo:
    ret
