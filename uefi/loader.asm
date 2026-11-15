; ==============================================================================
; NovaOS UEFI Bootloader (BOOTX64.EFI)
; x86-64 PE32+ application adhering to UEFI 2.x Specification
; Dynamic GOP mode selection, FAT file system payload loader,
; ExitBootServices transition to NovaOS 64-bit kernel.
; ==============================================================================
BITS 64
DEFAULT REL

%define IMAGE_BASE          0x140000000
%define SECTION_RVA         0x1000

; UEFI Return Codes
%define EFI_SUCCESS         0
%define EFI_FILE_MODE_READ  0x0000000000000001

; Memory Map & Target Locations
%define KERNEL_PHYS         0x10000
%define KERNEL_MAX          0x10000         ; 64 KiB
%define FS_PHYS             0x20000
%define FS_MAX              0x80000         ; 512 KiB
%define HANDOFF             0x9000
%define STACK_TOP           0x400000
%define PT_PML4             0xA000
%define PT_PDPT             0xB000
%define PT_PD0              0xC000

; GOP Constants
%define PixelRedGreenBlue   0
%define PixelBlueGreenRed   1

section .text vstart=(IMAGE_BASE + SECTION_RVA)

; ------------------------------------------------------------------------------
; efi_main(ImageHandle, SystemTable)
; RCX = ImageHandle
; RDX = SystemTable
; ------------------------------------------------------------------------------
global efi_main
efi_main:
    ; 8 pushes (64 bytes). With 8-byte ret address: 72 bytes.
    push rbp
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    ; Subtract 88 bytes (0x58): 72 + 88 = 160 (160 % 16 == 0).
    ; Stack is now strictly 16-byte aligned before any call!
    sub rsp, 0x58

    mov [rel img_handle], rcx
    mov [rel sys_table], rdx

    ; ConOut is at offset 64 (0x40) of EFI_SYSTEM_TABLE
    mov rax, [rdx + 64]
    mov [rel con_out], rax

    ; BootServices is at offset 96 (0x60) of EFI_SYSTEM_TABLE
    mov rax, [rdx + 96]
    mov [rel boot_svc], rax

    ; Print startup banner
    mov rcx, [rel con_out]
    lea rdx, [rel msg_hello]
    sub rsp, 32
    call [rcx + 8]          ; ConOut->OutputString(ConOut, String)
    add rsp, 32

    ; --------------------------------------------------------------------------
    ; 1. Locate GOP via BootServices->LocateProtocol
    ; LocateProtocol is offset 320 (0x140) in EFI_BOOT_SERVICES
    ; LocateProtocol(IN EFI_GUID *Protocol, IN VOID *Registration, OUT VOID **Interface)
    ; --------------------------------------------------------------------------
    mov rax, [rel boot_svc]
    lea rcx, [rel guid_gop]
    xor edx, edx
    lea r8, [rel gop_ptr]
    sub rsp, 32
    call [rax + 320]
    add rsp, 32
    test rax, rax
    jnz near .fail_gop

    mov rax, [rel gop_ptr]
    test rax, rax
    jz near .fail_gop

    ; GOP->Mode is at offset 24 (0x18)
    mov rbx, [rax + 24]
    mov [rel gop_mode], rbx
    test rbx, rbx
    jz near .fail_gop

    ; gop_mode->MaxMode is at offset 0 (UINT32)
    mov ecx, [rbx]
    mov [rel gop_max], ecx

    ; Query and find best GOP mode
    xor r14d, r14d          ; best_mode
    xor r15d, r15d          ; best_area
    xor ebx, ebx            ; mode_idx = 0

.mode_loop:
    cmp ebx, [rel gop_max]
    jae .mode_done

    mov rcx, [rel gop_ptr]  ; This
    mov edx, ebx            ; ModeNumber
    lea r8, [rel tmp_isz]   ; &SizeOfInfo
    lea r9, [rel tmp_info]  ; &Info
    sub rsp, 32
    call [rcx + 0]          ; GOP->QueryMode is at offset 0 (0x00)
    add rsp, 32
    test rax, rax
    jnz .mode_next

    mov rsi, [rel tmp_info]
    test rsi, rsi
    jz .mode_next

    ; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION offsets:
    ; +4:  HorizontalResolution
    ; +8:  VerticalResolution
    ; +12: PixelFormat
    ; +32: PixelsPerScanLine
    mov eax, [rsi + 4]      ; width
    mov edx, [rsi + 8]      ; height
    mov ecx, [rsi + 12]     ; pixel format

    ; Accept PixelRedGreenBlue (0) or PixelBlueGreenRed (1)
    cmp ecx, 1
    ja .mode_next

    ; Reject unsuited resolutions
    cmp eax, 640
    jb .mode_next
    cmp edx, 400
    jb .mode_next
    cmp eax, 2560
    ja .mode_next
    cmp edx, 1600
    ja .mode_next

    mov r10d, eax
    imul r10d, edx
    cmp r10d, r15d
    jbe .mode_next

    mov r15d, r10d
    mov r14d, ebx
    mov [rel best_w], eax
    mov [rel best_h], edx
    mov [rel best_fmt], ecx
    mov eax, [rsi + 32]
    mov [rel best_ppsl], eax

.mode_next:
    inc ebx
    jmp .mode_loop

.mode_done:
    test r15d, r15d
    jz near .fail_gop

    ; Set selected mode: GOP->SetMode(This, ModeNumber)
    ; SetMode is at offset 8 (0x08)
    mov rcx, [rel gop_ptr]
    mov edx, r14d
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    test rax, rax
    jnz near .fail_gop

    ; Re-read active mode parameters
    mov rax, [rel gop_ptr]
    mov rbx, [rax + 24]     ; gop->Mode
    mov [rel gop_mode], rbx

    mov rsi, [rbx + 8]      ; gop_mode->Info (offset 8)
    mov eax, [rsi + 4]
    mov [rel best_w], eax
    mov eax, [rsi + 8]
    mov [rel best_h], eax
    mov eax, [rsi + 12]
    mov [rel best_fmt], eax
    mov eax, [rsi + 32]     ; PixelsPerScanLine (offset 32)
    mov [rel best_ppsl], eax

    mov rax, [rbx + 24]     ; FrameBufferBase (offset 24)
    mov [rel fb_base], rax
    mov rax, [rbx + 32]     ; FrameBufferSize (offset 32)
    mov [rel fb_size], rax

    ; Print resolution
    mov rcx, [rel con_out]
    lea rdx, [rel msg_mode]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov eax, [rel best_w]
    call print_dec

    mov rcx, [rel con_out]
    lea rdx, [rel msg_x]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov eax, [rel best_h]
    call print_dec

    mov rcx, [rel con_out]
    lea rdx, [rel msg_nl]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; --------------------------------------------------------------------------
    ; 2. Load Payload Files (Kernel & NovaFS)
    ; --------------------------------------------------------------------------
    call load_payloads
    test rax, rax
    jnz near .fail_payload

    ; --------------------------------------------------------------------------
    ; 3. Populate NovaOS Handoff Table at 0x9000
    ; --------------------------------------------------------------------------
    mov rax, [rel fb_base]
    mov [abs HANDOFF + 0], eax          ; low 32-bit mirror
    mov eax, [rel best_ppsl]
    shl eax, 2
    mov [abs HANDOFF + 4], eax          ; low 32-bit pitch mirror
    mov eax, [rel best_w]
    mov [abs HANDOFF + 8], eax          ; width
    mov eax, [rel best_h]
    mov [abs HANDOFF + 12], eax         ; height
    mov dword [abs HANDOFF + 16], 32    ; 32 bpp
    mov dword [abs HANDOFF + 20], 0x504F474E ; Magic 'NGOP'
    mov eax, [rel best_w]
    mov [abs HANDOFF + 24], rax         ; qword width
    mov eax, [rel best_h]
    mov [abs HANDOFF + 32], rax         ; qword height
    mov eax, [rel best_ppsl]
    shl rax, 2
    mov [abs HANDOFF + 40], rax         ; qword pitch
    mov rax, [rel fb_base]
    mov [abs HANDOFF + 48], rax         ; qword framebuffer address
    mov eax, [rel best_fmt]
    cmp eax, PixelBlueGreenRed
    sete al
    movzx eax, al
    or eax, 2                           ; bit1 = UEFI source
    mov [abs HANDOFF + 56], rax         ; qword flags

    ; Print jumping status
    mov rcx, [rel con_out]
    lea rdx, [rel msg_jump]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; --------------------------------------------------------------------------
    ; 4. ExitBootServices
    ; --------------------------------------------------------------------------
    call do_exit_boot_services
    test rax, rax
    jnz near .fail_ebs

    ; --------------------------------------------------------------------------
    ; 5. Set Up Identity Page Tables & Reload GDT
    ; Clear 6 pages at 0xA000 (PML4, PDPT, PD0..PD3 = 24 KiB)
    ; --------------------------------------------------------------------------
    cli
    mov rdi, PT_PML4
    mov rcx, (4096 * 6) / 8
    xor eax, eax
    rep stosq

    mov qword [abs PT_PML4], PT_PDPT | 0x03
    mov qword [abs PT_PDPT + 0*8], (PT_PD0 + 0x0000) | 0x03
    mov qword [abs PT_PDPT + 1*8], (PT_PD0 + 0x1000) | 0x03
    mov qword [abs PT_PDPT + 2*8], (PT_PD0 + 0x2000) | 0x03
    mov qword [abs PT_PDPT + 3*8], (PT_PD0 + 0x3000) | 0x03

    xor ecx, ecx
.pd_outer:
    mov rdi, PT_PD0
    mov eax, ecx
    shl rax, 12
    add rdi, rax
    mov rax, rcx
    shl rax, 30
    mov edx, 512
.pd_inner:
    mov rsi, rax
    or rsi, 0x83        ; Present, Writable, 2MB Page Size
    mov [rdi], rsi
    add rdi, 8
    add rax, 0x200000
    dec edx
    jnz .pd_inner
    inc ecx
    cmp ecx, 4
    jb .pd_outer

    ; Map Framebuffer if above 4GB
    mov r8, [rel fb_base]
    mov rdx, 0x100000000
    cmp r8, rdx
    jb .fb_done

    mov rax, r8
    shr rax, 30
    and eax, 0x1FF
    mov rsi, r8
    and rsi, ~0x3FFFFFFF
    or rsi, 0x83        ; 1GB page
    mov [abs PT_PDPT + rax*8], rsi

.fb_done:
    mov rax, PT_PML4
    mov cr3, rax

    ; Load 64-bit GDT with runtime physical base address
    lea rax, [rel gdt64]
    mov [rel gdt64_base], rax
    lgdt [rel gdt64_desc]
    push 0x08
    lea rax, [rel .reload_cs]
    push rax
    retfq

.reload_cs:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, STACK_TOP
    and rsp, -16

    ; Jump to NovaOS 64-bit Kernel at 0x10000
    mov rax, KERNEL_PHYS
    jmp rax

; Error handlers
.fail_gop:
    mov rcx, [rel con_out]
    lea rdx, [rel msg_nogop]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    jmp .hang

.fail_payload:
    mov rcx, [rel con_out]
    lea rdx, [rel msg_nofs]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    jmp .hang

.fail_ebs:
    mov rcx, [rel con_out]
    lea rdx, [rel msg_failebs]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    jmp .hang

.hang:
    cli
    hlt
    jmp .hang

; ------------------------------------------------------------------------------
; load_payloads: load KERNEL.BIN and NOVAFS.BIN into physical memory
; ------------------------------------------------------------------------------
load_payloads:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x40

    ; Print startup
    mov rcx, [rel con_out]
    lea rdx, [rel str_lp_start]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; 1. Try LoadedImageProtocol for our image handle
    ; HandleProtocol is at offset 152 (0x98) of EFI_BOOT_SERVICES
    mov rax, [rel boot_svc]
    mov rcx, [rel img_handle]
    lea rdx, [rel guid_loaded]
    lea r8, [rel loaded_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32

    mov rcx, [rel con_out]
    lea rdx, [rel str_lp_li]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    mov rax, [rel loaded_ptr]
    call print_hex64
    mov rcx, [rel con_out]
    lea rdx, [rel msg_nl]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov rax, [rel loaded_ptr]
    test rax, rax
    jz .lp_fallback

    ; loaded_ptr->DeviceHandle is at offset 24 (0x18)
    mov rcx, [rax + 24]
    test rcx, rcx
    jz .lp_fallback

    ; 2. Get SimpleFileSystemProtocol on DeviceHandle
    mov rax, [rel boot_svc]
    lea rdx, [rel guid_fs]
    lea r8, [rel fs_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jz .got_fs

.lp_fallback:
    ; Fallback: LocateProtocol(&guid_fs, NULL, &fs_ptr)
    mov rax, [rel boot_svc]
    lea rcx, [rel guid_fs]
    xor edx, edx
    lea r8, [rel fs_ptr]
    sub rsp, 32
    call [rax + 320]
    add rsp, 32

.got_fs:
    mov rcx, [rel con_out]
    lea rdx, [rel str_lp_fs]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    mov rax, [rel fs_ptr]
    call print_hex64
    mov rcx, [rel con_out]
    lea rdx, [rel msg_nl]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov rcx, [rel fs_ptr]
    test rcx, rcx
    jz .lp_err

    ; 3. OpenVolume: fs_ptr->OpenVolume(fs_ptr, &vol_ptr)
    ; OpenVolume is at offset 8 (0x08) of SimpleFileSystemProtocol
    lea rdx, [rel vol_ptr]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov rcx, [rel con_out]
    lea rdx, [rel str_lp_vol]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    mov rax, [rel vol_ptr]
    call print_hex64
    mov rcx, [rel con_out]
    lea rdx, [rel msg_nl]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov rbx, [rel vol_ptr]  ; rbx = Root Directory File Protocol
    test rbx, rbx
    jz .lp_err

    ; 4. Open KERNEL.BIN
    ; Try root path first: KERNEL.BIN
    mov rcx, rbx
    lea rdx, [rel fh_kernel]
    lea r8, [rel path_kernel3]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], 0
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jz .open_k_ok

    ; Try secondary path: EFI\NOVA\KERNEL.BIN
    mov rcx, rbx
    lea rdx, [rel fh_kernel]
    lea r8, [rel path_kernel2]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], 0
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jz .open_k_ok

    ; Try primary path: \EFI\NOVA\KERNEL.BIN
    mov rcx, rbx
    lea rdx, [rel fh_kernel]
    lea r8, [rel path_kernel1]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], 0
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_err

.open_k_ok:
    mov rcx, [rel con_out]
    lea rdx, [rel str_lp_kok]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; Read kernel into KERNEL_PHYS (0x10000)
    mov rcx, [rel fh_kernel]
    mov rdx, KERNEL_PHYS
    mov r8, KERNEL_MAX
    call read_file_all
    test rax, rax
    jnz .lp_err

    ; Close kernel file
    mov rcx, [rel fh_kernel]
    sub rsp, 32
    call [rcx + 16]         ; File->Close is at offset 16 (0x10)
    add rsp, 32

    ; 5. Open NOVAFS.BIN
    ; Try root path first: NOVAFS.BIN
    mov rcx, rbx
    lea rdx, [rel fh_fs]
    lea r8, [rel path_fs3]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], 0
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jz .open_fs_ok

    ; Try secondary path: EFI\NOVA\NOVAFS.BIN
    mov rcx, rbx
    lea rdx, [rel fh_fs]
    lea r8, [rel path_fs2]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], 0
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jz .open_fs_ok

    ; Try primary path: \EFI\NOVA\NOVAFS.BIN
    mov rcx, rbx
    lea rdx, [rel fh_fs]
    lea r8, [rel path_fs1]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], 0
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_err

.open_fs_ok:
    mov rcx, [rel con_out]
    lea rdx, [rel str_lp_fsok]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; Read NovaFS into FS_PHYS (0x20000)
    mov rcx, [rel fh_fs]
    mov rdx, FS_PHYS
    mov r8, FS_MAX
    call read_file_all
    test rax, rax
    jnz .lp_err

    ; Close NovaFS file
    mov rcx, [rel fh_fs]
    sub rsp, 32
    call [rcx + 16]
    add rsp, 32

    ; Close Root Directory
    mov rcx, rbx
    sub rsp, 32
    call [rcx + 16]
    add rsp, 32

    xor eax, eax
    add rsp, 0x40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.lp_err:
    mov eax, 1
    add rsp, 0x40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------------------------
; read_file_all(FileHandle, DestBuffer, MaxBytes)
; RCX = FileHandle
; RDX = Destination buffer
; R8  = Maximum bytes
; ------------------------------------------------------------------------------
read_file_all:
    push rbx
    push r12
    push r13
    push r15
    sub rsp, 40             ; 8 (ret) + 32 (pushes) + 40 = 80 (16-byte aligned!)

    mov rbx, rcx
    mov r12, rdx
    mov r13, r8
    xor r15d, r15d

.ra_loop:
    mov rax, r13
    sub rax, r15
    jbe .ra_done

    cmp rax, 65536
    jbe .ra_chunk
    mov rax, 65536
.ra_chunk:
    mov [rel io_size], rax

    mov rcx, rbx
    lea rdx, [rel io_size]
    mov r8, r12
    add r8, r15
    sub rsp, 32
    call [rbx + 32]         ; File->Read is at offset 32 (0x20)
    add rsp, 32
    test rax, rax
    jnz .ra_fail

    mov rax, [rel io_size]
    test rax, rax
    jz .ra_done             ; 0 bytes read = EOF

    add r15, rax
    jmp .ra_loop

.ra_done:
    xor eax, eax
    add rsp, 40
    pop r15
    pop r13
    pop r12
    pop rbx
    ret

.ra_fail:
    mov eax, 1
    add rsp, 40
    pop r15
    pop r13
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------------------------
; do_exit_boot_services: Retrieve MemoryMap key and ExitBootServices
; ------------------------------------------------------------------------------
do_exit_boot_services:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x20

    mov r14d, 8             ; retry counter
.ebs_retry:
    mov qword [rel mmap_size], 8192
    mov rax, [rel boot_svc]
    lea rcx, [rel mmap_size]
    lea rdx, [rel mmap_buf]
    lea r8, [rel mmap_key]
    lea r9, [rel mmap_dsize]
    sub rsp, 48
    lea r10, [rel mmap_dver]
    mov [rsp + 32], r10
    call [rax + 56]         ; GetMemoryMap is at offset 56 (0x38)
    add rsp, 48
    test rax, rax
    jnz .ebs_fail

    mov rax, [rel boot_svc]
    mov rcx, [rel img_handle]
    mov rdx, [rel mmap_key]
    sub rsp, 32
    call [rax + 232]        ; ExitBootServices is at offset 232 (0xE8)
    add rsp, 32
    test rax, rax
    jz .ebs_ok

    dec r14d
    jnz .ebs_retry

.ebs_fail:
    mov eax, 1
    add rsp, 0x20
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.ebs_ok:
    xor eax, eax
    add rsp, 0x20
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------------------------
; print_dec: Print decimal EAX via ConOut->OutputString
; ------------------------------------------------------------------------------
print_dec:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    lea rsi, [rsp + 40]
    mov word [rsi], 0
    mov ebx, 10
    test eax, eax
    jnz .pd_conv
    dec rsi
    dec rsi
    mov word [rsi], '0'
    jmp .pd_print

.pd_conv:
    xor edx, edx
    div ebx
    add dl, '0'
    dec rsi
    dec rsi
    mov [rsi], dx
    test eax, eax
    jnz .pd_conv

.pd_print:
    mov rcx, [rel con_out]
    mov rdx, rsi
    sub rsp, 32
    call [rcx + 8]          ; ConOut->OutputString
    add rsp, 32
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret

; ------------------------------------------------------------------------------
; print_hex64: Print RAX as 16 hex digits via ConOut->OutputString
; ------------------------------------------------------------------------------
print_hex64:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    lea rsi, [rsp + 40]
    mov word [rsi], 0
    mov ebx, 16
.ph_loop:
    mov rdx, rax
    and edx, 0xF
    cmp dl, 10
    jb .ph_digit
    add dl, 'A' - 10
    jmp .ph_store
.ph_digit:
    add dl, '0'
.ph_store:
    dec rsi
    dec rsi
    mov [rsi], dx
    shr rax, 4
    dec ebx
    jnz .ph_loop
    mov rcx, [rel con_out]
    mov rdx, rsi
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret

; ------------------------------------------------------------------------------
; Read-Only Data
; ------------------------------------------------------------------------------
align 8
gdt64:
    dq 0x0000000000000000       ; 0x00: null descriptor
    dq 0x00AF9A000000FFFF       ; 0x08: 64-bit code descriptor
    dq 0x00CF92000000FFFF       ; 0x10: 64-bit data descriptor
align 8
gdt64_desc:
    dw $ - gdt64 - 1
gdt64_base:
    dq 0

align 2
msg_hello   dw 'N','o','v','a','O','S',' ','U','E','F','I',' ','L','o','a','d','e','r',' ','v','0','.','8','.','5','1','6','7',13,10,0
msg_mode    dw 'G','O','P',' ','M','o','d','e',':',' ',0
msg_x       dw 'x',0
msg_nl      dw 13,10,0
msg_jump    dw 'S','t','a','r','t','i','n','g',' ','N','o','v','a','O','S',' ','k','e','r','n','e','l','.','.','.',13,10,0
msg_nogop   dw 'E','r','r','o','r',':',' ','N','o',' ','s','u','i','t','a','b','l','e',' ','G','O','P',' ','m','o','d','e','!',13,10,0
msg_nofs    dw 'E','r','r','o','r',':',' ','P','a','y','l','o','a','d',' ','(','K','E','R','N','E','L','.','B','I','N',')',' ','n','o','t',' ','f','o','u','n','d','!',13,10,0
msg_failebs dw 'E','r','r','o','r',':',' ','E','x','i','t','B','o','o','t','S','e','r','v','i','c','e','s',' ','f','a','i','l','e','d','!',13,10,0

str_lp_start dw 'L','o','a','d','i','n','g',' ','p','a','y','l','o','a','d','s','.','.','.',13,10,0
str_lp_li    dw 'L','o','a','d','e','d','I','m','g',':',' ',0
str_lp_fs    dw 'F','i','l','e','S','y','s',':',' ',0
str_lp_vol   dw 'O','p','e','n','V','o','l',':',' ',0
str_lp_kok   dw 'K','e','r','n','e','l',' ','f','o','u','n','d','.',13,10,0
str_lp_fsok  dw 'N','o','v','a','F','S',' ','f','o','u','n','d','.',13,10,0

path_kernel1 dw '\','E','F','I','\','N','O','V','A','\','K','E','R','N','E','L','.','B','I','N',0
path_kernel2 dw 'E','F','I','\','N','O','V','A','\','K','E','R','N','E','L','.','B','I','N',0
path_kernel3 dw 'K','E','R','N','E','L','.','B','I','N',0

path_fs1     dw '\','E','F','I','\','N','O','V','A','\','N','O','V','A','F','S','.','B','I','N',0
path_fs2     dw 'E','F','I','\','N','O','V','A','\','N','O','V','A','F','S','.','B','I','N',0
path_fs3     dw 'N','O','V','A','F','S','.','B','I','N',0

guid_gop    db 0xDE,0xA9,0x42,0x90,0xDC,0x23,0x38,0x4A,0x96,0xFB,0x7A,0xDE,0xD0,0x80,0x51,0x6A
guid_fs     db 0x22,0x5B,0x4E,0x96,0x59,0x64,0xD2,0x11,0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B
guid_loaded db 0xA1,0x31,0x1B,0x5B,0x62,0x95,0xD2,0x11,0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B

; ------------------------------------------------------------------------------
; Variables & BSS Buffers
; ------------------------------------------------------------------------------
align 8
img_handle  dq 0
sys_table   dq 0
con_out     dq 0
boot_svc    dq 0

gop_ptr     dq 0
gop_mode    dq 0
gop_max     dd 0, 0

best_w      dd 0
best_h      dd 0
best_fmt    dd 0
best_ppsl   dd 0
fb_base     dq 0
fb_size     dq 0

tmp_isz     dq 0
tmp_info    dq 0

loaded_ptr  dq 0
fs_ptr      dq 0
vol_ptr     dq 0
fh_kernel   dq 0
fh_fs       dq 0
io_size     dq 0

mmap_size   dq 0
mmap_key    dq 0
mmap_dsize  dq 0
mmap_dver   dd 0, 0

align 16
mmap_buf    times 8192 db 0
