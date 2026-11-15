; NovaOS UEFI loader part A: header + GOP enum (see loader.asm)
BITS 64
DEFAULT REL
%define IMAGE_BASE      0x140000000
%define SECTION_RVA     0x1000
%define BY_PROTOCOL     2
%define PixelBitMask    2
%define PixelBltOnly    3
%define PixelFormatMax  4
%define KERNEL_PHYS     0x10000
%define KERNEL_MAX      0x10000
%define FS_PHYS         0x20000
%define FS_MAX          0x80000
%define HANDOFF         0x9000
%define STACK_TOP       0x400000
%define PT_PML4         0xA000
%define PT_PDPT         0xB000
%define PT_PD0          0xC000
%define MAX_GOP_WIDTH   2560
%define MAX_GOP_HEIGHT  1600
%define EFI_FILE_MODE_READ  0x1
%define EFI_FILE_READ_ONLY  0x1
%define EFI_BUFFER_TOO_SMALL 0x8000000000000005
section .text vstart=(IMAGE_BASE + SECTION_RVA)
efi_main:
    push rbx
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x60
    mov [rel img_handle], rcx
    mov [rel sys_table], rdx
    mov rcx, [rdx + 64]
    lea rdx, [rel msg_hello]
    call [rcx + 8]
    mov rax, [rel sys_table]
    mov rax, [rax + 88]
    mov [rel boot_svc], rax
    test rax, rax
    jz near .fail_bs
    lea rcx, [rel guid_gop]
    mov rbx, [rel boot_svc]
    mov edx, BY_PROTOCOL
    xor r8d, r8d
    lea r9, [rel tmp_size]
    mov qword [rel tmp_size], 0
    sub rsp, 32
    mov qword [rsp + 32], 0
    call [rbx + 176]
    add rsp, 32
    mov rdx, EFI_BUFFER_TOO_SMALL
    cmp rax, rdx
    jne near .fail_bs
    mov rax, [rel tmp_size]
    test rax, rax
    jz near .fail_bs
    cmp rax, 4096
    ja near .fail_bs
; NovaOS UEFI loader part B: pool alloc + mode loop + SetMode
    mov rax, [rel boot_svc]
    xor ecx, ecx
    mov rdx, [rel tmp_size]
    lea r8, [rel tmp_ptr]
    sub rsp, 32
    call [rax + 128]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel tmp_ptr]
    test rax, rax
    jz near .fail_bs
    mov rax, [rel boot_svc]
    lea rcx, [rel guid_gop]
    mov edx, BY_PROTOCOL
    xor r8d, r8d
    lea r9, [rel tmp_size]
    mov rbx, [rel tmp_ptr]
    sub rsp, 32
    mov [rsp + 32], rbx
    call [rax + 176]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel boot_svc]
    mov rcx, [rel tmp_ptr]
    mov rcx, [rcx]
    lea rdx, [rel guid_gop]
    lea r8, [rel gop_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz near .fail_bs
    mov rax, [rel gop_ptr]
    test rax, rax
    jz near .fail_bs
    mov rax, [rax + 8]
    mov [rel gop_mode], rax
    test rax, rax
    jz near .fail_bs
    mov ecx, [rax]
    mov [rel gop_max], ecx
    xor r14d, r14d
    xor r15d, r15d
    mov dword [rel best_w], 0
    mov dword [rel best_h], 0
    xor ebx, ebx
.mode_loop:
    cmp ebx, [rel gop_max]
    jae .mode_done
    mov rcx, [rel gop_ptr]
    mov edx, ebx
    lea r8, [rel tmp_isz]
    lea r9, [rel tmp_info]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    test rax, rax
    jnz .mode_next
    mov rsi, [rel tmp_info]
    test rsi, rsi
    jz .mode_next
    mov eax, [rsi + 4]
    mov edx, [rsi + 8]
    mov ecx, [rsi + 12]
    cmp ecx, PixelFormatMax
    jae .mode_next
    cmp ecx, PixelBitMask
    je .mode_next
    cmp ecx, PixelBltOnly
    je .mode_next
    cmp eax, 640
    jb .mode_next
    cmp edx, 400
    jb .mode_next
    cmp eax, MAX_GOP_WIDTH
    ja .mode_next
    cmp edx, MAX_GOP_HEIGHT
    ja .mode_next
    mov r10d, eax
    imul r10d, edx
    cmp r10d, r15d
    jbe .mode_next
    mov r15d, r10d
    mov r14d, ebx
    mov eax, [rsi + 4]
    mov [rel best_w], eax
    mov eax, [rsi + 8]
    mov [rel best_h], eax
    mov eax, [rsi + 12]
    mov [rel best_fmt], eax
    mov eax, [rsi + 16]
    mov [rel best_ppsl], eax
.mode_next:
    inc ebx
    jmp .mode_loop
.mode_done:
    test r15d, r15d
    jz near .fail_nomode
    mov rcx, [rel gop_ptr]
    mov edx, r14d
    sub rsp, 32
    call [rcx + 16]
    add rsp, 32
    test rax, rax
    jnz near .fail_nomode
    mov rax, [rel gop_ptr]
    mov rax, [rax + 8]
    mov [rel gop_mode], rax
    test rax, rax
    jz near .fail_nomode
    mov rcx, [rax + 8]
    test rcx, rcx
    jz near .fail_nomode
    mov edx, [rcx + 4]
    mov [rel best_w], edx
    mov edx, [rcx + 8]
    mov [rel best_h], edx
    mov edx, [rcx + 12]
    mov [rel best_fmt], edx
    mov edx, [rcx + 16]
    mov [rel best_ppsl], edx
    mov rdx, [rax + 24]
    mov [rel fb_base], rdx
    test rdx, rdx
    jz near .fail_nomode
    mov rdx, [rax + 32]
    mov [rel fb_size], rdx
    mov eax, [rel best_ppsl]
    shl rax, 2
    mov rcx, [rel best_h]
    mul rcx
    test rdx, rdx
    jnz near .fail_nomode
    cmp qword [rel fb_size], 0
    jz .fb_size_ok
    cmp rax, [rel fb_size]
    jbe .fb_size_ok
    mov [rel fb_size], rax
.fb_size_ok:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_mode]
    call [rcx + 8]
    mov eax, [rel best_w]
    call print_dec
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_x]
    call [rcx + 8]
    mov eax, [rel best_h]
    call print_dec
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_nl]
    call [rcx + 8]
    call load_payloads
    test rax, rax
    jnz near .fail_fs
; NovaOS UEFI loader part C: handoff + ExitBootServices + jump
    mov rax, [rel fb_base]
    mov [HANDOFF + 48], rax          ; qword fb base
    mov eax, [rel best_ppsl]
    shl rax, 2
    mov [HANDOFF + 40], rax          ; qword pitch
    mov eax, [rel best_w]
    mov [HANDOFF + 24], rax          ; qword width
    mov eax, [rel best_h]
    mov [HANDOFF + 32], rax          ; qword height
    mov dword [HANDOFF + 20], 0x504F474E  ; 'NGOP'
    mov rax, [rel fb_base]
    mov [HANDOFF], eax               ; BIOS mirror dwords
    mov eax, [rel best_ppsl]
    shl eax, 2
    mov [HANDOFF + 4], eax
    mov eax, [rel best_w]
    mov [HANDOFF + 8], eax
    mov eax, [rel best_h]
    mov [HANDOFF + 12], eax
    mov dword [HANDOFF + 16], 32
    mov eax, [rel best_fmt]          ; 1=BGR => flags bit0
    cmp eax, 1
    sete al
    movzx eax, al
    or eax, 2                        ; bit1 = UEFI source
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_jump]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    call exit_boot_services
    test rax, rax
    jnz near .fail_bs
    ; identity tables, clear all 6 pages (PML4, PDPT, PD0-3 = 24 KiB)
    mov rdi, PT_PML4
    mov rcx, (4096 * 6) / 8
    xor eax, eax
    rep stosq
    mov qword [PT_PML4], PT_PDPT | 0x03
    mov qword [PT_PDPT + 0*8], PT_PD0 | 0x03
    mov qword [PT_PDPT + 1*8], (PT_PD0 + 0x1000) | 0x03
    mov qword [PT_PDPT + 2*8], (PT_PD0 + 0x2000) | 0x03
    mov qword [PT_PDPT + 3*8], (PT_PD0 + 0x3000) | 0x03
    xor ecx, ecx
.pd_loop:
    mov rdi, PT_PD0
    mov eax, ecx
    shl rax, 12
    add rdi, rax
    mov rax, rcx
    shl rax, 30
    mov edx, 512
.pte_loop:
    mov rsi, rax
    or rsi, 0x83
    mov [rdi], rsi
    add rdi, 8
    add rax, 0x200000
    dec edx
    jnz .pte_loop
    inc ecx
    cmp ecx, 4
    jb .pd_loop
    ; If fb_base is >= 4GB, map it in PT_PDPT
    mov r8, [rel fb_base]
    mov rdx, 0x100000000
    cmp r8, rdx
    jb .fb_mapped
    mov rax, r8
    shr rax, 30
    and eax, 0x1FF
    push rax
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 26
    pop rax
    jnz .map_1gb
    mov rdi, 0x8000
    mov ecx, 512
    xor eax, eax
    rep stosq
    mov rax, r8
    shr rax, 30
    and eax, 0x1FF
    mov qword [PT_PDPT + rax*8], 0x8000 | 0x03
    mov rax, r8
    shr rax, 21
    and eax, 0x1FF
    lea rdi, [0x8000 + rax*8]
    mov rsi, r8
    and rsi, ~0x1FFFFF
    mov ecx, 16
.fb_2mb_loop:
    mov rax, rsi
    or rax, 0x83
    mov [rdi], rax
    add rdi, 8
    add rsi, 0x200000
    dec ecx
    jnz .fb_2mb_loop
    jmp .fb_mapped
.map_1gb:
    mov rsi, r8
    and rsi, ~0x3FFFFFFF
    or rsi, 0x83
    mov [PT_PDPT + rax*8], rsi
.fb_mapped:
    mov rax, PT_PML4
    mov cr3, rax
    mov rsp, STACK_TOP
    mov rax, KERNEL_PHYS
    jmp rax
.fail_nomode:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_nogop]
    call [rcx + 8]
    jmp .fail_halt
.fail_fs:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_nofs]
    call [rcx + 8]
    jmp .fail_halt
.fail_bs:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    lea rdx, [rel msg_fail]
    call [rcx + 8]
.fail_halt:
    add rsp, 0x60
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    mov eax, 1
    ret
print_dec:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    lea rsi, [rsp + 40]
    mov word [rsi], 0
    mov ebx, 10
    test eax, eax
    jnz .pd_loop
    dec rsi
    dec rsi
    mov word [rsi], '0'
    jmp .pd_out
.pd_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    dec rsi
    dec rsi
    mov [rsi], dx
    test eax, eax
    jnz .pd_loop
.pd_out:
    mov rax, [rel sys_table]
    mov rcx, [rax + 64]
    mov rdx, rsi
    call [rcx + 8]
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret
; NovaOS UEFI loader part D: payload file loading
load_payloads:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x40
    mov rax, [rel boot_svc]
    mov rcx, [rel img_handle]
    lea rdx, [rel guid_loaded]
    lea r8, [rel loaded_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rax, [rel loaded_ptr]
    test rax, rax
    jz .lp_fail
    mov rcx, [rax + 32]
    mov rax, [rel boot_svc]
    lea rdx, [rel guid_fs]
    lea r8, [rel fs_ptr]
    sub rsp, 32
    call [rax + 152]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fs_ptr]
    test rcx, rcx
    jz .lp_fail
    lea rdx, [rel vol_ptr]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel vol_ptr]
    lea rdx, [rel fh_kernel]
    lea r8, [rel path_kernel]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], EFI_FILE_READ_ONLY
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fh_kernel]
    mov rdx, KERNEL_PHYS
    mov r8, KERNEL_MAX
    call read_all
    test rax, rax
    jnz .lp_fail
    mov [rel kernel_size], r8
    cmp r8, 512
    jb .lp_fail
    mov rcx, [rel vol_ptr]
    lea rdx, [rel fh_fs]
    lea r8, [rel path_fs]
    mov r9, EFI_FILE_MODE_READ
    sub rsp, 48
    mov qword [rsp + 32], EFI_FILE_READ_ONLY
    call [rcx + 8]
    add rsp, 48
    test rax, rax
    jnz .lp_fail
    mov rcx, [rel fh_fs]
    mov rdx, FS_PHYS
    mov r8, FS_MAX
    call read_all
    test rax, rax
    jnz .lp_fail
    cmp dword [FS_PHYS], 0x53464E56
    jne .lp_fail
    xor eax, eax
    add rsp, 0x40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.lp_fail:
    mov eax, 1
    add rsp, 0x40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
read_all:
    push rbx
    push r12
    push r13
    push r15
    sub rsp, 32
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
    call [rbx + 32]
    add rsp, 32
    test rax, rax
    jnz .ra_fail
    mov rax, [rel io_size]
    test rax, rax
    jz .ra_done
    add r15, rax
    jmp .ra_loop
.ra_done:
    mov r8, r15
    xor eax, eax
    add rsp, 32
    pop r15
    pop r13
    pop r12
    pop rbx
    ret
.ra_fail:
    mov eax, 1
    add rsp, 32
    pop r15
    pop r13
    pop r12
    pop rbx
    ret
; NovaOS UEFI loader part E: ExitBootServices + data
exit_boot_services:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x20
    mov rax, [rel boot_svc]
    mov rbx, rax
    mov r14d, 8
.ebs_real:
    mov qword [rel mmap_size], 0
    lea rcx, [rel mmap_size]
    xor edx, edx
    xor r8d, r8d
    lea r9, [rel mmap_key]
    sub rsp, 64
    lea rax, [rel mmap_dsize]
    mov [rsp + 32], rax
    lea rax, [rel mmap_dver]
    mov [rsp + 40], rax
    call [rbx + 56]
    add rsp, 64
    mov rax, [rel mmap_size]
    add rax, 8*48
    mov [rel mmap_size], rax
    mov rax, [rel boot_svc]
    xor ecx, ecx
    mov rdx, [rel mmap_size]
    lea r8, [rel mmap_ptr]
    sub rsp, 32
    call [rax + 128]
    add rsp, 32
    test rax, rax
    jnz .ebs_fail
    lea rcx, [rel mmap_size]
    mov rdx, [rel mmap_ptr]
    lea r8, [rel mmap_key]
    lea r9, [rel mmap_dsize]
    sub rsp, 64
    lea rax, [rel mmap_dver]
    mov [rsp + 32], rax
    call [rbx + 56]
    add rsp, 64
    test rax, rax
    jnz .ebs_fail
    mov rax, [rel boot_svc]
    mov rcx, [rel img_handle]
    mov rdx, [rel mmap_key]
    sub rsp, 32
    call [rax + 216]
    add rsp, 32
    test rax, rax
    jz .ebs_ok
    mov rax, [rel boot_svc]
    mov rcx, [rel mmap_ptr]
    sub rsp, 32
    call [rax + 136]
    add rsp, 32
    dec r14d
    jnz .ebs_real
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
msg_hello   dw 'N','o','v','a','O','S',' ','U','E','F','I',' ','l','o','a','d','e','r',13,10,0
msg_mode    dw 'G','O','P',' ','m','o','d','e',':',' ',0
msg_x       dw 'x',0
msg_nl      dw 13,10,0
msg_jump    dw 'S','t','a','r','t','i','n','g',' ','k','e','r','n','e','l','.','.','.',13,10,0
msg_fail    dw 'U','E','F','I',' ','b','o','o','t',' ','f','a','i','l','u','r','e','.',13,10,0
msg_nogop   dw 'N','o',' ','s','u','i','t','a','b','l','e',' ','G','O','P',' ','m','o','d','e','.',13,10,0
msg_nofs    dw 'P','a','y','l','o','a','d',' ','m','i','s','s','i','n','g','.',13,10,0
path_kernel dw 92,'E','F','I',92,'N','O','V','A',92,'K','E','R','N','E','L','.','B','I','N',0
path_fs     dw 92,'E','F','I',92,'N','O','V','A',92,'N','O','V','A','F','S','.','B','I','N',0
guid_gop    db 0xDE,0xA9,0x42,0x90,0xDC,0x23,0x38,0x4A,0x96,0xFB,0x7A,0xDE,0xD0,0x80,0x51,0x6A
guid_fs     db 0x22,0x5B,0x4E,0x96,0x59,0x64,0xD2,0x11,0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B
guid_loaded db 0xA1,0x31,0x1B,0x5B,0x62,0x95,0xD2,0x11,0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B
img_handle  dq 0
sys_table   dq 0
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
tmp_size    dq 0
tmp_ptr     dq 0
tmp_info    dq 0
tmp_isz     dq 0
loaded_ptr  dq 0
fs_ptr      dq 0
vol_ptr     dq 0
fh_kernel   dq 0
fh_fs       dq 0
kernel_size dq 0
io_size     dq 0
mmap_ptr    dq 0
mmap_size   dq 0
mmap_key    dq 0
mmap_dsize  dq 0
mmap_dver   dd 0, 0
times 0x1000 - ($ - $$) db 0
