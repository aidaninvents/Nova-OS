; ============================================================
; NovaOS AC'97 AUDIO DRIVER
; QEMU Intel 82801AA / ICH AC'97 compatible
;
; Current startup audio:
;   STARTUP.WAV
;   48000 Hz
;   stereo
;   16-bit PCM
;
; PCM data is copied directly into the DMA buffer.
;
; AC'97 BDL lengths are expressed in 16-bit samples,
; NOT bytes.
;
; One BDL descriptor can contain at most:
;   65535 16-bit samples
;   = 131070 bytes
;
; Larger WAV files use multiple BDL descriptors.
; ============================================================

BITS 64
DEFAULT ABS

; ------------------------------------------------------------
; PCI
; ------------------------------------------------------------

PCI_CONFIG_ADDRESS equ 0xCF8
PCI_CONFIG_DATA    equ 0xCFC

AUDIO_PCI_VENDOR   equ 0x8086
AUDIO_PCI_DEVICE   equ 0x2415

; ------------------------------------------------------------
; NovaFS
; ------------------------------------------------------------

NOVAFS_BASE        equ 0x30000
NOVAFS_DIR         equ NOVAFS_BASE + 0x200
NOVAFS_ENTRY_SIZE  equ 32

; ------------------------------------------------------------
; Audio memory
;
; 0x600000 is safely above the current kernel/stack area.
;
; The current WAV contains 55122 bytes of mono PCM.
; Stereo expansion therefore needs 110244 bytes.
; ------------------------------------------------------------

AUDIO_DMA_BUFFER   equ 0x00600000
AUDIO_BDL          equ 0x005F0000

; Maximum PCM payload: 10 MiB.
AUDIO_MAX_BYTES      equ 10485760

; 65534 16-bit samples = 131068 bytes (28 descriptors for 19s <= 32 AC'97 HW BDL limit).
AUDIO_BDL_MAX_BYTES  equ 131068

; 128 descriptors gives room for more than 10 MiB.
AUDIO_BDL_ENTRIES    equ 128

; ------------------------------------------------------------
; AC'97 mixer registers
; ------------------------------------------------------------

NAM_MASTER_VOLUME  equ 0x02
NAM_PCM_VOLUME     equ 0x18
NAM_PCM_RATE       equ 0x2C

; ------------------------------------------------------------
; AC'97 native audio bus master registers
;
; PCM OUT starts at +0x10.
; ------------------------------------------------------------

PO_BDBAR           equ 0x10
PO_CIV             equ 0x14
PO_LVI             equ 0x15
PO_SR              equ 0x16
PO_PICB            equ 0x18
PO_PIV             equ 0x1A
PO_CR              equ 0x1B

NABM_GLOB_CNT      equ 0x2C
NABM_GLOB_STA      equ 0x30

; ------------------------------------------------------------
; PCI command bits
; ------------------------------------------------------------

PCI_COMMAND_IO     equ 0x0001
PCI_COMMAND_MASTER equ 0x0004

; ------------------------------------------------------------
; AC'97 BDL control
;
; Bit 31 = interrupt on completion.
; Low 16 bits = number of 16-bit samples.
; ------------------------------------------------------------

BD_IOC             equ 0x80000000

; ============================================================
; AUDIO INITIALIZATION
; ============================================================

audio_debug_init:
    ; COM1 = 0x3F8, 115200 8N1
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al

    mov dx, 0x3F8
    mov al, 0x01
    out dx, al

    mov dx, 0x3F9
    xor al, al
    out dx, al

    mov dx, 0x3FB
    mov al, 0x03
    out dx, al

    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al

    mov dx, 0x3FC
    mov al, 0x03
    out dx, al
    ret

audio_debug_char:
    push rax
    push rdx

.wait:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jz .wait

    mov dx, 0x3F8
    pop rdx
    pop rax
    out dx, al
    ret

audio_init:

    cld

    call audio_debug_init

    ; --------------------------------------------------------
    ; Find Intel AC'97 PCI controller.
    ; --------------------------------------------------------

    call audio_find_pci
    jc .failed

    ; --------------------------------------------------------
    ; Get BAR0 = mixer / native audio registers.
    ; Get BAR1 = bus-master registers.
    ; --------------------------------------------------------

    mov eax, [audio_bar0]
    and eax, 0xFFFFFFFC
    mov [audio_mixer], eax

    mov eax, [audio_bar1]
    and eax, 0xFFFFFFFC
    mov [audio_bm], eax

    ; --------------------------------------------------------
    ; Enable PCI I/O space + bus mastering.
    ;
    ; IMPORTANT:
    ; Preserve the existing command-register bits.
    ; --------------------------------------------------------

    mov eax, [audio_pci_config_command]
    or eax, PCI_COMMAND_IO | PCI_COMMAND_MASTER

    mov ecx, [audio_pci_config_command_address]

    mov dx, PCI_CONFIG_ADDRESS
    mov eax, ecx
    out dx, eax

    mov dx, PCI_CONFIG_DATA
    mov eax, [audio_pci_config_command]
    or eax, PCI_COMMAND_IO | PCI_COMMAND_MASTER
    out dx, eax

    ; --------------------------------------------------------
    ; Deassert AC-Link Cold Reset & Reset AC'97 Mixer.
    ; --------------------------------------------------------

    mov eax, [audio_bm]
    add eax, NABM_GLOB_CNT
    mov dx, ax
    in eax, dx
    or eax, 0x00000002
    out dx, eax

    mov eax, [audio_mixer]
    mov dx, ax
    xor eax, eax
    out dx, ax

    ; --------------------------------------------------------
    ; Set master output (-3dB clean) & PCM output (0dB unity gain, unclipped).
    ; --------------------------------------------------------

    mov eax, [audio_mixer]
    add eax, NAM_MASTER_VOLUME
    mov dx, ax
    mov ax, 0x0202
    out dx, ax

    mov eax, [audio_mixer]
    add eax, NAM_PCM_VOLUME
    mov dx, ax
    mov ax, 0x0808
    out dx, ax

    ; --------------------------------------------------------
    ; Enable VRA & Set PCM sample rate to 48000 Hz.
    ; --------------------------------------------------------

    mov eax, [audio_mixer]
    add eax, 0x2A
    mov dx, ax
    mov eax, 1
    out dx, ax

    mov eax, [audio_mixer]
    add eax, NAM_PCM_RATE
    mov dx, ax
    mov eax, 48000
    out dx, ax

    ; --------------------------------------------------------
    ; Find STARTUP.WAV in NovaFS.
    ; --------------------------------------------------------

    call audio_find_wav
    jc .failed_find

    ; --------------------------------------------------------
    ; Decode WAV and prepare stereo DMA buffer.
    ; --------------------------------------------------------

    call audio_load_wav
    jc .failed_load

    ; --------------------------------------------------------
    ; Start PCM output DMA.
    ; --------------------------------------------------------

    call audio_start_dma
    jc .failed_dma

    clc
    ret

.failed_find:
    stc
    ret

.failed_load:
    stc
    ret

.failed_dma:
    stc
    ret

.failed:
    stc
    ret


; ============================================================
; PCI CONFIGURATION READ
;
; EBX = device number 0..31
; ECX = configuration register offset
;
; Returns EAX = configuration DWORD
; ============================================================

audio_pci_read:

    mov eax, ebx
    or eax, 0x80000000
    add eax, ecx

    mov dx, PCI_CONFIG_ADDRESS
    out dx, eax

    mov dx, PCI_CONFIG_DATA
    in eax, dx

    ret


; ============================================================
; FIND INTEL / REAL HARDWARE AC'97 PCI DEVICE
;
; Scans PCI Bus 0..1, Devices 0..31, Functions 0..7.
; Supports:
;   Intel ICH, ICH0, ICH2, ICH3, ICH4, ICH5, ICH6, ICH7
;   VIA AC'97 (VT82C686, VT8233/35/37)
;   SiS 7012 AC'97
;   Generic PCI Multimedia Audio (Class 0x0401 with IO BARs)
; ============================================================

audio_find_pci:

    push r12
    push r13
    push r14

    xor r12d, r12d
.bus_loop:
    xor r13d, r13d
.dev_loop:
    xor r14d, r14d
.func_loop:
    mov ebx, r12d
    shl ebx, 16
    mov eax, r13d
    shl eax, 11
    or ebx, eax
    mov eax, r14d
    shl eax, 8
    or ebx, eax

    xor ecx, ecx
    call audio_pci_read
    cmp ax, 0xFFFF
    je .next_func
    test ax, ax
    jz .next_func

    cmp ax, 0x8086
    jne .check_via
    shr eax, 16
    cmp ax, 0x2415
    je .found_device
    cmp ax, 0x2425
    je .found_device
    cmp ax, 0x2445
    je .found_device
    cmp ax, 0x2485
    je .found_device
    cmp ax, 0x24C5
    je .found_device
    cmp ax, 0x24D5
    je .found_device
    cmp ax, 0x266E
    je .found_device
    cmp ax, 0x27DE
    je .found_device
    cmp ax, 0x7195
    je .found_device
    jmp .check_class

.check_via:
    cmp ax, 0x1106
    jne .check_sis
    shr eax, 16
    cmp ax, 0x3058
    je .found_device
    cmp ax, 0x3059
    je .found_device
    jmp .check_class

.check_sis:
    cmp ax, 0x1039
    jne .check_class
    shr eax, 16
    cmp ax, 0x7012
    je .found_device

.check_class:
    mov ecx, 0x08
    call audio_pci_read
    shr eax, 16
    cmp ax, 0x0401
    jne .next_func

.found_device:
    mov ecx, 0x10
    call audio_pci_read
    test al, 0x01
    jz .next_func
    mov [audio_bar0], eax

    mov ecx, 0x14
    call audio_pci_read
    test al, 0x01
    jz .next_func
    mov [audio_bar1], eax

    mov [audio_pci_device], ebx

    mov eax, ebx
    or eax, 0x80000004
    mov [audio_pci_config_command_address], eax

    mov dx, PCI_CONFIG_ADDRESS
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx
    mov [audio_pci_config_command], eax

    pop r14
    pop r13
    pop r12
    clc
    ret

.next_func:
    inc r14d
    cmp r14d, 8
    jb .func_loop

.next_dev:
    inc r13d
    cmp r13d, 32
    jb .dev_loop

.next_bus:
    inc r12d
    cmp r12d, 2
    jb .bus_loop

    pop r14
    pop r13
    pop r12
    stc
    ret


; ============================================================
; FIND STARTUP.WAV IN NOVAFS
;
; Directory entry:
;
; +0   filename[12]
; +12  start sector
; +16  file size
; ============================================================

audio_find_wav:

    mov rsi, NOVAFS_DIR
    mov ecx, 16

.next_entry:

    push rsi
    push rcx

    mov rdi, audio_filename
    mov edx, 12

.compare:

    mov al, [rsi]
    cmp al, [rdi]
    jne .not_match

    inc rsi
    inc rdi
    dec edx

    jnz .compare

    ; --------------------------------------------------------
    ; Match.
    ; --------------------------------------------------------

    pop rcx
    pop rsi

    ; Start sector is relative to NovaFS image.

    mov eax, [rsi + 12]
    shl eax, 9
    add eax, NOVAFS_BASE

    mov [audio_wav_base], eax

    ; File size.

    mov eax, [rsi + 16]
    mov [audio_wav_file_size], eax

    clc
    ret

.not_match:

    pop rcx
    pop rsi

    add rsi, NOVAFS_ENTRY_SIZE

    loop .next_entry

    stc
    ret


; ============================================================
; LOAD WAV
;
; Validates:
;
; RIFF
; WAVE
; PCM
; mono
; 22050 Hz
; 16-bit
;
; Then:
;
; 1. Copies mono PCM into AUDIO_DMA_BUFFER.
; 2. Expands it in-place backwards into stereo.
;
; Example:
;
; mono:
;   A B C
;
; stereo:
;   A A B B C C
;
; Since samples are 16-bit words:
;
;   A A = left/right
;
; ============================================================

audio_load_wav:

    mov rbx, [audio_wav_base]

    ; --------------------------------------------------------
    ; Basic RIFF/WAVE validation.
    ; --------------------------------------------------------

    mov eax, [rbx]
    cmp eax, 0x46464952              ; "RIFF"
    jne .bad

    mov eax, [rbx + 8]
    cmp eax, 0x45564157              ; "WAVE"
    jne .bad

    ; --------------------------------------------------------
    ; Scan RIFF chunks.
    ;
    ; We do NOT assume fmt is immediately after the RIFF header.
    ; This handles JUNK/LIST/fact/etc. chunks correctly.
    ; --------------------------------------------------------

    mov rsi, rbx
    add rsi, 12

    xor r8d, r8d                     ; fmt found
    xor r9d, r9d                     ; data found

.find_chunk:

    ; File end.
    mov rax, rbx
    add rax, [audio_wav_file_size]

    ; Need an 8-byte chunk header.
    mov rdx, rsi
    add rdx, 8
    cmp rdx, rax
    ja .bad

    ; Chunk size.
    mov ecx, [rsi + 4]

    ; Make sure chunk payload fits in file.
    mov rdx, rsi
    add rdx, 8
    mov eax, ecx
    add rdx, rax

    cmp rdx, rax                     ; overflow check
    jb .bad

    mov rax, rbx
    add rax, [audio_wav_file_size]
    cmp rdx, rax
    ja .bad

    ; --------------------------------------------------------
    ; "fmt "
    ; --------------------------------------------------------

    cmp dword [rsi], 0x20746D66
    jne .check_data

    ; fmt must contain at least the 16-byte PCM header.
    cmp ecx, 16
    jb .bad

    ; PCM
    cmp word [rsi + 8], 1
    jne .bad

    ; Stereo
    cmp word [rsi + 10], 2
    jne .bad

    ; 48000 Hz
    cmp dword [rsi + 12], 48000
    jne .bad

    ; Stereo 16-bit = 4 bytes/frame.
    cmp word [rsi + 20], 4
    jne .bad

    ; 16-bit.
    cmp word [rsi + 22], 16
    jne .bad

    mov r8d, 1
    jmp .next_chunk

.check_data:

    cmp dword [rsi], 0x61746164       ; "data"
    jne .next_chunk

    ; Data chunk must be non-empty.
    test ecx, ecx
    jz .bad

    ; Even number of bytes for 16-bit PCM.
    test ecx, 1
    jnz .bad

    ; Maximum supported PCM payload = 10 MiB.
    cmp ecx, AUDIO_MAX_BYTES
    ja .bad

    ; Save PCM size.
    mov [audio_size], ecx

    ; Save PCM data address.
    lea rdx, [rsi + 8]
    mov [audio_data], rdx

    mov r9d, 1

.next_chunk:

    ; Advance by:
    ;   8-byte header + chunk size
    ; rounded to an even byte boundary.
    mov eax, ecx
    inc eax
    and eax, 0xFFFFFFFE
    add eax, 8

    add rsi, rax

    ; If both fmt and data were found, we're done.
    cmp r8d, 1
    jne .continue_scan

    cmp r9d, 1
    je .copy_pcm

.continue_scan:

    mov rax, rbx
    add rax, [audio_wav_file_size]

    cmp rsi, rax
    jb .find_chunk

    ; Reached EOF without finding required chunks.
    jmp .bad

.copy_pcm:

    ; --------------------------------------------------------
    ; Copy PCM directly.
    ; WAV is already stereo 16-bit.
    ; --------------------------------------------------------

    mov rsi, [audio_data]
    mov rdi, AUDIO_DMA_BUFFER
    mov ecx, [audio_size]
    rep movsb

    clc
    ret

.bad:
    stc
    ret


audio_reset_po:
    mov eax, [audio_bm]
    add eax, PO_CR
    mov dx, ax
    mov al, 0x02
    out dx, al
    mov ecx, 10000
.wait_rr:
    in al, dx
    test al, 0x02
    jz .rr_done
    pause
    dec ecx
    jnz .wait_rr
.rr_done:
    xor al, al
    out dx, al
    ret

; bl = initial LVI (0..31); assumes AUDIO_BDL is already populated
audio_arm_bdl:
    mov eax, [audio_bm]
    add eax, PO_BDBAR
    mov dx, ax
    mov eax, AUDIO_BDL
    out dx, eax

    mov eax, [audio_bm]
    add eax, PO_LVI
    mov dx, ax
    mov al, bl
    out dx, al

    mov eax, [audio_bm]
    add eax, PO_SR
    mov dx, ax
    mov ax, 0x001C
    out dx, ax

    mov eax, [audio_bm]
    add eax, PO_CR
    mov dx, ax
    mov al, 0x01
    out dx, al
    clc
    ret

audio_start_dma:

    ; --------------------------------------------------------
    ; Stop PCM output before changing the BDL.
    ; --------------------------------------------------------

    call audio_reset_po

    ; --------------------------------------------------------
    ; Clear the entire BDL table.
    ; 128 entries * 8 bytes = 1024 bytes.
    ; --------------------------------------------------------

    mov rdi, AUDIO_BDL
    xor eax, eax
    mov ecx, AUDIO_BDL_ENTRIES * 2
    rep stosd

    ; --------------------------------------------------------
    ; Split the PCM buffer into BDL entries.
    ;
    ; Each descriptor:
    ;   dword 0 = physical buffer address
    ;   dword 1 = number of 16-bit samples + IOC
    ;
    ; Maximum descriptor payload:
    ;   65535 samples = 131070 bytes
    ; --------------------------------------------------------

    mov rsi, AUDIO_DMA_BUFFER
    mov ecx, [audio_size]

    test ecx, ecx
    jz .failed

    xor edx, edx
    mov [audio_bdl_count], edx

.build_bdl:

    ; Need another descriptor.
    mov eax, [audio_bdl_count]
    cmp eax, AUDIO_BDL_ENTRIES
    jae .failed

    ; Remaining bytes in ECX.
    mov eax, ecx

    cmp eax, AUDIO_BDL_MAX_BYTES
    jbe .chunk_ready

    mov eax, AUDIO_BDL_MAX_BYTES

.chunk_ready:

    ; PCM is 16-bit, so descriptor size must be even.
    and eax, 0xFFFFFFFE

    test eax, eax
    jz .failed

    ; BDL buffer address.
    mov rdi, AUDIO_BDL
    mov edx, [audio_bdl_count]
    shl edx, 3
    add rdi, rdx

    mov rdx, rsi
    mov dword [rdi + 0], edx

    ; Convert bytes -> 16-bit samples.
    mov edx, eax
    shr edx, 1

    mov dword [rdi + 4], edx

    ; Advance PCM source.
    add rsi, rax

    ; Subtract descriptor bytes from remaining size.
    sub ecx, eax

    ; Count descriptor.
    mov edx, [audio_bdl_count]
    inc edx
    mov [audio_bdl_count], edx

    test ecx, ecx
    jnz .build_bdl

    ; --------------------------------------------------------
    ; Mark only the final descriptor with IOC.
    ; --------------------------------------------------------

    mov eax, [audio_bdl_count]
    dec eax
    shl eax, 3

    mov rdi, AUDIO_BDL
    add rdi, rax

    or dword [rdi + 4], BD_IOC

    ; Last Valid Index = descriptor_count - 1 -> arm BDL & start output.
    mov ebx, [audio_bdl_count]
    dec ebx
    jmp audio_arm_bdl

.failed:
    stc
    ret


audio_filename:
    db "STARTUP.WAV", 0

audio_pci_device:
    dd 0

audio_bar0:
    dd 0

audio_bar1:
    dd 0

audio_mixer:
    dd 0

audio_bm:
    dd 0

audio_pci_config_command_address:
    dd 0

audio_pci_config_command:
    dd 0

audio_wav_base:
    dq 0

audio_wav_file_size:
    dq 0

audio_data:
    dq 0

audio_size:
    dd 0

audio_bdl_count:
    dd 0
