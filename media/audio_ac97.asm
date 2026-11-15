; ============================================================
; media/audio_ac97.asm
; Intel AC'97 (8086:2415) PCI Audio Driver for NovaOS 64-bit
; Plays 16-bit stereo 44.1kHz PCM audio from DMA ring buffer.
; ============================================================

[bits 64]
DEFAULT ABS

AC97_PCI_VENDOR     equ 0x8086
AC97_PCI_DEVICE     equ 0x2415

AC97_DMA_BUFFER     equ 0x00600000     ; 16-bit stereo 44.1kHz PCM ring buffer
AC97_BDL_ADDR       equ 0x005F0000     ; Buffer Descriptor List physical address
AC97_BDL_ENTRIES    equ 32             ; Ring buffer descriptor slots

; AC'97 Native Audio Mixer (NAM) Registers
NAM_MASTER_VOL      equ 0x02
NAM_PCM_VOL         equ 0x18
NAM_SAMPLE_RATE     equ 0x2C           ; 44100 Hz PCM rate

; AC'97 Native Audio Bus Master (NABM) Registers
NABM_PO_BDBAR       equ 0x10           ; PCM Out Buffer Descriptor Base Address (32-bit)
NABM_PO_CIV         equ 0x14           ; Current Index Value
NABM_PO_LVI         equ 0x15           ; Last Valid Index
NABM_PO_SR          equ 0x16           ; Status Register
NABM_PO_PICB        equ 0x18           ; Position in Current Buffer
NABM_PO_CR          equ 0x1B           ; Control Register (bit 0=Run/Pause, bit 1=Reset)

section .data
align 8
global ac97_nambar
global ac97_nabmbar
global ac97_is_active
global ac97_is_paused

ac97_nambar:     dw 0
ac97_nabmbar:    dw 0
ac97_is_active:  db 0
ac97_is_paused:  db 0

section .text
global ac97_init
global ac97_play_dma
global ac97_pause_dma
global ac97_resume_dma
global ac97_stop_dma

; ------------------------------------------------------------
; ac97_init: Probe PCI, enable bus mastering, configure 44.1kHz stereo
; ------------------------------------------------------------
ac97_init:
    push rax
    push rbx
    push rcx
    push rdx

    ; Probe PCI bus for Intel AC'97 (8086:2415)
    xor ebx, ebx
.pci_scan_loop:
    cmp ebx, 0x10000          ; Bus 0..255, Dev 0..31
    jae .ac97_not_found

    ; Read Vendor + Device ID
    mov eax, 0x80000000
    mov edx, ebx
    shl edx, 8
    or eax, edx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx

    cmp eax, 0x24158086       ; Intel AC'97 ICH (8086:2415)
    je .ac97_found
    cmp eax, 0x00021078       ; Cyrix/AMD 5530
    je .ac97_found
    inc ebx
    jmp .pci_scan_loop

.ac97_found:
    ; Enable PCI I/O Space (bit 0) and Bus Master (bit 2)
    mov eax, 0x80000004
    mov edx, ebx
    shl edx, 8
    or eax, edx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    or eax, 0x0005            ; I/O + Bus Master
    out dx, eax

    ; Read BAR0 (NAMBAR - Native Audio Mixer Base Address)
    mov eax, 0x80000010
    mov edx, ebx
    shl edx, 8
    or eax, edx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    and eax, 0xFFFE
    mov [ac97_nambar], ax

    ; Read BAR1 (NABMBAR - Native Audio Bus Master Base Address)
    mov eax, 0x80000014
    mov edx, ebx
    shl edx, 8
    or eax, edx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    and eax, 0xFFFE
    mov [ac97_nabmbar], ax

    ; Configure Mixer: Master Volume = 0dB (unmuted)
    mov dx, [ac97_nambar]
    add dx, NAM_MASTER_VOL
    mov ax, 0x0000            ; 0 dB, unmuted
    out dx, ax

    ; PCM Output Volume = 0dB
    mov dx, [ac97_nambar]
    add dx, NAM_PCM_VOL
    mov ax, 0x0000
    out dx, ax

    ; Set Sample Rate: 44100 Hz
    mov dx, [ac97_nambar]
    add dx, NAM_SAMPLE_RATE
    mov ax, 44100
    out dx, ax

    ; Setup BDL (Buffer Descriptor List) for 16-bit stereo 44.1kHz PCM ring buffer
    mov rdi, AC97_BDL_ADDR
    mov rcx, AC97_BDL_ENTRIES
    mov eax, AC97_DMA_BUFFER
.bdl_setup:
    mov [rdi], eax            ; Buffer physical address
    mov word [rdi + 4], 0x4000 ; 16384 samples (32768 bytes) per descriptor
    mov word [rdi + 6], 0x8000 ; IOC = 1 (bit 15)
    add eax, 32768
    add rdi, 8
    dec rcx
    jnz .bdl_setup

    ; Set BDL base address in NABM
    mov dx, [ac97_nabmbar]
    add dx, NABM_PO_BDBAR
    mov eax, AC97_BDL_ADDR
    out dx, eax

    ; Set Last Valid Index (LVI = 31)
    mov dx, [ac97_nabmbar]
    add dx, NABM_PO_LVI
    mov al, (AC97_BDL_ENTRIES - 1)
    out dx, al

    mov byte [ac97_is_active], 1
    mov byte [ac97_is_paused], 0

.ac97_not_found:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------
; ac97_play_dma: Start PCM Out DMA playback
; ------------------------------------------------------------
ac97_play_dma:
    cmp byte [ac97_is_active], 1
    jne .play_ret
    mov dx, [ac97_nabmbar]
    add dx, NABM_PO_CR
    mov al, 0x01              ; Run bit = 1
    out dx, al
    mov byte [ac97_is_paused], 0
.play_ret:
    ret

; ------------------------------------------------------------
; ac97_pause_dma: Pause PCM Out DMA transfer
; ------------------------------------------------------------
ac97_pause_dma:
    cmp byte [ac97_is_active], 1
    jne .pause_ret
    mov dx, [ac97_nabmbar]
    add dx, NABM_PO_CR
    xor al, al                ; Run bit = 0 (Pause)
    out dx, al
    mov byte [ac97_is_paused], 1
.pause_ret:
    ret

; ------------------------------------------------------------
; ac97_resume_dma: Resume paused PCM Out DMA transfer
; ------------------------------------------------------------
ac97_resume_dma:
    cmp byte [ac97_is_active], 1
    jne .resume_ret
    mov dx, [ac97_nabmbar]
    add dx, NABM_PO_CR
    mov al, 0x01              ; Run bit = 1 (Resume)
    out dx, al
    mov byte [ac97_is_paused], 0
.resume_ret:
    ret

; ------------------------------------------------------------
; ac97_stop_dma: Stop PCM Out DMA transfer and reset buffer index
; ------------------------------------------------------------
ac97_stop_dma:
    cmp byte [ac97_is_active], 1
    jne .stop_ret
    mov dx, [ac97_nabmbar]
    add dx, NABM_PO_CR
    mov al, 0x02              ; Reset controller
    out dx, al
    mov byte [ac97_is_paused], 0
.stop_ret:
    ret
